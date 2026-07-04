import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/app_logger.dart';
import '../exceptions/crypto_exceptions.dart';
import '../models/crypto_models.dart';
import 'secure_storage_service.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final keyManagerProvider = Provider<KeyManager>(
  (ref) => KeyManager(ref.read(secureStorageServiceProvider)),
  name: 'keyManagerProvider',
);

// ── Key Manager ───────────────────────────────────────────────────────────────

/// Manages the full lifecycle of the Orbit master encryption key.
///
/// ## Key hierarchy
/// ```
/// Recovery Passphrase ──Argon2id──► PEK (Passphrase Encryption Key, 256-bit)
///                                            │
///                                  AES-256-GCM encrypt ──► EncryptedKeyBlob
///                                            │                 (Firestore)
///                                            │
///           Secure Storage ◄── store ── Master Key (256-bit random)
///                │
///                ▼
///           HKDF-SHA256 per collection ──► Collection DEK (256-bit)
/// ```
///
/// ## Firestore path
/// `users/{uid}/security/keyData` — stores the [EncryptedKeyBlob].
/// This document is NOT sensitive on its own (it is an opaque encrypted blob).
///
/// ## First-login flow
/// 1. User authenticates with Google.
/// 2. [isKeyBlobPresent] returns `false` → this is a brand-new account.
/// 3. The app shows the passphrase-setup UI.
/// 4. [createMasterKey] generates a fresh 32-byte master key, encrypts it with
///    the chosen passphrase, persists the blob to Firestore, and caches the
///    raw key in secure storage.
///
/// ## New-device recovery flow
/// 1. [isMasterKeyPresent] → `false`, [isKeyBlobPresent] → `true`.
/// 2. The app shows the passphrase-recovery UI.
/// 3. [recoverMasterKey] fetches the blob, decrypts it, and caches the key.
///
/// ## Subsequent sign-ins (same device)
/// [isMasterKeyPresent] → `true`. No UI shown; key loaded via [getMasterKey].

class KeyManager {
  KeyManager(this._secureStorage);

  final SecureStorageService _secureStorage;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Argon2id defaults (OWASP 2023 recommendation for interactive login) ──
  static const int _argon2Memory = 65536; // 64 MiB
  static const int _argon2Iterations = 3;
  static const int _argon2Parallelism = 2;

  // ── Key IDs ──────────────────────────────────────────────────────────────

  /// Secure storage key ID for the raw master key of [uid].
  static String masterKeyId(String uid) => 'orbit_mk_v2_$uid';

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns `true` if the raw master key is cached in secure storage for [uid].
  Future<bool> isMasterKeyPresent(String uid) =>
      _secureStorage.containsKey(masterKeyId(uid));

  /// Returns `true` if an [EncryptedKeyBlob] exists in Firestore for [uid].
  Future<bool> isKeyBlobPresent(String uid) async {
    int attempts = 0;
    final currentAuthUid = FirebaseAuth.instance.currentUser?.uid;
    AppLogger.info(
      'KeyManager: isKeyBlobPresent called. Target uid: $uid, Auth uid: $currentAuthUid',
    );

    while (true) {
      try {
        final doc = await _keyBlobRef(uid).get();
        AppLogger.info('KeyManager: Fetch keyData successful for uid: $uid');
        return doc.exists;
      } catch (e, stackTrace) {
        attempts++;
        final errString = e.toString();
        final errType = e.runtimeType;
        AppLogger.warning(
          'KeyManager: Error fetching keyData for uid: $uid. Attempt: $attempts. '
          'Type: $errType, Error: $errString',
          e,
          stackTrace,
        );

        final isPermissionDenied =
            errString.contains('permission-denied') ||
            errString.contains('PERMISSION_DENIED') ||
            (e is FirebaseException && e.code == 'permission-denied');

        if (isPermissionDenied && attempts < 4) {
          AppLogger.warning(
            'KeyManager: Permission denied while checking key blob for uid=$uid. '
            'Retrying in ${150 * attempts}ms...',
          );
          await Future.delayed(Duration(milliseconds: 150 * attempts));
          continue;
        }
        AppLogger.error(
          'KeyManager: Failed to check key blob presence for uid=$uid after attempts',
          e,
        );
        rethrow;
      }
    }
  }

