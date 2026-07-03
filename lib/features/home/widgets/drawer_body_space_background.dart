import 'dart:math' as math;
import 'package:flutter/material.dart';

class DrawerBodySpaceBackground extends StatefulWidget {
  const DrawerBodySpaceBackground({super.key, required this.child});

  final Widget child;

  @override
  State<DrawerBodySpaceBackground> createState() => _DrawerBodySpaceBackgroundState();
}

class _DrawerBodySpaceBackgroundState extends State<DrawerBodySpaceBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20), // slow and soothing
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _DrawerBodySpacePainter(
                  progress: _controller.value,
                  isDark: isDark,
                  colorScheme: theme.colorScheme,
                ),
              );
            },
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _DrawerBodySpacePainter extends CustomPainter {
  _DrawerBodySpacePainter({
    required this.progress,
    required this.isDark,
    required this.colorScheme,
  });

  final double progress;
  final bool isDark;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // 1. Draw subtle background gradient to blend the drawer canvas color
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [
              const Color(0xFF1E2030), // matches theme canvas color
              const Color(0xFF131422), // deep midnight blue-black
            ]
          : [
              const Color(0xFFF1F4FB), // matches theme cool grey-blue
              const Color(0xFFE2E8F4), // slightly darker cool grey-blue
            ],
    );
    paint.shader = bgGradient.createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
    paint.shader = null;

    final random = math.Random(98765); // deterministic seed

    // 2. Draw low-opacity twinkling stars
    for (int i = 0; i < 15; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final baseRadius = random.nextDouble() * 1.0 + 0.3;
      final twinklePhase = random.nextDouble() * math.pi * 2;
      final twinkle = math.sin(progress * math.pi * 6 + twinklePhase) * 0.5 + 0.5;

      paint.color = (isDark ? Colors.white : colorScheme.primary)
          .withValues(alpha: (isDark ? 0.08 : 0.12) + (twinkle * 0.15));
      canvas.drawCircle(Offset(x, y), baseRadius, paint);
    }

    // 3. Draw subtle shooting stars (streaking diagonally)
    // Runs twice per progress cycle for visual activity
    final shootingStarProgress = (progress * 2.5) % 2.0;
    if (shootingStarProgress < 1.0) {
      final startX = size.width * (0.1 + random.nextDouble() * 0.2);
      final startY = size.height * (0.05 + random.nextDouble() * 0.15);
      final endX = size.width * 0.85;
      final endY = size.height * 0.65;

      final currentX = startX + (endX - startX) * shootingStarProgress;
      final currentY = startY + (endY - startY) * shootingStarProgress;

      final trailShader = LinearGradient(
        colors: [
          (isDark ? Colors.white : colorScheme.primary).withValues(alpha: 0.4),
          (isDark ? Colors.white : colorScheme.primary).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromPoints(
        Offset(currentX, currentY),
        Offset(currentX - 25, currentY - 18),
      ));

      final trailPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = trailShader;

      canvas.drawLine(
        Offset(currentX - 25, currentY - 18),
        Offset(currentX, currentY),
        trailPaint,
      );

      // Draw head
      paint.color = isDark ? Colors.white : colorScheme.primary;
      canvas.drawCircle(Offset(currentX, currentY), 1.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawerBodySpacePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
