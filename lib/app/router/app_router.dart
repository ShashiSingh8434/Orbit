import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/auth/views/splash_page.dart';
import '../../features/auth/views/login_page.dart';
import '../../features/home/views/home_page.dart';
import '../../features/reflection/views/reflection_list_page.dart';
import '../../features/reflection/views/reflection_edit_page.dart';
import '../../features/tasks/views/tasks_page.dart';
import '../../features/decision/views/decision_list_page.dart';
import '../../features/event/views/event_list_page.dart';
import '../../features/learning/views/learning_list_page.dart';
import '../../features/settings/views/settings_page.dart';
import '../../features/guide/views/guide_page.dart';
import '../../features/about/about_page.dart';
import '../../features/day/views/detailed_summary_page.dart';
import '../../core/ai/analytics/ai_analytics_page.dart';
import '../../features/academic/models/academic_schedule.dart';
import '../../features/academic/views/academic_page.dart';
import '../../features/academic/views/courses_page.dart';
import '../../features/academic/views/edit_course_page.dart';
import '../../features/academic/views/academic_reminder_settings_page.dart';
import '../../features/academic/views/academic_reminder_ringing_page.dart';
import 'package:alarm/alarm.dart';
import '../../core/security/services/recovery_service.dart';
import '../../core/security/views/passphrase_setup_page.dart';
import '../../core/security/views/passphrase_recovery_page.dart';
import '../../core/utils/app_logger.dart';
import 'app_routes.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

/// Tracks the active ringing alarm settings.
final ringingAlarmProvider = StateProvider<AlarmSettings?>((ref) => null);

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  // Re-run redirect whenever auth state changes
  ref.listen(authStateProvider, (prev, next) {
    AppLogger.info('Router: authStateProvider changed. Notifying listeners.');
    notifier.refresh();
  });

  // Re-run redirect whenever current encryption state changes
  ref.listen(currentEncryptionStateProvider, (prev, next) {
    AppLogger.info(
      'Router: currentEncryptionStateProvider changed. Notifying listeners.',
    );
    notifier.refresh();
  });

  // Re-run redirect whenever ringing alarm state changes
  ref.listen(ringingAlarmProvider, (prev, next) {
    AppLogger.info(
      'Router: ringingAlarmProvider changed. Notifying listeners.',
    );
    notifier.refresh();
  });

  return GoRouter(
    debugLogDiagnostics: true,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    initialLocation: AppRoutes.splash,

    // ── Deep-link configuration ──────────────────────────────────────────
    // Scheme: orbit://
    // orbit://reflection/:date  → /home/reflections/:date
    // orbit://weekly            → /home/weekly
    // orbit://task/:id          → /home/tasks/:id
    // orbit://settings          → /home/settings
    routes: [
      // ── Unauthenticated ───────────────────────────────────────────────
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginPage()),
      GoRoute(
        path: AppRoutes.academicReminderRinging,
        builder: (_, state) {
          final alarm = state.extra as AlarmSettings?;
          if (alarm != null) {
            return AcademicReminderRingingPage(alarmSettings: alarm);
          }
          final ringing = ref.read(ringingAlarmProvider);
          if (ringing != null) {
            return AcademicReminderRingingPage(alarmSettings: ringing);
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),

      // ── Encryption gate (authenticated but not yet encrypted-ready) ───
      GoRoute(
        path: AppRoutes.setupPassphrase,
        builder: (_, _) => const PassphraseSetupPage(),
      ),
      GoRoute(
        path: AppRoutes.recoverPassphrase,
        builder: (_, _) => const PassphraseRecoveryPage(),
      ),

      // ── Authenticated ─────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) => const HomePage(),
        routes: [
          // Reflections
          GoRoute(
            path: 'reflections',
            builder: (_, _) => const ReflectionListPage(),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return ReflectionEditPage(
                    dateKey: extra?['dateKey'] as String?,
                    existingReflectionId: extra?['reflectionId'] as String?,
                  );
                },
              ),
              GoRoute(
                path: ':date',
                builder: (_, state) =>
                    ReflectionListPage(dateKey: state.pathParameters['date']),
              ),
            ],
          ),

          // Tasks
          GoRoute(path: 'tasks', builder: (_, _) => const TasksPage()),

          // Decisions
          GoRoute(
            path: 'decisions',
            builder: (_, _) => const DecisionListPage(),
          ),

          // Events
          GoRoute(path: 'events', builder: (_, _) => const EventListPage()),

          // Learnings
          GoRoute(
            path: 'learnings',
            builder: (_, _) => const LearningListPage(),
          ),

          // Guide
          GoRoute(path: 'guide', builder: (_, _) => const GuidePage()),

          // About
          GoRoute(path: 'about', builder: (_, _) => const AboutPage()),

          // Academic
          GoRoute(
            path: 'academic',
            builder: (_, _) => const AcademicPage(),
            routes: [
              GoRoute(path: 'courses', builder: (_, _) => const CoursesPage()),
              GoRoute(
                path: 'edit-course',
                builder: (_, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return EditCoursePage(course: extra?['course'] as Course?);
                },
              ),
              GoRoute(
                path: 'reminder-settings',
                builder: (_, _) => const AcademicReminderSettingsPage(),
              ),
            ],
          ),

          // Settings
          GoRoute(path: 'settings', builder: (_, _) => const SettingsPage()),

          // Detailed Summary
          GoRoute(
            path: 'detailed-summary',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final date = extra?['date'] as DateTime? ?? DateTime.now();
              return DetailedSummaryPage(date: date);
            },
          ),

          // AI Analytics
          GoRoute(
            path: 'ai-analytics',
            builder: (_, _) => const AiAnalyticsPage(),
          ),
        ],
      ),
    ],
  );
});

