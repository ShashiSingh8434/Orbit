import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';

/// A premium bottom action bar matching the custom curved dome design,
/// displaying Action items: Decision, Learning, Reflection (+), Event, and Task.
class BottomActionBar extends StatelessWidget {
  final VoidCallback onTap;

  const BottomActionBar({super.key, required this.onTap});

  Widget _buildBarItem(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      verticalOffset: 28,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: isDark ? 0.7 : 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      verticalOffset: 34,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Base height for the action bar (excluding the safe area bottom padding)
    const baseHeight = 64.0;
    final totalHeight = baseHeight + bottomPadding;

    final fillColor = isDark
        ? Colors.black.withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.95);
    final borderColor = colorScheme.outlineVariant.withValues(
      alpha: isDark ? 0.15 : 0.25,
    );
    final shadowColor = isDark ? Colors.black : Colors.grey;

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // ── Custom Painted Background Shape ──────────────────────────────────
        CustomPaint(
          size: Size(MediaQuery.of(context).size.width, totalHeight),
          painter: _BottomBarPainter(
            shadowColor: shadowColor,
            fillColor: fillColor,
            borderColor: borderColor,
            bottomPadding: bottomPadding,
          ),
        ),

        // ── Action Buttons Row ───────────────────────────────────────────────
        Container(
          height: totalHeight,
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Decision Button (Amber)
              _buildBarItem(
                context,
                icon: Icons.gavel_rounded,
                color: const Color(0xFFF59E0B),
                label: 'Decisions',
                tooltip: 'Decisions',
                onTap: () => context.push(AppRoutes.decisions),
              ),
              // 2. Learning Button (Orange)
              _buildBarItem(
                context,
                icon: Icons.lightbulb_rounded,
                color: const Color(0xFFF97316),
                label: 'Learnings',
                tooltip: 'Learnings',
                onTap: () => context.push(AppRoutes.learnings),
              ),
              // 3. Placeholder for Center Plus Button (Reflection text)
              Tooltip(
                message: 'Write Reflection',
                preferBelow: false,
                verticalOffset: 28,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onTap();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 64,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24), // space for circle overlap
                        const SizedBox(height: 4),
                        Text(
                          'Reflection',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: isDark ? 0.7 : 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 4. Event Button (Blue)
              _buildBarItem(
                context,
                icon: Icons.event_rounded,
                color: const Color(0xFF3B82F6),
                label: 'Events',
                tooltip: 'Events',
                onTap: () => context.push(AppRoutes.events),
              ),
              // 5. Task Button (Green)
              _buildBarItem(
                context,
                icon: Icons.task_alt_rounded,
                color: const Color(0xFF22C55E),
                label: 'Tasks',
                tooltip: 'Tasks',
                onTap: () => context.push(AppRoutes.tasks),
              ),
            ],
          ),
        ),

        // ── Protruding Center Action Button (+) ──────────────────────────────
        Positioned(
          top: -15, // aligns with custom painter topY
          child: _buildCenterButton(
            context,
            icon: Icons.add_rounded,
            color: colorScheme.primary,
            tooltip: 'Write Reflection',
            onTap: onTap,
          ),
        ),
      ],
    );
  }
}

class _BottomBarPainter extends CustomPainter {
  final Color shadowColor;
  final Color fillColor;
  final Color borderColor;
  final double bottomPadding;

  const _BottomBarPainter({
    required this.shadowColor,
    required this.fillColor,
    required this.borderColor,
    required this.bottomPadding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    const double topY = -15.0; // Dome peak relative to 0

    final path = Path();
    // Start at top-left corner
    path.moveTo(0, 20);

    // Top-left rounded corner
    path.quadraticBezierTo(0, 0, 20, 0);

    // Straight line to dome start
    path.lineTo(width / 2 - 50, 0);

    // Dome curve
    path.cubicTo(width / 2 - 30, 0, width / 2 - 30, topY, width / 2, topY);
    path.cubicTo(width / 2 + 30, topY, width / 2 + 30, 0, width / 2 + 50, 0);

    // Straight line to top-right
    path.lineTo(width - 20, 0);

    // Top-right rounded corner
    path.quadraticBezierTo(width, 0, width, 20);

    // Line down to bottom-right
    path.lineTo(width, height);

    // Line across to bottom-left
    path.lineTo(0, height);

    path.close();

    // Paint shadow (directed upwards)
    canvas.drawShadow(
      path.shift(const Offset(0, -1)),
      shadowColor.withValues(alpha: 0.12),
      12.0,
      true,
    );

    // Paint fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Paint border (top edge outline only)
    final borderPath = Path()
      ..moveTo(0, 20)
      ..quadraticBezierTo(0, 0, 20, 0)
      ..lineTo(width / 2 - 50, 0)
      ..cubicTo(width / 2 - 30, 0, width / 2 - 30, topY, width / 2, topY)
      ..cubicTo(width / 2 + 30, topY, width / 2 + 30, 0, width / 2 + 50, 0)
      ..lineTo(width - 20, 0)
      ..quadraticBezierTo(width, 0, width, 20);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(_BottomBarPainter old) =>
      old.shadowColor != shadowColor ||
      old.fillColor != fillColor ||
      old.borderColor != borderColor ||
      old.bottomPadding != bottomPadding;
}
