import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../../../core/ai/prompts/academic_timetable_prompt.dart';
import '../../../core/ai/services/multimodal_extraction_service.dart';
import '../../../core/security/models/crypto_models.dart';
import '../../../core/security/repository/encryption_repository.dart';
import '../../../core/security/services/key_manager.dart';
import '../../../core/security/services/crypto_service.dart';
import '../../../core/utils/app_logger.dart';
import '../models/academic_schedule.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final academicRepositoryProvider = Provider<AcademicRepository>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final extractor = ref.read(multimodalExtractionServiceProvider);
  return FirebaseAcademicRepository(
    prefs: prefs,
    extractor: extractor,
    enc: ref.watch(encryptionRepositoryProvider),
    keyManager: ref.read(keyManagerProvider),
    cryptoService: ref.read(cryptoServiceProvider),
  );
});

// ── Constants ─────────────────────────────────────────────────────────────────

const _kCollection = 'academic';

// ── Abstract Interface ────────────────────────────────────────────────────────

/// Repository responsible for handling Academic Timetable actions.
abstract class AcademicRepository {
  /// Sends the provided image bytes list to Gemini to parse into an [AcademicSchedule].
  Future<AcademicSchedule> parseTimetable(
    List<Uint8List> imageBytesList,
    List<String> mimeTypes,
  );

  /// Loads the academic schedule for [uid], checking the local encrypted cache
  /// first, then falling back to the encrypted Firestore document.
  Future<AcademicSchedule?> getSchedule(String uid);

  /// Encrypts and saves the schedule to both local cache and Firestore.
  Future<void> saveSchedule(String uid, AcademicSchedule schedule);

  /// Clears the schedule from both local cache and Firestore.
  Future<void> clearSchedule(String uid);
}

// ── Firebase Implementation ───────────────────────────────────────────────────

/// Firebase + SharedPreferences implementation.
///
/// Both the local cache (SharedPreferences) and the Firestore document are
/// stored in encrypted form. The local cache stores the [EncryptedEnvelope]
/// JSON string keyed by `orbit_enc_academic_{uid}`. This prevents an attacker
/// with local storage access from reading the timetable.
class FirebaseAcademicRepository implements AcademicRepository {
  FirebaseAcademicRepository({
    required this._prefs,
    required this._extractor,
    required this._enc,
    required this._keyManager,
    required this._cryptoService,
  });

  final SharedPreferences _prefs;
  final MultimodalExtractionService _extractor;
  final EncryptionRepository _enc;
  final KeyManager _keyManager;
  final CryptoService _cryptoService;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// SharedPreferences key for the encrypted timetable cache.
  static String _cacheKey(String uid) => 'orbit_enc_academic_$uid';

  DocumentReference<Map<String, dynamic>> _docRef(String uid) =>
      _db.collection('users').doc(uid).collection(_kCollection).doc('data');

  // ── Parse (AI extraction — no encryption needed here) ──

  @override
  Future<AcademicSchedule> parseTimetable(
    List<Uint8List> imageBytesList,
    List<String> mimeTypes,
  ) async {
    final prompt = AcademicTimetablePromptBuilder.buildPrompt();
    final schema = AcademicTimetablePromptBuilder.buildSchema();
    final data = await _extractor.extractData(
      imageBytesList: imageBytesList,
      mimeTypes: mimeTypes,
      prompt: prompt,
      responseSchema: schema,
    );
    return AcademicSchedule.fromJson(data);
  }

  // ── Get (check local encrypted cache → Firestore) ──

  @override
  Future<AcademicSchedule?> getSchedule(String uid) async {
    // 1. Try encrypted local cache
    final cachedEnvelope = _prefs.getString(_cacheKey(uid));
    if (cachedEnvelope != null) {
      try {
        final schedule = await _decryptCachedSchedule(uid, cachedEnvelope);
        if (schedule != null) return schedule;
      } catch (e) {
        AppLogger.warning(
          'AcademicRepository: Failed to decrypt cached schedule; '
          'falling back to Firestore. Error: $e',
        );
        // Ignore; fall through to Firestore
      }
    }

    // 2. Try Firestore (encrypted)
    try {
      final doc = await _docRef(uid).get();
      if (!doc.exists || doc.data() == null) return null;

      final plain = await _enc.decryptDocument(uid, _kCollection, doc.data()!);
      final schedule = AcademicSchedule.fromJson(
        Map<String, dynamic>.from(plain['schedule'] as Map),
      );

      // Refresh local cache
      await _encryptAndCacheSchedule(uid, schedule);
      return schedule;
    } catch (e) {
      AppLogger.error(
        'AcademicRepository: Failed to load schedule from Firestore. Error: $e',
      );
      return null;
    }
  }

  // ── Save ──

  @override
  Future<void> saveSchedule(String uid, AcademicSchedule schedule) async {
    // 1. Encrypt and cache locally
    await _encryptAndCacheSchedule(uid, schedule);

    // 2. Encrypt and save to Firestore
    try {
      final plainMap = {'schedule': schedule.toJson()};
      final encrypted = await _enc.encryptDocument(
        uid,
        _kCollection,
        plainMap,
        // Academic documents have no query index fields
        plaintextFields: const {},
      );
      await _docRef(uid).set(encrypted);
    } catch (e) {
      AppLogger.error(
        'AcademicRepository: Failed to save encrypted schedule to Firestore. '
        'Error: $e',
      );
    }
  }

  // ── Clear ──

  @override
  Future<void> clearSchedule(String uid) async {
    await _prefs.remove(_cacheKey(uid));
    try {
      await _docRef(uid).delete();
    } catch (_) {}
  }

  // ── Private helpers ──

  /// Encrypts [schedule] and writes the envelope JSON to SharedPreferences.
  Future<void> _encryptAndCacheSchedule(
    String uid,
    AcademicSchedule schedule,
  ) async {
    final masterKey = await _keyManager.getMasterKey(uid);
    final dek = await _keyManager.deriveCollectionKey(masterKey, _kCollection);
    final plaintext = jsonEncode(schedule.toJson());
    final envelope = await _cryptoService.encrypt(dek, plaintext);
    await _prefs.setString(_cacheKey(uid), envelope.toJsonString());
  }

  /// Decrypts the envelope JSON string from SharedPreferences.
  Future<AcademicSchedule?> _decryptCachedSchedule(
    String uid,
    String envelopeJson,
  ) async {
    // Handle legacy unencrypted cache (before encryption was added)
    if (!envelopeJson.startsWith('{') ||
        !envelopeJson.contains('"v"') ||
        !envelopeJson.contains('"ct"')) {
      // Legacy plaintext JSON — parse directly (will be re-cached encrypted)
      try {
        final raw = jsonDecode(envelopeJson) as Map<String, dynamic>;
        if (raw.containsKey('_schemaVersion') || raw.containsKey('_enc')) {
          return null; // Encrypted but not envelope format — skip
        }
        return AcademicSchedule.fromJson(raw);
      } catch (_) {
        return null;
      }
    }

    final envelope = EncryptedEnvelope.fromJsonString(envelopeJson);
    final masterKey = await _keyManager.getMasterKey(uid);
    final dek = await _keyManager.deriveCollectionKey(masterKey, _kCollection);
    final plaintext = await _cryptoService.decrypt(dek, envelope);
    final json = jsonDecode(plaintext) as Map<String, dynamic>;
    return AcademicSchedule.fromJson(json);
  }
}
