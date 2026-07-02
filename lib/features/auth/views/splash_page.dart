import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/space_painter.dart';
import '../controllers/auth_controller.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/utils/app_logger.dart';
import '../../app_update/providers/app_update_provider.dart';
import '../../app_update/views/update_dialog.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  late AnimationController _orbitController;
  late AnimationController _pulseController;
  late AnimationController _starController;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    Future.delayed(const Duration(milliseconds: 0), () async {
      if (!mounted) return;
      final authValue = ref.read(authStateProvider).value;
      if (authValue != null) {
        AppLogger.info(
          'Startup check: User is authenticated. Checking for updates...',
        );
        try {
          final result = await ref
              .read(appUpdateProvider.notifier)
              .checkForUpdates();
          if (result != null && result.updateRequired && mounted) {
            final optionalDismissed = ref
                .read(appUpdateProvider)
                .optionalUpdateDismissed;
            if (result.forceUpdate || !optionalDismissed) {
              AppLogger.info(
                'Update is required (force=${result.forceUpdate}). Displaying update dialog.',
              );
              if (mounted) {
                await showDialog(
                  context: context,
                  barrierDismissible: !result.forceUpdate,
                  builder: (context) => UpdateDialog(
                    config: result.config!,
                    installedVersionName: result.installedVersionName,
                    installedVersionCode: result.installedVersionCode,
                  ),
                );
              }
            }
          }
        } catch (e, stackTrace) {
          AppLogger.error(
            'Startup update check failed. Continuing initialization.',
            e,
            stackTrace,
          );
        }

        if (mounted) {
          context.go(AppRoutes.home);
        }
      } else {
        context.go(AppRoutes.login);
      }
    });
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    _starController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _orbitController,
            _pulseController,
            _starController,
          ]),
          builder: (context, child) {
            return CustomPaint(
              size: const Size(double.infinity, double.infinity),
              painter: SpacePainter(
                orbitProgress: _orbitController.value,
                pulseProgress: _pulseController.value,
                starProgress: _starController.value,
                colorScheme: colorScheme,
                isDark: isDark,
              ),
            );
          },
        ),
      ),
    );
  }
}
