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
    // Increased duration from 60 to 180 seconds for a much slower, calmer orbit
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 180),
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
                painter: _SolarSystemPainter(
                  progress: _controller.value,
                  colorScheme: theme.colorScheme,
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

class _SolarSystemPainter extends CustomPainter {
  _SolarSystemPainter({
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

    // 1. Draw Deep Space Background
    _drawBackground(canvas, size, paint);

    // 2. Draw Distant Stars
    _drawStars(canvas, size, paint);

    // 3. Draw the Solar System (Sun, Orbits, Planets, Moons)
    _drawSolarSystem(canvas, size, paint);
  }

  void _drawBackground(Canvas canvas, Size size, Paint paint) {
    if (isDark) {
      final gradient = RadialGradient(
        center: const Alignment(0.0, 0.0),
        radius: 1.5,
        colors: const [
          Color(0xFF1E1E38), // Center cosmic glow
          Color(0xFF0F0F1B), // Deep space
          Color(0xFF05050A), // Void
        ],
      );
      paint.shader = gradient.createShader(Offset.zero & size);
    } else {
      final gradient = RadialGradient(
        center: const Alignment(0.0, 0.0),
        radius: 1.5,
        colors: const [
          Color(0xFFE8EDFF), // Bright center
          Color(0xFFD6E4FF), // Soft sky blue
          Color(0xFFF1F4FB), // Light fade
        ],
      );
      paint.shader = gradient.createShader(Offset.zero & size);
    }
    canvas.drawRect(Offset.zero & size, paint);
    paint.shader = null;
  }

  void _drawStars(Canvas canvas, Size size, Paint paint) {
    final random = math.Random(42); // Fixed seed for stable stars
    paint.style = PaintingStyle.fill;

    for (int i = 0; i < 60; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final baseRadius = random.nextDouble() * (isDark ? 1.5 : 2.0) + 0.5;

      // Slower twinkle effect (reduced multiplier from 10 to 4)
      final twinklePhase = random.nextDouble() * math.pi * 2;
      final twinkle = math.sin(progress * math.pi * 4 + twinklePhase) * 0.5 + 0.5;

      final baseColor = isDark ? Colors.white : colorScheme.primary;
      // Reduced base alpha and twinkle intensity for a subtler look
      paint.color = baseColor.withValues(alpha: (isDark ? 0.03 : 0.05) + (twinkle * 0.1));
      canvas.drawCircle(Offset(x, y), baseRadius, paint);
    }
  }

  void _drawSolarSystem(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    
    // Slant configuration for 3D perspective
    const double flattenRatio = 0.35; // How flat the orbits look (0 to 1)
    
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 8); // Tilt the whole system

    // --- Planet Configurations ---
    // [Radius from sun, Planet Size, Orbit Speed multiplier, Color]
    final planets = [
      _PlanetData(size.width * 0.15, 2.5, 4.0, isDark ? Colors.grey[400]! : Colors.grey[600]!), // Mercury-ish
      _PlanetData(size.width * 0.28, 4.5, 2.5, isDark ? Colors.orange[300]! : Colors.orange[400]!), // Venus-ish
      _PlanetData(size.width * 0.45, 5.0, 1.5, colorScheme.primary, hasMoon: true), // Earth-ish
      _PlanetData(size.width * 0.60, 3.5, 1.0, isDark ? Colors.redAccent[100]! : Colors.red[400]!), // Mars-ish
      _PlanetData(size.width * 0.85, 8.0, 0.5, colorScheme.tertiary), // Jupiter-ish
    ];

    for (int i = 0; i < planets.length; i++) {
      final p = planets[i];

      // Draw Orbit Ring
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 0.5;
      // Reduced orbit opacity to make lines fainter
      paint.color = (isDark ? Colors.white : colorScheme.primary)
          .withValues(alpha: isDark ? 0.03 : 0.08);
      
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.orbitRadius * 2,
          height: p.orbitRadius * 2 * flattenRatio,
        ),
        paint,
      );

      // Calculate Planet Position
      final startingAngle = i * (math.pi / 1.5);
      final angle = (progress * math.pi * 2 * p.speed) + startingAngle;
      
      final px = p.orbitRadius * math.cos(angle);
      final py = (p.orbitRadius * flattenRatio) * math.sin(angle);

      // Draw Planet
      paint.style = PaintingStyle.fill;
      // Reduced planet opacity so they blend into the background (0.4 / 0.5 instead of 0.8 / 0.9)
      paint.color = p.color.withValues(alpha: isDark ? 0.4 : 0.5);
      canvas.drawCircle(Offset(px, py), p.size, paint);

      // Draw Moon (if applicable)
      if (p.hasMoon) {
        final moonOrbitRadius = p.size * 2.5;
        // Reduced moon speed from 15 to 6 so it orbits more calmly
        final moonAngle = (progress * math.pi * 2 * 6) + startingAngle; 
        
        final mx = px + moonOrbitRadius * math.cos(moonAngle);
        final my = py + (moonOrbitRadius * flattenRatio) * math.sin(moonAngle);

        // Faded moon colors
        paint.color = (isDark ? Colors.white70 : Colors.blueGrey)
            .withValues(alpha: isDark ? 0.4 : 0.5);
        canvas.drawCircle(Offset(mx, my), p.size * 0.3, paint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SolarSystemPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.colorScheme != colorScheme;
  }
}

// Helper class to hold planet configuration
class _PlanetData {
  final double orbitRadius;
  final double size;
  final double speed;
  final Color color;
  final bool hasMoon;

  _PlanetData(this.orbitRadius, this.size, this.speed, this.color, {this.hasMoon = false});
}