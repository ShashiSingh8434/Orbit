import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/app_logger.dart';
import '../exceptions/crypto_exceptions.dart';
import '../models/crypto_models.dart';
import '../repository/encryption_repository.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final migrationServiceProvider = Provider<MigrationService>(
  (ref) => MigrationService(ref.watch(encryptionRepositoryProvider)),
  name: 'migrationServiceProvider',
);

// ── Service ───────────────────────────────────────────────────────────────────

/// Handles lazy migration of legacy plaintext (v1) Firestore documents to the
/// AES-256-GCM encrypted format (v2).
///
/// ## Strategy
/// Migration is **lazy and transparent** — it happens automatically the first
/// time a v1 document is read by any repository. There is no batch migration
/// job; documents are upgraded one at a time as they are accessed.
///
/// ## Safety guarantees
/// - The migration is wrapped in a try/catch. If encryption fails (e.g.
///   because the master key is temporarily unavailable), the raw plaintext
///   map is returned so the user can still see their data. The document is
///   **not** written back as v1 — it remains v1 in Firestore until the next
///   successful read.
/// - No data is deleted during migration.
///
/// ## Document version detection
/// A document is considered v1 if it does not contain `_schemaVersion` or if
/// `_schemaVersion < 2`. Version 2 documents are passed through unchanged.
class MigrationService {
  MigrationService(this._enc);

  final EncryptionRepository _enc;

  /// Checks if [firestoreDoc] is a v1 plaintext document, and if so,
  /// re-encrypts it and persists the v2 version via [writer].
  ///
  /// Returns the plain model-ready map regardless of whether migration
  /// occurred, so the calling repository can immediately deserialise it.
  ///
  /// [uid] — Firebase user ID.
  /// [collection] — Firestore sub-collection name (e.g. `"reflections"`).
  /// [firestoreDoc] — The raw `Map<String, dynamic>` from Firestore.
  /// [plaintextFields] — Fields to keep outside the envelope (same set as
  ///   in [EncryptionRepository.encryptDocument]).
  /// [writer] — Async callback that persists the encrypted document back to
  ///   Firestore. Receives the v2 document map.
  Future<Map<String, dynamic>> migrateIfNeeded(
    String uid,
    String collection,
    Map<String, dynamic> firestoreDoc, {
    Set<String> plaintextFields = const {},
    required Future<void> Function(Map<String, dynamic> encrypted) writer,
  }) async {
    final schemaVersion = firestoreDoc['_schemaVersion'] as int? ?? 1;

    // Already v2 — decrypt and return
    if (schemaVersion >= EncryptionVersion.aesGcm256.value) {
      return _enc.decryptDocument(uid, collection, firestoreDoc);
    }

    // v1 — migrate
    AppLogger.info(
      'MigrationService: Migrating v1 → v2 document in "$collection" for uid=$uid',
    );

    try {
      // Encrypt the v1 map
      final encryptedDoc = await _enc.encryptDocument(
        uid,
        collection,
        firestoreDoc,
        plaintextFields: plaintextFields,
      );

      // Persist v2 back to Firestore
      await writer(encryptedDoc);
      AppLogger.info(
        'MigrationService: Successfully migrated document in "$collection" for uid=$uid',
      );

      // Return the original plaintext fields so the caller can parse the model
      return firestoreDoc;
    } on EncryptionException catch (e, st) {
      // Migration failed — log and return the plaintext v1 data so the user
      // still sees their content. Document remains v1 in Firestore.
      AppLogger.error(
        'MigrationService: Failed to migrate document in "$collection"; '
        'returning plaintext. Error: ${e.message}',
        e,
        st,
      );
      return firestoreDoc;
    } catch (e, st) {
      AppLogger.error(
        'MigrationService: Unexpected error during migration in "$collection".',
        e,
        st,
      );
      throw MigrationException(
        'Unexpected error during v1→v2 migration in "$collection".',
        e,
      );
    }
  }

  /// Returns `true` if [firestoreDoc] is a legacy v1 plaintext document.
  bool isV1Document(Map<String, dynamic> firestoreDoc) {
    final schemaVersion = firestoreDoc['_schemaVersion'] as int? ?? 1;
    return schemaVersion < EncryptionVersion.aesGcm256.value;
  }
}
