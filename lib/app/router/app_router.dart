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
import '../../features/home/views/guide_page.dart';
import '../../features/home/views/bonus_page.dart';
import '../../features/day/views/detailed_summary_page.dart';
import '../../core/ai/analytics/ai_analytics_page.dart';
import '../../features/academic/models/academic_schedule.dart';
import '../../features/academic/views/academic_page.dart';
import '../../features/academic/views/courses_page.dart';
import '../../features/academic/views/edit_course_page.dart';
import 'app_routes.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
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
          // Bonus Page
          GoRoute(
            path: 'bonus',
            builder: (_, _) => const BonusPage(),
          ),
        ],
      ),
    ],
  );
});

// ── Auth Redirect Guard ───────────────────────────────────────────────────────
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue>(authStateProvider, (_, _) {
      notifyListeners();
    });
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authValue = _ref.read(authStateProvider);
    final loc = state.matchedLocation;

    if (loc == AppRoutes.splash) {
      return null;
    }

    if (authValue.isLoading) {
      return AppRoutes.splash;
    }

    final isAuthenticated = authValue.value != null;

    if (!isAuthenticated) {
      return loc == AppRoutes.login ? null : AppRoutes.login;
    }

    if (loc == AppRoutes.login) {
      return AppRoutes.home;
    }

    return null;
  }
}
