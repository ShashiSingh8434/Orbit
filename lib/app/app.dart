import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:alarm/alarm.dart';
import '../core/constants/app_constants.dart';
import '../core/voice/global_voice_status_notch.dart';
import '../core/ai/views/global_ai_status_notch.dart';
import '../core/widgets/subtle_space_background.dart';
import 'router/app_router.dart';
import 'router/app_routes.dart';
import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';
import '../features/tasks/services/tasks_widget_sync_service.dart';
import '../features/tasks/controllers/task_controller.dart';
import '../features/tasks/models/task_model.dart';

/// Root widget of the Orbit application.
class OrbitApp extends ConsumerStatefulWidget {
  const OrbitApp({super.key});

  @override
  ConsumerState<OrbitApp> createState() => _OrbitAppState();
}

class _OrbitAppState extends ConsumerState<OrbitApp> with WidgetsBindingObserver {
  StreamSubscription<AlarmSettings>? _ringSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ringSubscription = Alarm.ringStream.stream.listen((alarmSettings) {
      ref.read(ringingAlarmProvider.notifier).state = alarmSettings;
    });

    _checkActiveRingingAlarms();
    TasksWidgetSyncService.checkAndSyncToggles(ref);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      TasksWidgetSyncService.checkAndSyncToggles(ref);
    }
  }

  Future<void> _checkActiveRingingAlarms() async {
    // Wait a brief moment to allow the router and widget tree to mount completely
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    try {
      final alarms = await Alarm.getAlarms();
      for (final alarm in alarms) {
        final isRinging = await Alarm.isRinging(alarm.id);
        if (isRinging) {
          ref.read(ringingAlarmProvider.notifier).state = alarm;
          break;
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ringSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep Tasks Widget in sync whenever any task changes in the database globally
    ref.listen<AsyncValue<List<TaskModel>>>(tasksProvider, (prev, next) {
      next.whenOrNull(
        data: (tasks) {
          TasksWidgetSyncService.syncTasks(tasks);
        },
      );
    });

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
            if (child != null)
              Builder(
                builder: (innerContext) {
                  String? location;
                  try {
                    location = GoRouterState.of(innerContext).matchedLocation;
                  } catch (_) {}
                  final showGlobalBackground = location != AppRoutes.bonus;
                  return showGlobalBackground
                      ? SubtleSpaceBackground(child: child)
                      : child;
                },
              ),
            const GlobalAiStatusNotch(),
            const GlobalVoiceStatusNotch(),
          ],
        );
      },
    );
  }
}
