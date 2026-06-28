import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../decision/views/decision_edit_page.dart';
import '../../learning/views/learning_edit_page.dart';
import '../../event/views/event_edit_page.dart';
import '../../tasks/views/task_edit_page.dart';

/// A FAB that:
///  • On **tap** → runs [onTap] (e.g. open the home quick-add flow).
///  • On **long-press** → opens an animated radial arc of four action buttons.
///    Each arc button is also individually tappable (no drag required).
class ArcActionFab extends StatefulWidget {
  final VoidCallback onTap;

  const ArcActionFab({super.key, required this.onTap});

  @override
  State<ArcActionFab> createState() => _ArcActionFabState();
}

class _ArcActionFabState extends State<ArcActionFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  OverlayEntry? _overlayEntry;
  bool _isMenuOpen = false;

  // ── Menu item definitions ──────────────────────────────────────────────────
  static const _items = [
    _ArcItem(
      icon: Icons.gavel_rounded,
      label: 'Decision',
      color: Color(0xFFF59E0B),
    ),
    _ArcItem(
      icon: Icons.lightbulb_rounded,
      label: 'Learning',
      color: Color(0xFFF97316),
    ),
    _ArcItem(
      icon: Icons.event_rounded,
      label: 'Event',
      color: Color(0xFF3B82F6),
    ),
    _ArcItem(
      icon: Icons.task_alt_rounded,
      label: 'Task',
      color: Color(0xFF22C55E),
    ),
  ];

  // Arc geometry — larger radius keeps buttons clear of each other and the FAB.
  // Spread from 195° → 285°, shifted slightly more left so the rightmost button
  // (Task, at 285°) lands well inside the screen.
  static const double _radius = 140.0;
  static const double _startAngle = 195.0;
  static const double _sweepAngle = 90.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _removeOverlay();
    _animController.dispose();
    super.dispose();
  }

  // ── Overlay lifecycle ──────────────────────────────────────────────────────

  void _openMenu() {
    if (_isMenuOpen) return;
    _isMenuOpen = true;
    HapticFeedback.mediumImpact();

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset fabCenter = box.localToGlobal(
      Offset(box.size.width / 2, box.size.height / 2),
    );

    _overlayEntry = OverlayEntry(
      builder: (context) => _ArcOverlay(
        fabCenter: fabCenter,
        items: _items,
        animation: _animController,
        scaleAnim: _scaleAnim,
        fadeAnim: _fadeAnim,
        radius: _radius,
        startAngle: _startAngle,
        sweepAngle: _sweepAngle,
        onItemTap: (index) {
          _closeMenu();
          _navigate(index);
        },
        onDismiss: _closeMenu,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animController.forward();
  }

  void _closeMenu() {
    if (!_isMenuOpen) return;
    _animController.reverse().then((_) {
      _removeOverlay();
      _isMenuOpen = false;
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _navigate(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      switch (index) {
        case 0:
          DecisionEditPage.push(context);
        case 1:
          LearningEditPage.push(context);
        case 2:
          EventEditPage.push(context);
        case 3:
          TaskEditPage.push(context);
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_isMenuOpen) {
          _closeMenu();
        } else {
          widget.onTap();
        }
      },
      onLongPress: _openMenu,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _animController.value * math.pi / 4, // 45° when open
            child: child,
          );
        },
        child: FloatingActionButton(
          heroTag: 'main_fab',
          onPressed: null, // handled by GestureDetector
          elevation: 6,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }
}

// ── Arc Overlay ───────────────────────────────────────────────────────────────

class _ArcOverlay extends StatelessWidget {
  final Offset fabCenter;
  final List<_ArcItem> items;
  final AnimationController animation;
  final Animation<double> scaleAnim;
  final Animation<double> fadeAnim;
  final void Function(int index) onItemTap;
  final VoidCallback onDismiss;
  final double radius;
  final double startAngle;
  final double sweepAngle;

  const _ArcOverlay({
    required this.fabCenter,
    required this.items,
    required this.animation,
    required this.scaleAnim,
    required this.fadeAnim,
    required this.onItemTap,
    required this.onDismiss,
    required this.radius,
    required this.startAngle,
    required this.sweepAngle,
  });

  @override
  Widget build(BuildContext context) {
    // Button widget total height: label chip (~26) + gap (6) + circle (54) = ~86px
    // Half-width of the widest button content: ~40px
    const double buttonHalfW = 44.0;
    const double buttonH = 88.0;
    final double screenW = MediaQuery.of(context).size.width;
    final double screenH = MediaQuery.of(context).size.height;
    const double edgePadding = 12.0;

    return Stack(
      children: [
        // ── Backdrop ────────────────────────────────────────────────────────
        GestureDetector(
          onTap: onDismiss,
          child: AnimatedBuilder(
            animation: fadeAnim,
            builder: (_, __) => Container(
              color: Colors.black.withAlpha(
                (0.35 * 255 * fadeAnim.value).round(),
              ),
            ),
          ),
        ),

        // ── Arc buttons ─────────────────────────────────────────────────────
        AnimatedBuilder(
          animation: scaleAnim,
          builder: (context, _) {
            return Stack(
              children: List.generate(items.length, (i) {
                final item = items[i];
                final double angleDeg =
                    startAngle + (i / (items.length - 1)) * sweepAngle;
                final double rad = angleDeg * math.pi / 180.0;

                final double dx = radius * scaleAnim.value * math.cos(rad);
                final double dy = radius * scaleAnim.value * math.sin(rad);

                // Raw centre of the button
                double cx = fabCenter.dx + dx;
                double cy = fabCenter.dy + dy;

                // Clamp so the button never bleeds off-screen
                cx = cx.clamp(
                  edgePadding + buttonHalfW,
                  screenW - edgePadding - buttonHalfW,
                );
                cy = cy.clamp(
                  edgePadding + buttonH / 2,
                  screenH - edgePadding - buttonH / 2,
                );

                // Stagger each item's entrance slightly
                final double staggered = (scaleAnim.value - i * 0.08).clamp(
                  0.0,
                  1.0,
                );

                return Positioned(
                  // Centre the button widget on (cx, cy)
                  left: cx - buttonHalfW,
                  top: cy - buttonH / 2,
                  child: Opacity(
                    opacity: staggered,
                    child: Transform.scale(
                      scale: staggered,
                      child: _ArcButton(item: item, onTap: () => onItemTap(i)),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}

// ── Single Arc Button ─────────────────────────────────────────────────────────

class _ArcButton extends StatefulWidget {
  final _ArcItem item;
  final VoidCallback onTap;

  const _ArcButton({required this.item, required this.onTap});

  @override
  State<_ArcButton> createState() => _ArcButtonState();
}

class _ArcButtonState extends State<_ArcButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverCtrl;
  late Animation<double> _scaleHover;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleHover = Tween<double>(
      begin: 1.0,
      end: 1.18,
    ).animate(CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _hoverCtrl.forward(),
      onTapUp: (_) {
        _hoverCtrl.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _hoverCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleHover,
        builder: (_, child) =>
            Transform.scale(scale: _scaleHover.value, child: child),
        child: SizedBox(
          // Fixed-width container prevents label overflow and keeps layout stable
          width: 88,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Label chip ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: widget.item.color,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: widget.item.color.withAlpha(100),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  widget.item.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // ── Circle button ─────────────────────────────────────────────
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: widget.item.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.item.color.withAlpha(130),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(widget.item.icon, color: Colors.white, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _ArcItem {
  final IconData icon;
  final String label;
  final Color color;

  const _ArcItem({
    required this.icon,
    required this.label,
    required this.color,
  });
}