  /// Loads the raw 32-byte master key from secure storage.
  ///
  /// Throws [KeyNotFoundException] if the key is not cached locally.
  /// Use [isMasterKeyPresent] first if you need to handle this case gracefully.
  Future<Uint8List> getMasterKey(String uid) =>
      _secureStorage.readKey(masterKeyId(uid));

  /// Derives a 256-bit collection-specific Data Encryption Key (DEK) from the
  /// master key using HKDF-SHA256.
  ///
  /// HKDF is the correct tool here (not Argon2id) because the master key is
  /// already high-entropy key material — we need *expansion*, not *stretching*.
  ///
  /// The derivation is domain-separated by [collection] so that a compromise
  /// of one collection DEK does not affect others.
  ///
  /// [collection] examples: `"reflections"`, `"decisions"`, `"tasks"`, …
  Future<Uint8List> deriveCollectionKey(
    Uint8List masterKey,
    String collection,
  ) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final secretKey = SecretKey(masterKey);
    final info = utf8.encode('orbit-dek-v2:$collection');
    final saltBytes = utf8.encode('orbit-salt-v2:$collection');

    final derivedKey = await hkdf.deriveKey(
      secretKey: secretKey,
      nonce: saltBytes,
      info: info,
    );
    final keyBytes = await derivedKey.extractBytes();
    return Uint8List.fromList(keyBytes);
  }

  // ── First-time Setup ──────────────────────────────────────────────────────

  /// Generates a new random 256-bit master key, encrypts it with [passphrase]
  /// using Argon2id + AES-256-GCM, persists the blob to Firestore, and caches
  /// the raw key in secure storage for this session.
  ///
  /// ⚠️ This must only be called when [isKeyBlobPresent] is `false`.
  Future<void> createMasterKey(String uid, String passphrase) async {
    AppLogger.info('KeyManager: Generating new master key for uid=$uid');
    final masterKey = _generateRandomBytes(32);
    final blob = await _encryptMasterKey(masterKey, passphrase);

    int attempts = 0;
    while (true) {
      try {
        await _keyBlobRef(uid).set(blob.toJson());
        break;
      } catch (e, stackTrace) {
        attempts++;
        final errString = e.toString();
        final isPermissionDenied =
            errString.contains('permission-denied') ||
            errString.contains('PERMISSION_DENIED') ||
            (e is FirebaseException && e.code == 'permission-denied');

        if (isPermissionDenied && attempts < 4) {
          AppLogger.warning(
            'KeyManager: Permission denied while persisting master key blob for uid=$uid. '
            'Retrying in ${200 * attempts}ms...',
          );
          await Future.delayed(Duration(milliseconds: 200 * attempts));
          continue;
        }
        AppLogger.error(
          'KeyManager: Failed to persist master key blob for uid=$uid after $attempts attempts',
          e,
          stackTrace,
        );
        rethrow;
      }
    }

    await _secureStorage.writeKey(masterKeyId(uid), masterKey);
    AppLogger.info('KeyManager: Master key created and persisted for uid=$uid');
  }

  // ── Recovery ─────────────────────────────────────────────────────────────

  /// Fetches the [EncryptedKeyBlob] from Firestore, decrypts it with
  /// [passphrase], and caches the recovered master key in secure storage.
  ///
  /// Throws [KeyBlobNotFoundException] if no blob exists in Firestore.
  /// Throws [InvalidPassphraseException] if the passphrase is wrong.
  Future<void> recoverMasterKey(String uid, String passphrase) async {
    AppLogger.info('KeyManager: Starting key recovery for uid=$uid');

    final doc = await _keyBlobRef(uid).get();
    if (!doc.exists || doc.data() == null) {
      throw const KeyBlobNotFoundException();
    }

    final blob = EncryptedKeyBlob.fromJson(doc.data()!);
    final masterKey = await _decryptMasterKey(blob, passphrase);

    await _secureStorage.writeKey(masterKeyId(uid), masterKey);
    AppLogger.info('KeyManager: Key recovery succeeded for uid=$uid');
  }

  // ── Session Management ────────────────────────────────────────────────────

  /// Removes the master key from secure storage.
  ///
  /// Called on sign-out. The encrypted blob in Firestore is intentionally NOT
  /// deleted — the user can recover with their passphrase on the next sign-in.
  Future<void> clearMasterKey(String uid) async {
    await _secureStorage.deleteKey(masterKeyId(uid));
    AppLogger.info(
      'KeyManager: Master key cleared from secure storage for uid=$uid',
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _keyBlobRef(String uid) =>
      _db.collection('users').doc(uid).collection('security').doc('keyData');

  Uint8List _generateRandomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }

  Future<EncryptedKeyBlob> _encryptMasterKey(
    Uint8List masterKey,
    String passphrase,
  ) async {
    final salt = _generateRandomBytes(16);
    final pek = await _derivePassphraseKey(passphrase, salt);
    final iv = _generateRandomBytes(12);

    final algorithm = AesGcm.with256bits();
    final secretKey = await algorithm.newSecretKeyFromBytes(pek);
    final secretBox = await algorithm.encrypt(
      masterKey,
      secretKey: secretKey,
      nonce: iv,
    );

    // Append GCM tag to ciphertext (same convention as CryptoService)
    final encryptedKey = Uint8List.fromList(
      secretBox.cipherText + secretBox.mac.bytes,
    );

    return EncryptedKeyBlob(
      version: 1,
      salt: salt,
      iv: iv,
      encryptedKey: encryptedKey,
      argon2Memory: _argon2Memory,
      argon2Iterations: _argon2Iterations,
      argon2Parallelism: _argon2Parallelism,
    );
  }

  Future<Uint8List> _decryptMasterKey(
    EncryptedKeyBlob blob,
    String passphrase,
  ) async {
    final pek = await _derivePassphraseKey(
      passphrase,
      blob.salt,
      memory: blob.argon2Memory,
      iterations: blob.argon2Iterations,
      parallelism: blob.argon2Parallelism,
    );

    const tagLength = 16;
    final cipherText = blob.encryptedKey.sublist(
      0,
      blob.encryptedKey.length - tagLength,
    );
    final macBytes = blob.encryptedKey.sublist(
      blob.encryptedKey.length - tagLength,
    );

    try {
      final algorithm = AesGcm.with256bits();
      final secretKey = await algorithm.newSecretKeyFromBytes(pek);
      final secretBox = SecretBox(
        cipherText,
        nonce: blob.iv,
        mac: Mac(macBytes),
      );
      final plainBytes = await algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      return Uint8List.fromList(plainBytes);
    } on SecretBoxAuthenticationError {
      throw const InvalidPassphraseException();
    } catch (_) {
      throw const InvalidPassphraseException();
    }
  }

  /// Derives a 256-bit key from [passphrase] + [salt] using Argon2id.
  Future<Uint8List> _derivePassphraseKey(
    String passphrase,
    List<int> salt, {
    int memory = _argon2Memory,
    int iterations = _argon2Iterations,
    int parallelism = _argon2Parallelism,
  }) async {
    final argon2 = Argon2id(
      memory: memory,
      parallelism: parallelism,
      iterations: iterations,
      hashLength: 32,
    );
    final secretKey = SecretKey(utf8.encode(passphrase));
    final derived = await argon2.deriveKey(secretKey: secretKey, nonce: salt);
    final bytes = await derived.extractBytes();
    return Uint8List.fromList(bytes);
  }
}
