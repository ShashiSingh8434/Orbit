import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

/// Manages the app's theme mode (System / Light / Dark) and
/// persists the user's choice via [SharedPreferences].
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({required SharedPreferences prefs}) : _prefs = prefs {
    _loadSavedTheme();
  }

  final SharedPreferences _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(AppConstants.themeModeKey, mode.name);
  }

  void _loadSavedTheme() {
    final saved = _prefs.getString(AppConstants.themeModeKey);
    if (saved != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.system,
      );
    }
  }
}
