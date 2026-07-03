import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/app_logger.dart';

/// Wrapper around [FlutterSecureStorage] for encrypted API key management.
///
/// Keys are stored in Android Keystore / iOS Keychain — never in plaintext,
/// never in Firestore, never in SharedPreferences.
class SecureKeyStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _keyPrefix = 'orbit_ai_key_';

  /// Save an API key for a provider. Overwrites any existing key.
  static Future<void> saveKey(String providerId, String apiKey) async {
    await _storage.write(key: '$_keyPrefix$providerId', value: apiKey);
    AppLogger.debug('SecureKeyStorage: Saved key for $providerId');
  }

  /// Retrieve the stored API key for a provider. Returns `null` if not set.
  static Future<String?> getKey(String providerId) async {
    return _storage.read(key: '$_keyPrefix$providerId');
  }

  /// Delete the stored API key for a provider.
  static Future<void> deleteKey(String providerId) async {
    await _storage.delete(key: '$_keyPrefix$providerId');
    AppLogger.debug('SecureKeyStorage: Deleted key for $providerId');
  }

  /// Whether a key exists for the given provider.
  static Future<bool> hasKey(String providerId) async {
    final key = await _storage.read(key: '$_keyPrefix$providerId');
    return key != null && key.isNotEmpty;
  }

  /// Delete all stored API keys.
  static Future<void> clearAll() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(_keyPrefix)) {
        await _storage.delete(key: key);
      }
    }
    AppLogger.debug('SecureKeyStorage: Cleared all keys');
  }
}
