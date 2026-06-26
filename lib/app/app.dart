import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_constants.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import '../features/auth/views/auth_gate.dart';

/// Root widget for the Orbit application.
///
/// Consumes [ThemeProvider] to apply the correct light/dark theme
/// and routes to [AuthGate] which handles auth-based navigation.
class OrbitApp extends StatelessWidget {
  const OrbitApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const AuthGate(),
    );
  }
}