// ── Auth + Encryption Redirect Guard ─────────────────────────────────────────

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref);

  final Ref _ref;
  String? _pendingLocation;

  void refresh() => notifyListeners();

  /// Determines the redirect destination based on auth + encryption state.
  ///
  /// Priority order:
  /// 1. Unauthenticated → /login
  /// 2. Authenticated but encryption state loading → / (Splash screen)
  /// 3. Authenticated and encryption state needsSetup → /setup-passphrase
  /// 4. Authenticated and encryption state needsRecovery → /recover-passphrase
  /// 5. Authenticated and encryption state ready → /home
  String? redirect(BuildContext context, GoRouterState state) {
    final loc = state.matchedLocation;

    // Check if any alarm is ringing and redirect immediately
    final ringingAlarm = _ref.read(ringingAlarmProvider);
    if (ringingAlarm != null) {
      if (loc != AppRoutes.academicReminderRinging) {
        return AppRoutes.academicReminderRinging;
      }
      return null;
    }

    // Exempt academic reminder ringing screen from all security guards
    if (loc == AppRoutes.academicReminderRinging) {
      return null;
    }

    final authValue = _ref.read(authStateProvider);
    final user = authValue.value;
    final isAuthenticated = user != null;
    final encState = _ref.read(currentEncryptionStateProvider);
    final stateValue = encState.value;

    // Save pending location if we are not yet ready/authenticated
    if (loc != AppRoutes.splash &&
        loc != AppRoutes.login &&
        loc != AppRoutes.setupPassphrase &&
        loc != AppRoutes.recoverPassphrase &&
        loc != AppRoutes.academicReminderRinging) {
      if (authValue.isLoading || !isAuthenticated || encState.isLoading || stateValue != EncryptionState.ready) {
        _pendingLocation = state.uri.toString();
        AppLogger.info('Router: Saved pending deep link/target location: $_pendingLocation');
      }
    }

    AppLogger.info(
      'Router: Redirect called for loc: $loc. Auth status: isAuthenticated=$isAuthenticated, isLoading=${authValue.isLoading}',
    );

    // 1. Auth still loading -> show splash
    if (authValue.isLoading) {
      AppLogger.info('Router: Auth is loading. Directing/staying on Splash.');
      if (loc == AppRoutes.splash) return null;
      return AppRoutes.splash;
    }

    // 2. Not authenticated -> go to login
    if (!isAuthenticated) {
      AppLogger.info('Router: Unauthenticated. Directing to Login.');
      if (loc == AppRoutes.login || loc == AppRoutes.splash) return null;
      return AppRoutes.login;
    }

    // 3. Authenticated -> Check Encryption State
    AppLogger.info(
      'Router: Authenticated user. Encryption status: value=${encState.value}, isLoading=${encState.isLoading}',
    );

    // 3a. Encryption state still loading -> keep showing splash screen
    if (encState.isLoading) {
      AppLogger.info(
        'Router: Encryption state is loading. Directing/staying on Splash.',
      );
      if (loc == AppRoutes.splash) return null;
      return AppRoutes.splash;
    }

    if (stateValue == null) {
      AppLogger.info(
        'Router: Encryption state value is null. Directing/staying on Splash.',
      );
      if (loc == AppRoutes.splash) return null;
      return AppRoutes.splash;
    }

    // 3b. Encryption state resolved
    AppLogger.info('Router: Encryption state resolved to: $stateValue');
    switch (stateValue) {
      case EncryptionState.needsSetup:
        if (loc == AppRoutes.setupPassphrase) return null;
        AppLogger.info('Router: Redirecting to setup passphrase.');
        return AppRoutes.setupPassphrase;

      case EncryptionState.needsRecovery:
        if (loc == AppRoutes.recoverPassphrase) return null;
        AppLogger.info('Router: Redirecting to recover passphrase.');
        return AppRoutes.recoverPassphrase;

      case EncryptionState.ready:
        // If on splash, login, or gate screens, go to home or the pending location
        if (loc == AppRoutes.splash ||
            loc == AppRoutes.login ||
            loc == AppRoutes.setupPassphrase ||
            loc == AppRoutes.recoverPassphrase) {
          final target = _pendingLocation ?? AppRoutes.home;
          _pendingLocation = null; // Clear it so we don't redirect repeatedly
          AppLogger.info('Router: Encryption is ready. Redirecting to target: $target');
          return target;
        }
        return null;
    }
  }
}
