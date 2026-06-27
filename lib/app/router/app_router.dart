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
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginPage(),
      ),

      // ── Authenticated ─────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const HomePage(),
        routes: [
          // Reflections
          GoRoute(
            path: 'reflections',
            builder: (_, __) => const ReflectionListPage(),
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
                builder: (_, state) => ReflectionListPage(
                  dateKey: state.pathParameters['date'],
                ),
              ),
            ],
          ),


          // Tasks
          GoRoute(
            path: 'tasks',
            builder: (_, __) => const TasksPage(),
          ),

          // Decisions
          GoRoute(
            path: 'decisions',
            builder: (_, __) => const DecisionListPage(),
          ),

          // Events
          GoRoute(
            path: 'events',
            builder: (_, __) => const EventListPage(),
          ),

          // Learnings
          GoRoute(
            path: 'learnings',
            builder: (_, __) => const LearningListPage(),
          ),

          // Guide
          GoRoute(
            path: 'guide',
            builder: (_, __) => const GuidePage(),
          ),

          // Settings
          GoRoute(
            path: 'settings',
            builder: (_, __) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );
});

// ── Auth Redirect Guard ───────────────────────────────────────────────────────
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue>(authStateProvider, (_, __) {
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
