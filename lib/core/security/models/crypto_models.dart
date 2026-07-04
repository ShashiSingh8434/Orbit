import 'dart:convert';
import 'dart:typed_data';

// ── Encryption Version ────────────────────────────────────────────────────────

/// Identifies the storage format of a Firestore document.
///
/// - [plaintext] (v1): Legacy documents written before encryption was enabled.
///   The repository will lazily re-encrypt them on the next write.
/// - [aesGcm256] (v2): Current encrypted format — AES-256-GCM with a random
///   12-byte IV and GCM authentication tag.
enum EncryptionVersion {
  plaintext(1),
  aesGcm256(2);

  const EncryptionVersion(this.value);

  /// Wire-format integer stored in `_schemaVersion` and inside the envelope.
  final int value;

  /// Parses from its wire integer. Unknown versions default to [plaintext]
  /// so that legacy documents are still read (and then migrated).
  static EncryptionVersion fromInt(int v) =>
      EncryptionVersion.values.firstWhere(
        (e) => e.value == v,
        orElse: () => EncryptionVersion.plaintext,
      );
}

// ── Encrypted Envelope ────────────────────────────────────────────────────────

/// Immutable envelope that wraps a single AES-256-GCM encrypted payload.
///
/// Stored as the JSON string value of the `_enc` field in every encrypted
/// Firestore document:
/// ```json
/// {
///   "_enc": "{\"v\":2,\"alg\":\"AES-256-GCM\",\"iv\":\"<base64>\",\"ct\":\"<base64>\"}",
///   "_schemaVersion": 2,
///   "id": "...",          // plaintext — needed for Firestore queries
///   "createdAt": <Timestamp> // plaintext — needed for orderBy
/// }
/// ```
///
/// The GCM authentication tag (16 bytes) is appended to [ciphertext] by the
/// cipher; no separate `tag` field is required.

class EncryptedEnvelope {
  const EncryptedEnvelope({
    required this.version,
    required this.algorithm,
    required this.iv,
    required this.ciphertext,
  });

  /// Envelope format version — always [EncryptionVersion.aesGcm256] when
  /// constructed by [CryptoService].
  final EncryptionVersion version;

  /// Algorithm identifier — `"AES-256-GCM"`.
  final String algorithm;

  /// 12-byte random IV/nonce used for this encryption operation.
  final Uint8List iv;

  /// AES-GCM ciphertext with the 16-byte authentication tag appended.
  final Uint8List ciphertext;

  // ── Serialisation ──

  factory EncryptedEnvelope.fromJson(Map<String, dynamic> json) {
    return EncryptedEnvelope(
      version: EncryptionVersion.fromInt(json['v'] as int),
      algorithm: json['alg'] as String,
      iv: base64Decode(json['iv'] as String),
      ciphertext: base64Decode(json['ct'] as String),
    );
  }

  /// Parses the raw JSON string stored in the `_enc` Firestore field.
  factory EncryptedEnvelope.fromJsonString(String raw) =>
      EncryptedEnvelope.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  Map<String, dynamic> toJson() => {
    'v': version.value,
    'alg': algorithm,
    'iv': base64Encode(iv),
    'ct': base64Encode(ciphertext),
  };

  /// Encodes to the compact JSON string written into Firestore.
  String toJsonString() => jsonEncode(toJson());
}

// ── Encrypted Key Blob ────────────────────────────────────────────────────────

/// Stores the user's master key, encrypted with their recovery passphrase.
///
/// Persisted at `users/{uid}/security/keyData` in Firestore.
/// This document is NOT sensitive on its own — it is an opaque blob that
/// can only be decrypted by someone who knows the recovery passphrase.
///
/// Structure:
/// ```json
/// {
///   "version": 1,
///   "salt":        "<base64 — 16 bytes>",
///   "iv":          "<base64 — 12 bytes>",
///   "encryptedKey":"<base64 — 48 bytes: 32 key + 16 GCM tag>",
///   "argon2Params": { "memory": 65536, "iterations": 3, "parallelism": 2 }
/// }
/// ```

class EncryptedKeyBlob {
  const EncryptedKeyBlob({
    required this.version,
    required this.salt,
    required this.iv,
    required this.encryptedKey,
    required this.argon2Memory,
    required this.argon2Iterations,
    required this.argon2Parallelism,
  });

  /// Blob format version. Currently 1.
  final int version;

  /// 16-byte random salt used as Argon2id input.
  final Uint8List salt;

  /// 12-byte AES-GCM IV used to encrypt the master key.
  final Uint8List iv;

  /// 48-byte payload: 32 bytes of encrypted master key + 16 bytes GCM tag.
  final Uint8List encryptedKey;

  /// Argon2id memory cost in KiB (default: 65 536 = 64 MiB).
  final int argon2Memory;

  /// Argon2id time cost (iterations). Default: 3.
  final int argon2Iterations;

  /// Argon2id parallelism degree. Default: 2.
  final int argon2Parallelism;

  // ── Serialisation ──

  factory EncryptedKeyBlob.fromJson(Map<String, dynamic> json) {
    final params = json['argon2Params'] as Map<String, dynamic>;
    return EncryptedKeyBlob(
      version: json['version'] as int,
      salt: base64Decode(json['salt'] as String),
      iv: base64Decode(json['iv'] as String),
      encryptedKey: base64Decode(json['encryptedKey'] as String),
      argon2Memory: params['memory'] as int,
      argon2Iterations: params['iterations'] as int,
      argon2Parallelism: params['parallelism'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'salt': base64Encode(salt),
    'iv': base64Encode(iv),
    'encryptedKey': base64Encode(encryptedKey),
    'argon2Params': {
      'memory': argon2Memory,
      'iterations': argon2Iterations,
      'parallelism': argon2Parallelism,
    },
  };
}
