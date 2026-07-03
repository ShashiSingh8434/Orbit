import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/voice/global_voice_status_notch.dart';
import '../core/ai/views/global_ai_status_notch.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';

/// Root widget of the Orbit application.

class OrbitApp extends ConsumerWidget {
  const OrbitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeNotifierProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            // ignore: use_null_aware_elements
            if (child != null) child,
            const GlobalAiStatusNotch(),
            const GlobalVoiceStatusNotch(),
          ],
        );
      },
    );
  }
}
