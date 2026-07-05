import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../exceptions/crypto_exceptions.dart';
import '../models/crypto_models.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final cryptoServiceProvider = Provider<CryptoService>(
  (ref) => CryptoService(),
  name: 'cryptoServiceProvider',
);

// ── Service ───────────────────────────────────────────────────────────────────

/// Pure, stateless AES-256-GCM encrypt / decrypt service.
///
/// This service knows nothing about keys, users, or collections — it operates
/// only on raw key bytes and plaintext / ciphertext. Higher-level concerns
/// (key derivation, caching, Firestore serialisation) live in [KeyManager]
/// and [EncryptionRepository].
///
/// Algorithm: **AES-256-GCM** (authenticated encryption)
/// - 256-bit key
/// - 12-byte (96-bit) random IV per operation
/// - 16-byte GCM authentication tag appended to the ciphertext
///
/// All data paths are in-memory; nothing is written to disk by this class.
class CryptoService {
  CryptoService() : _algorithm = AesGcm.with256bits();

  static const String algorithmId = 'AES-256-GCM';
  static const int _ivLength = 12;

  final AesGcm _algorithm;

  // ── Encrypt ──

  /// Encrypts [plaintext] (a JSON string) with [key] and returns an
  /// [EncryptedEnvelope] containing the version tag, a fresh random IV, and
  /// the ciphertext (with GCM tag appended).
  ///
  /// A new random IV is generated for every call — never reuse an IV with the
  /// same key.
  Future<EncryptedEnvelope> encrypt(Uint8List key, String plaintext) async {
    assert(key.length == 32, 'AES-256 requires a 32-byte key.');

    final secretKey = await _algorithm.newSecretKeyFromBytes(key);
    final nonce = _generateIv();
    final plaintextBytes = utf8.encode(plaintext);

    final secretBox = await _algorithm.encrypt(
      plaintextBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    // GCM convention: append tag to ciphertext so the envelope has one blob.
    final ciphertext = Uint8List.fromList(
      secretBox.cipherText + secretBox.mac.bytes,
    );

    return EncryptedEnvelope(
      version: EncryptionVersion.aesGcm256,
      algorithm: algorithmId,
      iv: Uint8List.fromList(nonce),
      ciphertext: ciphertext,
    );
  }

  // ── Decrypt ──

  /// Decrypts the [envelope] using [key] and returns the original plaintext
  /// JSON string.
  ///
  /// Throws [DecryptionFailureException] if the GCM authentication tag fails
  /// (data was tampered with, or the wrong key was used).
  /// Throws [MalformedEnvelopeException] if the ciphertext is too short to
  /// contain a valid GCM tag.
  Future<String> decrypt(Uint8List key, EncryptedEnvelope envelope) async {
    assert(key.length == 32, 'AES-256 requires a 32-byte key.');

    const tagLength = 16;
    if (envelope.ciphertext.length < tagLength) {
      throw MalformedEnvelopeException(
        'Ciphertext is too short (${envelope.ciphertext.length} bytes); '
        'expected at least $tagLength bytes for the GCM tag.',
      );
    }

    final cipherBody = envelope.ciphertext.sublist(
      0,
      envelope.ciphertext.length - tagLength,
    );
    final macBytes = envelope.ciphertext.sublist(
      envelope.ciphertext.length - tagLength,
    );

    try {
      final secretKey = await _algorithm.newSecretKeyFromBytes(key);
      final secretBox = SecretBox(
        cipherBody,
        nonce: envelope.iv,
        mac: Mac(macBytes),
      );
      final plainBytes = await _algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      return utf8.decode(plainBytes);
    } on SecretBoxAuthenticationError {
      throw const DecryptionFailureException(
        'GCM authentication tag verification failed. '
        'The document may have been tampered with or the encryption key is wrong.',
      );
    } catch (e, st) {
      throw DecryptionFailureException(
        'Unexpected error during AES-GCM decryption.',
        '${e.runtimeType}: $e\n$st',
      );
    }
  }

  // ── Private ──

  List<int> _generateIv() {
    final rng = Random.secure();
    return List.generate(_ivLength, (_) => rng.nextInt(256));
  }
}
