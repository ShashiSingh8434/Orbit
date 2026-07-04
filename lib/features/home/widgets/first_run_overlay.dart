import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/first_run_provider.dart';

/// Wraps the home page body and injects a two-step first-run overlay via
/// Flutter's [Overlay], so it paints above the AppBar, FAB, and everything
/// else on screen.
///
/// Step 1 — spotlights the guide/info icon in the AppBar.
/// Step 2 — spotlights the FAB and explains tap vs long-press.
class FirstRunOverlay extends ConsumerStatefulWidget {
  final Widget child;

  /// Key attached to the guide [IconButton] in the AppBar.
  final GlobalKey guideIconKey;

  /// Key attached to the [BottomActionBar].
  final GlobalKey fabKey;

  const FirstRunOverlay({
    super.key,
    required this.child,
    required this.guideIconKey,
    required this.fabKey,
  });

  @override
  ConsumerState<FirstRunOverlay> createState() => _FirstRunOverlayState();
}

class _FirstRunOverlayState extends ConsumerState<FirstRunOverlay>
    with TickerProviderStateMixin {
  // 0 = guide icon step, 1 = FAB step, 2 = done
  int _step = 0;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulse = Tween<double>(
      begin: 1.0,
      end: 1.18,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1.0,
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Insert the overlay once, after the first frame so GlobalKeys are live.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureOverlay());
  }

  @override
  void dispose() {
    _removeOverlay();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Overlay lifecycle ──────────────────────────────────────────────────────

  void _ensureOverlay() {
    final isVisible = ref.read(firstRunProvider);
    if (!isVisible || _step == 2 || _entry != null) return;
    _entry = OverlayEntry(builder: (_) => _OverlayContent(state: this));
    Overlay.of(context).insert(_entry!);
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  void _rebuildOverlay() => _entry?.markNeedsBuild();

  // ── Coordinate helper ──────────────────────────────────────────────────────

  /// Returns the widget's bounding rect in **screen space**.
  ///
  /// Because the OverlayEntry fills the entire screen from (0,0), raw
  /// screen-space coordinates (localToGlobal with no ancestor) are exactly
  /// what the CustomPainter and Positioned widgets inside the Overlay need.
  /// No ancestor correction is required here — the Overlay IS the screen.
  Rect? _screenRectFor(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final pos = box.localToGlobal(Offset.zero); // screen space ✓
    return pos & box.size;
  }

  // ── Step navigation ────────────────────────────────────────────────────────

  Future<void> advance() async {
    if (_step == 0) {
      await _fadeCtrl.reverse();
      _step = 1;
      _rebuildOverlay();
      _fadeCtrl.forward();
    } else {
      await _fadeCtrl.reverse();
      _step = 2;
      _removeOverlay();
      await ref.read(firstRunProvider.notifier).markSeen();
    }
  }

  Future<void> skipAll() async {
    await _fadeCtrl.reverse();
    _step = 2;
    _removeOverlay();
    await ref.read(firstRunProvider.notifier).markSeen();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch so we react if the provider flips externally.
    final isVisible = ref.watch(firstRunProvider);
    if (!isVisible) _removeOverlay();
    // The child is always rendered normally — the overlay floats above it.
    return widget.child;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The actual overlay widget, inserted into the Navigator's Overlay.
// It fills the full screen (status bar + AppBar + body + nav bar).
// ─────────────────────────────────────────────────────────────────────────────

class _OverlayContent extends StatelessWidget {
  final _FirstRunOverlayState state;

  const _OverlayContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    final guideRect = state._screenRectFor(state.widget.guideIconKey);
    final fabRect = state._screenRectFor(state.widget.fabKey);
    final targetRect = state._step == 0
        ? guideRect?.inflate(8)
        : fabRect;

    return FadeTransition(
      opacity: state._fade,
      child: GestureDetector(
        onTap: state.advance,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: state._pulseCtrl,
          builder: (context, child) {
            return CustomPaint(
              size: screenSize,
              painter: _SpotlightPainter(
                targetRect: targetRect,
                pulseScale: state._pulse.value,
                step: state._step,
              ),
              child: child,
            );
          },
          child: Stack(
            children: [
              // ── Animated ring / Onboarding indicators ────────────────────
              if (targetRect != null)
                AnimatedBuilder(
                  animation: state._pulse,
                  builder: (context, _) {
                    if (state._step == 0) {
                      // Guide button: circle
                      final double ringDiameter =
                          (targetRect.longestSide + 40) * state._pulse.value;
                      return Positioned(
                        left: targetRect.center.dx - ringDiameter / 2,
                        top: targetRect.center.dy - ringDiameter / 2,
                        width: ringDiameter,
                        height: ringDiameter,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 2.5,
                            ),
                          ),
                        ),
                      );
                    } else {
                      // Bottom navigation bar: no ring is drawn, handled via assets below
                      return const SizedBox.shrink();
                    }
                  },
                ),

              // ── Navigation Bar Arrow & Text Overlay ──────────────────────
              if (targetRect != null && state._step == 1) ...[
                
                // Hand-drawn arrow asset matching current theme
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: (screenSize.height - targetRect.top) + 30, // 24px gap above the navigation bar
                  child: Center(
                    child: Image.asset(
                      Theme.of(context).brightness == Brightness.dark
                          ? 'assets/arrow_light.png'
                          : 'assets/arrow_black.png',
                      height: 85,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],

              // ── Callout card ─────────────────────────────────────────────
              _buildCallout(context, targetRect, screenSize),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallout(
    BuildContext context,
    Rect? targetRect,
    Size screenSize,
  ) {
    final isStep0 = state._step == 0;

    final title = isStep0 ? 'Your daily guide' : 'Quick capture';
    final body = isStep0
        ? 'Tap the ⓘ button any time to see how the app works — what to log, how AI helps, and what each section means.'
        : 'Tap the + button in the middle to write a reflection and let AI extract everything.\n\nOr tap the individual buttons next to it to quickly create tasks, events, learnings, and decisions.';
    final stepLabel = '${state._step + 1} of 2';
    final cta = isStep0 ? 'Got it →' : 'Let\'s go!';

    // Card is always centred on screen — only the ring tracks the target.
    return Positioned.fill(
      child: Center(
        child: SizedBox(
          width: 280,
          child: _CalloutCard(
            title: title,
            body: body,
            stepLabel: stepLabel,
            cta: cta,
            onTap: state.advance,
            onSkip: isStep0 ? state.skipAll : null,
          ),
        ),
      ),
    );
  }
}

// ── Callout card ──────────────────────────────────────────────────────────────

class _CalloutCard extends StatelessWidget {
  final String title;
  final String body;
  final String stepLabel;
  final String cta;
  final VoidCallback onTap;
  final VoidCallback? onSkip; // null on last step

  const _CalloutCard({
    required this.title,
    required this.body,
    required this.stepLabel,
    required this.cta,
    required this.onTap,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(70),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: cs.primary.withAlpha(60), width: 1.5),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                stepLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.onPrimaryContainer,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            // Body
            Text(
              body,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // CTA
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  cta,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),

            // Skip (first step only)
            if (onSkip != null) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: onSkip,
                  child: Text(
                    'Skip tour',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Spotlight painter ─────────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final double pulseScale;
  final int step;

  const _SpotlightPainter({
    required this.targetRect,
    required this.pulseScale,
    required this.step,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.7);

    if (targetRect == null) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    final fullPath = Path()..addRect(Offset.zero & size);
    final spotPath = Path();

    if (step == 0) {
      // Guide icon (circle)
      final double radius = (targetRect!.longestSide / 2 + 10) * pulseScale.clamp(1.0, 1.15);
      spotPath.addOval(Rect.fromCircle(center: targetRect!.center, radius: radius));
    } else {
      // Bottom navigation bar (custom shape matching BottomActionBar top dome)
      final double width = size.width;
      final double barTop = targetRect!.top;
      const double domeHeight = 15.0; // Dome peak relative to barTop
      final double height = size.height;

      spotPath.moveTo(0, barTop + 20);
      spotPath.quadraticBezierTo(0, barTop, 20, barTop);
      spotPath.lineTo(width / 2 - 50, barTop);
      spotPath.cubicTo(
        width / 2 - 30, barTop,
        width / 2 - 30, barTop - domeHeight,
        width / 2, barTop - domeHeight,
      );
      spotPath.cubicTo(
        width / 2 + 30, barTop - domeHeight,
        width / 2 + 30, barTop,
        width / 2 + 50, barTop,
      );
      spotPath.lineTo(width - 20, barTop);
      spotPath.quadraticBezierTo(width, barTop, width, barTop + 20);
      spotPath.lineTo(width, height);
      spotPath.lineTo(0, height);
      spotPath.close();
    }

    canvas.drawPath(
      Path.combine(PathOperation.difference, fullPath, spotPath),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.targetRect != targetRect || old.pulseScale != pulseScale || old.step != step;
}


