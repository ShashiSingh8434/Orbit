import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../decision/views/decision_edit_page.dart';
import '../../learning/views/learning_edit_page.dart';
import '../../event/views/event_edit_page.dart';
import '../../tasks/views/task_edit_page.dart';

/// A FAB that:
///  • On **tap** → runs [onTap] (e.g. open the home quick-add flow).
///  • On **long-press** → opens an animated vertical stack of four action
///    buttons rising upward above the FAB.

class ArcActionFab extends StatefulWidget {
  final VoidCallback onTap;

  const ArcActionFab({super.key, required this.onTap});

  @override
  State<ArcActionFab> createState() => _ArcActionFabState();
}

class _ArcActionFabState extends State<ArcActionFab>
    with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final AnimationController _pulseController;

  late final Animation<double> _fadeAnim;
  late final Animation<double> _pulseAnim;

  OverlayEntry? _overlayEntry;
  bool _isMenuOpen = false;

  // ── Menu item definitions (bottom → top order) ────────────────────────────
  static const _items = [
    _FabItem(
      icon: Icons.task_alt_rounded,
      label: 'Task',
      color: Color(0xFF22C55E),
    ),
    _FabItem(
      icon: Icons.event_rounded,
      label: 'Event',
      color: Color(0xFF3B82F6),
    ),
    _FabItem(
      icon: Icons.lightbulb_rounded,
      label: 'Learning',
      color: Color(0xFFF97316),
    ),
    _FabItem(
      icon: Icons.gavel_rounded,
      label: 'Decision',
      color: Color(0xFFF59E0B),
    ),
  ];

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    _pulseAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.06,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.06,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_pulseController);
  }

  @override
  void dispose() {
    _removeOverlay();
    _animController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Overlay lifecycle ──────────────────────────────────────────────────────

  void _openMenu() {
    if (_isMenuOpen) return;

    _isMenuOpen = true;
    _pulseController.stop();

    HapticFeedback.mediumImpact();

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset fabTopRight = box.localToGlobal(Offset(box.size.width, 0));

    _overlayEntry = OverlayEntry(
      builder: (_) => _VerticalMenuOverlay(
        fabTopRight: fabTopRight,
        items: _items,
        fadeAnim: _fadeAnim,
        animController: _animController,
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
      _pulseController.repeat();
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
          TaskEditPage.push(context);
          break;
        case 1:
          EventEditPage.push(context);
          break;
        case 2:
          LearningEditPage.push(context);
          break;
        case 3:
          DecisionEditPage.push(context);
          break;
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
        animation: Listenable.merge([_animController, _pulseController]),
        builder: (context, child) {
          return Transform.scale(
            scale: _isMenuOpen ? 1.0 : _pulseAnim.value,
            child: Transform.rotate(
              angle: _animController.value * 0.785398, // 45°
              child: child,
            ),
          );
        },
        child: FloatingActionButton(
          heroTag: 'main_fab',
          onPressed: null,
          elevation: 6,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }
}

// ── Vertical Menu Overlay ─────────────────────────────────────────────────────

class _VerticalMenuOverlay extends StatelessWidget {
  final Offset fabTopRight;
  final List<_FabItem> items;
  final Animation<double> fadeAnim;
  final AnimationController animController;
  final void Function(int index) onItemTap;
  final VoidCallback onDismiss;

  const _VerticalMenuOverlay({
    required this.fabTopRight,
    required this.items,
    required this.fadeAnim,
    required this.animController,
    required this.onItemTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Each row: icon(40) + gap(12) + label pill height(~36) = row height 52,
    // plus 10px gap between rows.
    const double rowHeight = 52.0;
    const double rowGap = 10.0;
    const double fabGap = 12.0; // gap between FAB top and first item bottom

    return Stack(
      children: [
        // ── Backdrop ──────────────────────────────────────────────────────
        GestureDetector(
          onTap: onDismiss,
          child: AnimatedBuilder(
            animation: fadeAnim,
            builder: (_, _) => Container(
              color: Colors.black.withAlpha(
                (0.4 * 255 * fadeAnim.value).round(),
              ),
            ),
          ),
        ),

        // ── Item rows ────────────────────────────────────────────────────
        ...List.generate(items.length, (i) {
          // i=0 is the bottom-most item (closest to FAB)
          final double bottomOffset =
              fabTopRight.dy - fabGap - (i * (rowHeight + rowGap)) - rowHeight;

          // Stagger: bottom items appear first
          final Animation<double> staggerAnim = CurvedAnimation(
            parent: animController,
            curve: Interval(
              i * 0.08,
              (i * 0.08 + 0.6).clamp(0.0, 1.0),
              curve: Curves.easeOutCubic,
            ),
          );

          return AnimatedBuilder(
            animation: staggerAnim,
            builder: (_, child) {
              return Positioned(
                top: bottomOffset + (1 - staggerAnim.value) * 16,
                // Align right edge with FAB right edge
                right: MediaQuery.of(context).size.width - fabTopRight.dx,
                child: Opacity(opacity: staggerAnim.value, child: child),
              );
            },
            child: _VerticalFabRow(item: items[i], onTap: () => onItemTap(i)),
          );
        }),
      ],
    );
  }
}

// ── Single Row: label + icon button ──────────────────────────────────────────

class _VerticalFabRow extends StatefulWidget {
  final _FabItem item;
  final VoidCallback onTap;

  const _VerticalFabRow({required this.item, required this.onTap});

  @override
  State<_VerticalFabRow> createState() => _VerticalFabRowState();
}

class _VerticalFabRowState extends State<_VerticalFabRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: widget.item.color,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: widget.item.color.withAlpha(100),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                widget.item.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Circle icon button
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.item.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.item.color.withAlpha(120),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(widget.item.icon, color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _FabItem {
  final IconData icon;
  final String label;
  final Color color;

  const _FabItem({
    required this.icon,
    required this.label,
    required this.color,
  });
}
