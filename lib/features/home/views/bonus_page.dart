import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BonusPage extends ConsumerStatefulWidget {
  const BonusPage({super.key});

  @override
  ConsumerState<BonusPage> createState() => _BonusPageState();
}

class _ShootingStar {
  _ShootingStar({
    required this.startX,
    required this.startY,
    required this.progress,
  });

  final double startX;
  final double startY;
  double progress; // ranges from 0.0 to 1.0
}

class _BonusPageState extends ConsumerState<BonusPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ShootingStar> _interactiveStars = [];
  bool _isCardExpanded = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spawnShootingStar(Offset position) {
    setState(() {
      _interactiveStars.add(_ShootingStar(
        startX: position.dx,
        startY: position.dy,
        progress: 0.0,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF040408), // pure dark outer space background
      body: Stack(
        children: [
          // 1. Core animated canvas (interactive)
          Positioned.fill(
            child: GestureDetector(
              onTapDown: (details) => _spawnShootingStar(details.localPosition),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  // Advance interactive star animations
                  final toRemove = <_ShootingStar>[];
                  for (final star in _interactiveStars) {
                    star.progress += 0.04; // speed of swipe
                    if (star.progress >= 1.0) {
                      toRemove.add(star);
                    }
                  }
                  for (final star in toRemove) {
                    _interactiveStars.remove(star);
                  }

                  return CustomPaint(
                    painter: _DetailedSaturnPainter(
                      progress: _controller.value,
                      interactiveStars: List.from(_interactiveStars),
                      colorScheme: colorScheme,
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. Floating glassmorphic Back Button
          Positioned(
            top: 20,
            left: 20,
            child: SafeArea(
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.1),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Floating glassmorphic Saturn Facts Card
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: SafeArea(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0x1AFFFFFF),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.blur_circular_rounded,
                                    color: Colors.amberAccent, size: 28),
                                const SizedBox(width: 8),
                                Text(
                                  'Saturn Explorer',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(
                                _isCardExpanded
                                    ? Icons.keyboard_arrow_down_rounded
                                    : Icons.keyboard_arrow_up_rounded,
                                color: Colors.white70,
                              ),
                              onPressed: () => setState(() =>
                                  _isCardExpanded = !_isCardExpanded),
                            ),
                          ],
                        ),
                        if (_isCardExpanded) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Tapped locations summon shooting stars! Watch three moons (Titan, Rhea, Enceladus) orbit the gas giant with proper 3D depth alignment.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white12, height: 1),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStat('Diameter', '116,460 km'),
                              _buildStat('Moons', '146 confirmed'),
                              _buildStat('Orbits', '29.5 Earth yrs'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _DetailedSaturnPainter extends CustomPainter {
  _DetailedSaturnPainter({
    required this.progress,
    required this.interactiveStars,
    required this.colorScheme,
  });

  final double progress;
  final List<_ShootingStar> interactiveStars;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 20);
    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(11111); // seed for cosmos elements

    // 1. Cosmic radial nebula background
    final bgShader = RadialGradient(
      center: const Alignment(0.0, -0.1),
      radius: 1.4,
      colors: const [
        Color(0xFF0F1026), // Cosmic indigo center
        Color(0xFF05050C), // Midnight deep space
        Color(0xFF010103), // Boundary dark void
      ],
    ).createShader(Offset.zero & size);
    paint.shader = bgShader;
    canvas.drawRect(Offset.zero & size, paint);
    paint.shader = null;

    // 2. Draw 80+ twinkling background stars
    for (int i = 0; i < 80; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final baseRadius = random.nextDouble() * 1.5 + 0.3;
      final twinklePhase = random.nextDouble() * math.pi * 2;
      final twinkle = math.sin(progress * math.pi * 12 + twinklePhase) * 0.5 + 0.5;

      // Color variation (some stars are slightly blue or red)
      Color starColor = Colors.white;
      if (i % 8 == 0) starColor = const Color(0xFFAEC6FF); // blue-white
      if (i % 12 == 0) starColor = const Color(0xFFFFD2D2); // red-white

      paint.color = starColor.withValues(alpha: 0.15 + twinkle * 0.65);
      canvas.drawCircle(Offset(x, y), baseRadius, paint);
    }

    // 3. Draw passive shooting stars
    final passiveProgress = (progress * 3.5) % 4.0;
    if (passiveProgress < 1.0) {
      final startX = size.width * 0.1;
      final startY = size.height * 0.1;
      final endX = size.width * 0.95;
      final endY = size.height * 0.7;

      final curX = startX + (endX - startX) * passiveProgress;
      final curY = startY + (endY - startY) * passiveProgress;

      _drawShootingStarTrail(canvas, Offset(curX, curY), const Color(0xFF8183FF));
    }

    // 4. Draw interactive tapped shooting stars
    for (final star in interactiveStars) {
      final endX = star.startX + 200;
      final endY = star.startY + 150;
      final curX = star.startX + (endX - star.startX) * star.progress;
      final curY = star.startY + (endY - star.startY) * star.progress;
      
      _drawShootingStarTrail(canvas, Offset(curX, curY), Colors.amberAccent);
    }

    // ── Planet Setup ─────────────────────────────────────────────────────────
    const planetRadius = 48.0;

    // Define Moon orbits
    // Moon 1: Enceladus (Fast, close)
    final enceladusPos = _calculateMoonPos(progress * 2.5, 90.0, 20.0, center);
    // Moon 2: Rhea (Medium speed, mid distance)
    final rheaPos = _calculateMoonPos(progress * 1.4 + 1.5, 140.0, 30.0, center);
    // Moon 3: Titan (Slow, far distance)
    final titanPos = _calculateMoonPos(progress * 0.6 + 3.2, 220.0, 50.0, center);

    // Depth Sorting checks:
    // A moon is behind Saturn if its unrotated y is < 0 (i.e. math.sin(angle) < 0)
    final enceladusIsFront = math.sin(progress * 2.5 * math.pi * 2) >= 0;
    final rheaIsFront = math.sin((progress * 1.4 + 1.5) * math.pi * 2) >= 0;
    final titanIsFront = math.sin((progress * 0.6 + 3.2) * math.pi * 2) >= 0;

    // 5. Draw Moons (Behind Phase)
    paint.shader = null;
    _drawMoon(canvas, paint, enceladusPos, enceladusIsFront, planetRadius, center, 4.0, const Color(0xFFE2E2E8));
    _drawMoon(canvas, paint, rheaPos, rheaIsFront, planetRadius, center, 6.0, const Color(0xFFC4D4E3));
    _drawMoon(canvas, paint, titanPos, titanIsFront, planetRadius, center, 10.0, const Color(0xFFFFEFA6));

    // 6. Draw Back Rings (rendered behind Saturn body)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-14 * math.pi / 180); // tilt Saturn rings

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-size.width, -size.height, size.width, 0));
    _drawDetailedSaturnRings(canvas, paint);
    canvas.restore();

    canvas.restore(); // restore tilt

    // 7. Draw Saturn Body
    final planetPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        colors: const [
          Color(0xFFFFF0D0), // super bright gaseous highlights
          Color(0xFFECB474), // orange-gold atmospheric gas
          Color(0xFF90562D), // shadow side transition
          Color(0xFF2C190D), // dark shadow side
        ],
        stops: const [0.0, 0.45, 0.85, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: planetRadius));
    canvas.drawCircle(center, planetRadius, planetPaint);

    // Draw atmospheric gas bands
    final bandPaint = Paint()..style = PaintingStyle.fill;
    final bands = [
      _SaturnBand(yOffset: -22.0, height: 4.0, color: const Color(0xFF6B3C1B).withValues(alpha: 0.12)),
      _SaturnBand(yOffset: -12.0, height: 6.0, color: const Color(0xFF965B33).withValues(alpha: 0.15)),
      _SaturnBand(yOffset: -2.0, height: 9.0, color: const Color(0xFFDCA16E).withValues(alpha: 0.2)),
      _SaturnBand(yOffset: 12.0, height: 5.0, color: const Color(0xFF7A431F).withValues(alpha: 0.18)),
      _SaturnBand(yOffset: 24.0, height: 7.0, color: const Color(0xFF5E2F13).withValues(alpha: 0.22)),
    ];

    canvas.save();
    final sphereClip = Path()..addOval(Rect.fromCircle(center: center, radius: planetRadius));
    canvas.clipPath(sphereClip);
    for (final band in bands) {
      bandPaint.color = band.color;
      canvas.drawRect(
        Rect.fromLTRB(
          center.dx - planetRadius - 10,
          center.dy + band.yOffset,
          center.dx + planetRadius + 10,
          center.dy + band.yOffset + band.height,
        ),
        bandPaint,
      );
    }
    canvas.restore();

    // 8. Draw Front Rings (rendered in front of Saturn body)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-14 * math.pi / 180); // tilt Saturn rings

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-size.width, 0, size.width, size.height));
    _drawDetailedSaturnRings(canvas, paint);
    canvas.restore();

    canvas.restore(); // restore tilt

    // 9. Draw Moons (Front Phase)
    paint.shader = null;
    _drawMoon(canvas, paint, enceladusPos, !enceladusIsFront, planetRadius, center, 4.0, const Color(0xFFE2E2E8));
    _drawMoon(canvas, paint, rheaPos, !rheaIsFront, planetRadius, center, 6.0, const Color(0xFFC4D4E3));
    _drawMoon(canvas, paint, titanPos, !titanIsFront, planetRadius, center, 10.0, const Color(0xFFFFEFA6));
  }

  void _drawShootingStarTrail(Canvas canvas, Offset currentPos, Color headColor) {
    final trailShader = LinearGradient(
      colors: [
        headColor.withValues(alpha: 0.6),
        headColor.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromPoints(
      currentPos,
      Offset(currentPos.dx - 45, currentPos.dy - 34),
    ));

    final trailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = trailShader;

    canvas.drawLine(
      Offset(currentPos.dx - 45, currentPos.dy - 34),
      currentPos,
      trailPaint,
    );

    // Draw shining core head
    final headPaint = Paint()..color = Colors.white;
    canvas.drawCircle(currentPos, 1.5, headPaint);
    headPaint.color = headColor.withValues(alpha: 0.4);
    canvas.drawCircle(currentPos, 3.5, headPaint);
  }

  Offset _calculateMoonPos(double p, double rx, double ry, Offset center) {
    final angle = p * math.pi * 2;
    final mx = rx * math.cos(angle);
    final my = ry * math.sin(angle);

    // Rotate the coordinates to match Saturn's -14 degree axis tilt
    final cosTheta = math.cos(-14 * math.pi / 180);
    final sinTheta = math.sin(-14 * math.pi / 180);
    final rotX = center.dx + (mx * cosTheta - my * sinTheta);
    final rotY = center.dy + (mx * sinTheta + my * cosTheta);

    return Offset(rotX, rotY);
  }

  void _drawMoon(
    Canvas canvas,
    Paint paint,
    Offset position,
    bool shouldDraw,
    double planetRadius,
    Offset center,
    double radius,
    Color color,
  ) {
    if (!shouldDraw) return;

    // Check if the moon is covered behind the Saturn body
    final distToCenter = (position - center).distance;
    if (!shouldDraw && distToCenter <= planetRadius) return;

    paint.color = color;
    canvas.drawCircle(position, radius, paint);

    // Add a soft glow indicator
    paint.color = Colors.white.withValues(alpha: 0.25);
    canvas.drawCircle(position, radius + 2.5, paint);
  }

  void _drawDetailedSaturnRings(Canvas canvas, Paint paint) {
    // Rings are drawn inside a tilted space coordinate system
    // Ring Dimensions (A, B, C rings and Cassini Division gap)
    const rings = [
      _SaturnRingLayer(inner: 56.0, outer: 68.0, colorStart: Color(0xFF5E4935), colorEnd: Color(0xFF8F765A)), // C Ring (Dark)
      _SaturnRingLayer(inner: 70.0, outer: 94.0, colorStart: Color(0xFFECDBB2), colorEnd: Color(0xFFC7B38D)), // B Ring (Bright)
      _SaturnRingLayer(inner: 98.0, outer: 114.0, colorStart: Color(0xFFB0997F), colorEnd: Color(0xFF7A6553)), // A Ring (Medium)
    ];

    for (final layer in rings) {
      final ringRect = Rect.fromLTRB(-layer.outer, -layer.outer * 0.23, layer.outer, layer.outer * 0.23);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (layer.outer - layer.inner) * 0.23
        ..shader = RadialGradient(
          colors: [
            layer.colorStart.withValues(alpha: 0.15),
            layer.colorStart.withValues(alpha: 0.85),
            layer.colorEnd.withValues(alpha: 0.95),
            layer.colorEnd.withValues(alpha: 0.35),
          ],
          stops: const [0.0, 0.45, 0.75, 1.0],
        ).createShader(ringRect);

      final double middleRadiusX = (layer.inner + layer.outer) / 2;
      final double middleRadiusY = middleRadiusX * 0.23;

      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: middleRadiusX * 2, height: middleRadiusY * 2),
        ringPaint,
      );
    }

    // Cassini Division Gap (between A and B rings)
    final gapPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF010103).withValues(alpha: 0.95);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 96.0 * 2, height: (96.0 * 0.23) * 2),
      gapPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DetailedSaturnPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.interactiveStars.length != interactiveStars.length;
  }
}

class _SaturnRingLayer {
  const _SaturnRingLayer({
    required this.inner,
    required this.outer,
    required this.colorStart,
    required this.colorEnd,
  });

  final double inner;
  final double outer;
  final Color colorStart;
  final Color colorEnd;
}

class _SaturnBand {
  const _SaturnBand({
    required this.yOffset,
    required this.height,
    required this.color,
  });

  final double yOffset;
  final double height;
  final Color color;
}
