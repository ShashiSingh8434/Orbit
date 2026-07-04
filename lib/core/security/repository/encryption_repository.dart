import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/app_logger.dart';
import '../exceptions/crypto_exceptions.dart';
import '../models/crypto_models.dart';
import '../services/crypto_service.dart';
import '../services/key_manager.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final encryptionRepositoryProvider = Provider<EncryptionRepository>(
  (ref) => EncryptionRepository(
    keyManager: ref.read(keyManagerProvider),
    cryptoService: ref.read(cryptoServiceProvider),
  ),
  name: 'encryptionRepositoryProvider',
);

// ── Repository ────────────────────────────────────────────────────────────────

/// High-level encryption façade used by all Firebase repositories.
///
/// Encapsulates:
/// - Master key loading (from [KeyManager])
/// - Per-collection DEK derivation via HKDF (cached in memory)
/// - JSON serialisation of the plaintext map before encryption
/// - [EncryptedEnvelope] serialisation / deserialisation for Firestore
/// - Lazy v1 → v2 schema detection (actual migration logic is in
///   [MigrationService])
///
/// ## Usage — in a repository's `_toMap` / `_fromDoc` paths:
///
/// ```dart
/// // Write path
/// final encryptedDoc = await _enc.encryptDocument(
///   uid, 'reflections', plaintextMap,
///   plaintextFields: {'id', 'createdAt', 'updatedAt', 'deleted'},
/// );
/// await _col(uid, dateKey).doc(id).set(encryptedDoc);
///
/// // Read path
/// final plainMap = await _enc.decryptDocument(uid, 'reflections', firestoreData);
/// return ReflectionModel(...);
/// ```
///
/// ## In-memory DEK cache
/// Collection DEKs are cached for the lifetime of the `EncryptionRepository`
/// instance (i.e. the Riverpod provider scope). This avoids redundant HKDF
/// invocations on every document read/write.

class EncryptionRepository {
  EncryptionRepository({
    required this._keyManager,
    required this._cryptoService,
  });

  final KeyManager _keyManager;
  final CryptoService _cryptoService;

  // Cache: "$uid:$collection" → 32-byte collection DEK
  final Map<String, Uint8List> _dekCache = {};

  // ── Public API ────────────────────────────────────────────────────────────

  /// Encrypts [plainMap] and returns a Firestore-ready document map.
  ///
  /// Fields listed in [plaintextFields] are copied to the output document
  /// as-is (they remain unencrypted so Firestore can use them for queries and
  /// ordering). Everything else is JSON-encoded and encrypted into `_enc`.
  ///
  /// The output document always contains:
  /// - `_schemaVersion: 2` — allows version detection on reads.
  /// - `_enc: "<envelope JSON string>"` — the encrypted payload.
  /// - One entry per field listed in [plaintextFields].
  ///
  /// Firestore [Timestamp] values in [plaintextFields] are preserved as-is
  /// (they are passed through without any conversion by this layer).
  
  Future<Map<String, dynamic>> encryptDocument(
    String uid,
    String collection,
    Map<String, dynamic> plainMap, {
    Set<String> plaintextFields = const {},
  }) async {
    // 1. Extract plaintext fields (to keep outside the envelope)
    final plainPart = <String, dynamic>{};
    final encryptPart = <String, dynamic>{};

    for (final entry in plainMap.entries) {
      if (plaintextFields.contains(entry.key)) {
        plainPart[entry.key] = entry.value;
      } else {
        encryptPart[entry.key] = entry.value;
      }
    }

    // 2. JSON-encode the portion to encrypt.
    //    Firestore Timestamps are not JSON-serialisable; convert them to ISO strings
    //    so they survive the JSON round-trip. They are reconstructed in decryptDocument.
    final jsonString = jsonEncode(_toJsonSafe(encryptPart));

    // 3. Get the collection DEK
    final dek = await _getDek(uid, collection);

    // 4. AES-256-GCM encrypt
    final envelope = await _cryptoService.encrypt(dek, jsonString);

    // 5. Assemble the final Firestore document
    return {
      '_schemaVersion': EncryptionVersion.aesGcm256.value,
      '_enc': envelope.toJsonString(),
      ...plainPart,
    };
  }

