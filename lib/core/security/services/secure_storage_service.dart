import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../exceptions/crypto_exceptions.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final secureStorageServiceProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
  name: 'secureStorageServiceProvider',
);

// ── Service ───────────────────────────────────────────────────────────────────

/// Thin, typed wrapper over [FlutterSecureStorage] that reads and writes raw
/// key bytes as base64-encoded strings.
///
/// Platform security guarantees:
/// - **Android**: `EncryptedSharedPreferences` backed by Android Keystore
///   (AES-256-GCM, hardware-backed on devices that support it).
/// - **iOS / macOS**: Keychain with `first_unlock_this_device` accessibility
///   (readable after first unlock; NOT accessible in iCloud backup).
/// - **Windows**: DPAPI (`CryptProtectData`).
///
/// All operations are atomic at the platform level. There is no in-memory
/// caching here — the encryption layer caches derived keys to avoid repeated
/// secure-storage reads.
class SecureStorageService {
  SecureStorageService()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
        mOptions: MacOsOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
        wOptions: WindowsOptions(useBackwardCompatibility: false),
      );

  final FlutterSecureStorage _storage;

  // ── Read ──

  /// Reads binary key material stored under [keyId].
  ///
  /// Throws [KeyNotFoundException] if no value exists.
  Future<Uint8List> readKey(String keyId) async {
    final encoded = await _storage.read(key: keyId);
    if (encoded == null) {
      throw KeyNotFoundException('No key found for keyId="$keyId".');
    }
    return base64Decode(encoded);
  }

  // ── Write ──

  /// Writes [bytes] to secure storage under [keyId], overwriting any previous
  /// value atomically.
  Future<void> writeKey(String keyId, Uint8List bytes) async {
    await _storage.write(key: keyId, value: base64Encode(bytes));
  }

  // ── Existence ──

  /// Returns `true` if a value is stored under [keyId].
  Future<bool> containsKey(String keyId) async {
    return _storage.containsKey(key: keyId);
  }

  // ── Delete ──

  /// Permanently removes the entry for [keyId] from secure storage.
  /// No-ops if the key does not exist.
  Future<void> deleteKey(String keyId) async {
    await _storage.delete(key: keyId);
  }

  /// Removes **all** values from secure storage.
  ///
  /// ⚠️ Call this only during a full account-delete flow — not on sign-out,
  /// since the user should be able to recover with their passphrase.
  Future<void> deleteAllKeys() async {
    await _storage.deleteAll();
  }
}
