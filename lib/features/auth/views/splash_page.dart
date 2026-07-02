import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/auth_controller.dart';
import '../../../app/router/app_routes.dart';

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

    Future.delayed(const Duration(milliseconds: 0), () {
      if (!mounted) return;
      final authValue = ref.read(authStateProvider).value;
      if (authValue != null) {
        context.go(AppRoutes.home);
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

class SpacePainter extends CustomPainter {
  final double orbitProgress;
  final double pulseProgress;
  final double starProgress;
  final ColorScheme colorScheme;
  final bool isDark;

  SpacePainter({
    required this.orbitProgress,
    required this.pulseProgress,
    required this.starProgress,
    required this.colorScheme,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final paint = Paint()..style = PaintingStyle.fill;

    _drawStars(canvas, size, paint);
    _drawOrbits(canvas, center, paint);
    _drawCore(canvas, center, paint);
    _drawText(canvas, center, size.height);
  }

  void _drawStars(Canvas canvas, Size size, Paint paint) {
    final random = math.Random(42);

    // Background twinkling stars
    paint.style = PaintingStyle.fill;
    for (int i = 0; i < 60; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final r = random.nextDouble() * 1.5 + 0.5;

      final twinklePhase = random.nextDouble() * math.pi * 2;
      final twinkle =
          math.sin(starProgress * math.pi * 4 + twinklePhase) * 0.5 + 0.5;

      final baseColor = isDark ? Colors.white : colorScheme.primary;
      paint.color = baseColor.withValues(alpha: 0.1 + (twinkle * 0.4));
      canvas.drawCircle(Offset(x, y), r, paint);
    }

    // Shooting stars
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;
    paint.strokeCap = StrokeCap.round;

    for (int i = 0; i < 3; i++) {
      final progress = (starProgress + (i * 0.33)) % 1.0;

      // Start off top right, go to bottom left
      final startX = size.width * 1.2 - (progress * size.width * 2.0);
      final startY = -size.height * 0.2 + (progress * size.height * 2.0);

      final endX = startX + 60.0;
      final endY = startY - 60.0;

      // Fade in and out
      double opacity = 0.0;
      if (progress > 0.1 && progress < 0.9) {
        opacity = math.sin((progress - 0.1) / 0.8 * math.pi) * 0.6;
      }

      paint.color = (isDark ? Colors.white : colorScheme.primary).withValues(
        alpha: opacity,
      );
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  void _drawCore(Canvas canvas, Offset center, Paint paint) {
    paint.style = PaintingStyle.fill;

    // Pulsing outer glow
    final glowRadius = 45.0 + (pulseProgress * 15.0);
    paint.color = colorScheme.primary.withValues(
      alpha: 0.2 - (pulseProgress * 0.1),
    );
    canvas.drawCircle(center, glowRadius, paint);

    // Main core
    paint.color = colorScheme.primary;
    canvas.drawCircle(center, 28.0, paint);

    // Inner bright core
    paint.color = colorScheme.onPrimary;
    canvas.drawCircle(center, 12.0, paint);
  }

  void _drawOrbits(Canvas canvas, Offset center, Paint paint) {
    final orbitRadii = [75.0, 125.0, 185.0];
    final planetSizes = [6.0, 10.0, 4.0];
    final speeds = [1.0, -0.6, 0.4];
    final colors = [
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.primary,
    ];

    for (int i = 0; i < orbitRadii.length; i++) {
      // Draw orbit path
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.0;
      paint.color = (isDark ? Colors.white : colorScheme.primary).withValues(
        alpha: 0.15,
      );
      canvas.drawCircle(center, orbitRadii[i], paint);

      // Draw orbiting planet
      final angle =
          (orbitProgress * math.pi * 2 * speeds[i]) + (i * math.pi / 2);
      final px = center.dx + orbitRadii[i] * math.cos(angle);
      final py = center.dy + orbitRadii[i] * math.sin(angle);

      paint.style = PaintingStyle.fill;
      paint.color = colors[i];
      canvas.drawCircle(Offset(px, py), planetSizes[i], paint);
    }
  }

  void _drawText(Canvas canvas, Offset center, double height) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'O R B I T',
        style: TextStyle(
          color: isDark ? Colors.white : colorScheme.primary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 12.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - (textPainter.width / 2) + 6.0, center.dy + 250),
    );

    // Pulsing loading dots
    final loadingPainter = TextPainter(
      text: TextSpan(
        text: 'Aligning stars...',
        style: TextStyle(
          color: (isDark ? Colors.white : colorScheme.primary).withValues(
            alpha: 0.5 + (pulseProgress * 0.5),
          ),
          fontSize: 14,
          letterSpacing: 2.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    loadingPainter.layout();
    loadingPainter.paint(
      canvas,
      Offset(center.dx - (loadingPainter.width / 2), center.dy + 290),
    );
  }

  @override
  bool shouldRepaint(covariant SpacePainter oldDelegate) => true;
}