  /// Decrypts a Firestore document map and returns the fully reconstructed
  /// plaintext field map.
  ///
  /// - v1 documents (no `_schemaVersion` or `_schemaVersion == 1`) are
  ///   returned as-is so the caller can decide whether to migrate them.
  ///   The [MigrationService] handles the actual re-encryption.
  /// - v2 documents are decrypted and the plaintext fields are merged back
  ///   into the result.
  ///
  /// Returns a map that looks exactly like the original [plainMap] that was
  /// passed to [encryptDocument], making the encryption layer transparent to
  /// the model deserialization code.
  Future<Map<String, dynamic>> decryptDocument(
    String uid,
    String collection,
    Map<String, dynamic> firestoreDoc,
  ) async {
    final schemaVersion = firestoreDoc['_schemaVersion'] as int? ?? 1;

    // v1 — plaintext, return as-is (migration handled by MigrationService)
    if (schemaVersion < EncryptionVersion.aesGcm256.value) {
      return firestoreDoc;
    }

    // v2 — decrypt
    final encString = firestoreDoc['_enc'] as String?;
    if (encString == null) {
      throw const MalformedEnvelopeException(
        'Document is marked as v2 but has no "_enc" field.',
      );
    }

    EncryptedEnvelope envelope;
    try {
      envelope = EncryptedEnvelope.fromJsonString(encString);
    } catch (e) {
      throw MalformedEnvelopeException(
        'Failed to parse encrypted envelope: $e',
      );
    }

    final dek = await _getDek(uid, collection);
    final jsonString = await _cryptoService.decrypt(dek, envelope);

    final decryptedMap = jsonDecode(jsonString) as Map<String, dynamic>;
    final fromJsonConverted = _fromJsonSafe(decryptedMap);

    // Extract only the plaintext-index fields (not internal _* fields)
    final plaintextFields = {
      for (final entry in firestoreDoc.entries)
        if (!entry.key.startsWith('_')) entry.key: entry.value,
    };

    // Merge: decrypted fields take precedence over plaintext index copies
    return {...plaintextFields, ...fromJsonConverted};
  }

  /// Returns true if [uid] has a master key ready in secure storage.
  Future<bool> isReadyForUser(String uid) =>
      _keyManager.isMasterKeyPresent(uid);

  /// Clears the in-memory DEK cache for [uid]. Call this on sign-out.
  void clearCacheForUser(String uid) {
    _dekCache.removeWhere((key, _) => key.startsWith('$uid:'));
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<Uint8List> _getDek(String uid, String collection) async {
    final cacheKey = '$uid:$collection';
    if (_dekCache.containsKey(cacheKey)) return _dekCache[cacheKey]!;

    final masterKey = await _keyManager.getMasterKey(uid);
    final dek = await _keyManager.deriveCollectionKey(masterKey, collection);
    _dekCache[cacheKey] = dek;
    AppLogger.debug(
      'EncryptionRepository: DEK derived and cached for $cacheKey',
    );
    return dek;
  }

  /// Converts a map so it can be JSON-encoded:
  /// - [Timestamp] → ISO-8601 string (prefixed with `__ts:` for round-trip)
  /// - [DateTime] → ISO-8601 string
  /// - Nested maps and lists are handled recursively.
  dynamic _toJsonSafe(dynamic value) {
    if (value is Timestamp) {
      return '__ts:${value.toDate().toUtc().toIso8601String()}';
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is Map<String, dynamic>) {
      return value.map((k, v) => MapEntry(k, _toJsonSafe(v)));
    }
    if (value is List) {
      return value.map(_toJsonSafe).toList();
    }
    return value;
  }

  /// Reverse of [_toJsonSafe]: reconstructs [Timestamp] values from
  /// `__ts:` prefixed strings.
  dynamic _fromJsonSafe(dynamic value) {
    if (value is String && value.startsWith('__ts:')) {
      final isoString = value.substring(5);
      return Timestamp.fromDate(DateTime.parse(isoString));
    }
    if (value is Map<String, dynamic>) {
      return value.map((k, v) => MapEntry(k, _fromJsonSafe(v)));
    }
    if (value is List) {
      return value.map(_fromJsonSafe).toList();
    }
    return value;
  }
}
