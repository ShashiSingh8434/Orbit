import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/shared_preferences_provider.dart';

// ─── Keys ────────────────────────────────────────────────────────────────────

const _kHasSeenFirstRunOverlay = 'has_seen_first_run_overlay';

// ─── First-run notifier ───────────────────────────────────────────────────────

class FirstRunNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;

  FirstRunNotifier(this._prefs)
    : super(!(_prefs.getBool(_kHasSeenFirstRunOverlay) ?? false));

  /// Call this once the user has dismissed the overlay.
  Future<void> markSeen() async {
    await _prefs.setBool(_kHasSeenFirstRunOverlay, true);
    state = false;
  }

  /// Force-reset for debug / testing purposes.
  Future<void> reset() async {
    await _prefs.remove(_kHasSeenFirstRunOverlay);
    state = true;
  }
}

/// `true`  → user has NOT seen the first-run guide yet (show overlay).
/// `false` → user has already seen it (don't show).
final firstRunProvider = StateNotifierProvider<FirstRunNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FirstRunNotifier(prefs);
});
