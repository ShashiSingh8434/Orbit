import 'dart:math' as math;
import 'package:flutter/material.dart';

class SubtleSpaceBackground extends StatefulWidget {
  const SubtleSpaceBackground({super.key, required this.child});

  final Widget child;

  @override
  State<SubtleSpaceBackground> createState() => _SubtleSpaceBackgroundState();
}

class _SubtleSpaceBackgroundState extends State<SubtleSpaceBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40), // slow and soothing
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
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _SubtleSpacePainter(
                  progress: _controller.value,
                  colorScheme: colorScheme,
                  isDark: isDark,
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

class _SubtleSpacePainter extends CustomPainter {
  _SubtleSpacePainter({
    required this.progress,
    required this.colorScheme,
    required this.isDark,
  });

  final double progress;
  final ColorScheme colorScheme;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw background nebula gradient
    if (isDark) {
      // Dark space: deep indigo, dark violet and deep blue gradients to make it slightly brighter than pure black
      final gradient = RadialGradient(
        center: const Alignment(0.3, -0.4),
        radius: 1.5,
        colors: const [
          Color(0xFF1E1E38), // Dark purple-blue (brighter than pure black)
          Color(0xFF0F0F1B), // Soft deep space blue
          Color(0xFF07070F), // Near-black boundary
        ],
      );
      paint.shader = gradient.createShader(Offset.zero & size);
    } else {
      // Light space: very soft pastel sky gradients (lavender, soft blue, near-white)
      final gradient = RadialGradient(
        center: const Alignment(-0.3, 0.4),
        radius: 1.5,
        colors: const [
          Color(0xFFD6E4FF), // Enhanced soft blue
          Color(0xFFE8D3FF), // Enhanced soft lavender
          Color(0xFFF1F4FB), // Cool light grey-blue (theme surface)
        ],
      );
      paint.shader = gradient.createShader(Offset.zero & size);
    }
    canvas.drawRect(Offset.zero & size, paint);
    paint.shader = null; // Clear shader

    // Draw stars
    _drawStars(canvas, size, paint);

    // Draw orbits
    _drawOrbits(canvas, size, paint);
  }

  void _drawStars(Canvas canvas, Size size, Paint paint) {
    final random = math.Random(12345); // deterministic seed
    paint.style = PaintingStyle.fill;

    for (int i = 0; i < 40; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final baseRadius = isDark 
          ? (random.nextDouble() * 1.2 + 0.4)
          : (random.nextDouble() * 1.8 + 0.6); // slightly larger in light mode

      // Twinkle animation
      final twinklePhase = random.nextDouble() * math.pi * 2;
      final twinkle = math.sin(progress * math.pi * 8 + twinklePhase) * 0.5 + 0.5;

      final baseColor = isDark ? Colors.white : colorScheme.primary;
      paint.color = baseColor.withValues(alpha: (isDark ? 0.05 : 0.12) + (twinkle * 0.25));
      canvas.drawCircle(Offset(x, y), baseRadius, paint);
    }
  }

  void _drawOrbits(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width * 0.5, size.height * 0.45);
    final orbitRadii = [size.width * 0.25, size.width * 0.45, size.width * 0.7];
    final planetSizes = [3.0, 4.5, 2.5];
    final speeds = [0.15, -0.08, 0.05]; // extremely slow
    
    // Warm accent colors for orbits/planets
    final colors = [
      colorScheme.primary.withValues(alpha: isDark ? 0.6 : 0.75),
      colorScheme.secondary.withValues(alpha: isDark ? 0.6 : 0.75),
      colorScheme.tertiary.withValues(alpha: isDark ? 0.6 : 0.75),
    ];

    for (int i = 0; i < orbitRadii.length; i++) {
      // Draw orbit path line
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 0.5;
      paint.color = (isDark ? Colors.white : colorScheme.primary).withValues(
        alpha: isDark ? 0.04 : 0.1,
      );
      
      // Draw slightly oval orbit to look three-dimensional
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: orbitRadii[i] * 2,
          height: orbitRadii[i] * 1.5,
        ),
        paint,
      );

      // Draw orbiting planet
      final angle = (progress * math.pi * 2 * speeds[i]) + (i * math.pi / 2);
      final px = center.dx + orbitRadii[i] * math.cos(angle);
      final py = center.dy + (orbitRadii[i] * 0.75) * math.sin(angle);

      paint.style = PaintingStyle.fill;
      paint.color = colors[i];
      canvas.drawCircle(Offset(px, py), planetSizes[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SubtleSpacePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.colorScheme != colorScheme;
  }
}
