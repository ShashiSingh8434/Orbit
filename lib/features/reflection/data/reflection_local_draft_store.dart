import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/shared_preferences_provider.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final reflectionDraftStoreProvider = Provider<ReflectionDraftStore>(
  (ref) => ReflectionDraftStore(ref.watch(sharedPreferencesProvider)),
);

// ── Draft Store ───────────────────────────────────────────────────────────────

/// Persists in-progress reflection drafts locally via [SharedPreferences].
///
/// Each user gets one draft slot keyed by UID.
/// Future migration: swap to `hive` or `drift` for richer offline support.
class ReflectionDraftStore {
  ReflectionDraftStore(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String uid) => 'orbit_reflection_draft_$uid';

  /// Returns the saved draft for [uid], or `null` if none exists.
  ReflectionDraft? loadDraft(String uid) {
    final raw = _prefs.getString(_key(uid));
    if (raw == null) return null;
    try {
      return ReflectionDraft.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  /// Saves [draft] for [uid], overwriting any existing draft.
  Future<void> saveDraft(String uid, ReflectionDraft draft) async {
    await _prefs.setString(_key(uid), jsonEncode(draft.toJson()));
  }

  /// Clears the draft for [uid] (called after a successful save to Firestore).
  Future<void> clearDraft(String uid) async {
    await _prefs.remove(_key(uid));
  }
}

// ── Draft Model ───────────────────────────────────────────────────────────────

class ReflectionDraft {
  const ReflectionDraft({required this.text, required this.tags, required this.savedAt});

  final String text;
  final List<String> tags;
  final DateTime savedAt;

  factory ReflectionDraft.fromJson(Map<String, dynamic> json) => ReflectionDraft(
        text: json['text'] as String? ?? '',
        tags: List<String>.from(json['tags'] as List? ?? []),
        savedAt: DateTime.parse(json['savedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'tags': tags,
        'savedAt': savedAt.toIso8601String(),
      };
}
