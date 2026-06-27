import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/theme_notifier.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

/// Convenience re-export of [themeNotifierProvider] scoped to settings.
/// The UI only needs to import this file.
final settingsControllerProvider = themeNotifierProvider;

// ── Controller ────────────────────────────────────────────────────────────────

/// Thin wrapper exposing theme management to the settings view.
/// All persistence is handled by [ThemeNotifier].
extension SettingsActions on WidgetRef {
  void setTheme(ThemeMode mode) =>
      read(themeNotifierProvider.notifier).setThemeMode(mode);
}
