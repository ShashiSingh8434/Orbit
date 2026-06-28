import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../decision/views/decision_edit_sheet.dart';
import '../../learning/views/learning_edit_sheet.dart';
import '../../event/views/event_edit_sheet.dart';
import '../../tasks/views/tasks_page.dart';

class ArcActionFab extends StatefulWidget {
  final VoidCallback onTap;

  const ArcActionFab({super.key, required this.onTap});

  @override
  State<ArcActionFab> createState() => _ArcActionFabState();
}

class _ArcActionFabState extends State<ArcActionFab> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  OverlayEntry? _overlayEntry;
  Offset _dragPosition = Offset.zero;
  int? _hoveredIndex;

  final List<Map<String, dynamic>> _menuItems = [
    {
      'icon': Icons.gavel_rounded,
      'label': 'Decision',
      'color': Colors.amber,
    },
    {
      'icon': Icons.lightbulb_outline,
      'label': 'Learning',
      'color': Colors.orange,
    },
    {
      'icon': Icons.event,
      'label': 'Event',
      'color': Colors.blue,
    },
    {
      'icon': Icons.task_alt_rounded,
      'label': 'Task',
      'color': Colors.green,
    },
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _animController.dispose();
    super.dispose();
  }

  void _showOverlay(Offset fabCenter) {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        return GestureDetector(
          onLongPressMoveUpdate: (details) {
            setState(() {
              _dragPosition = details.globalPosition;
              _updateHover(fabCenter);
            });
            _overlayEntry?.markNeedsBuild();
          },
          onLongPressEnd: (details) {
            _handleSelection();
            _closeMenu();
          },
          child: Stack(
            children: [
              // Semi-transparent backdrop to highlight the arc FAB
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Container(
                    color: Colors.black.withAlpha((0.3 * 255 * _animController.value).round()),
                  );
                },
              ),
              // Radial Arc Buttons
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  const double radius = 100.0;
                  const double buttonSize = 56.0;

                  return Stack(
                    children: List.generate(_menuItems.length, (index) {
                      final item = _menuItems[index];
                      // Angle from 180 to 270 (quadrant of bottom right)
                      final double angle = 180.0 + (index * 30.0);
                      final double radians = angle * math.pi / 180.0;

                      final double dx = radius * _animController.value * math.cos(radians);
                      final double dy = radius * _animController.value * math.sin(radians);

                      final double x = fabCenter.dx + dx;
                      final double y = fabCenter.dy + dy;

                      final bool isHovered = _hoveredIndex == index;
                      final double scale = isHovered ? 1.3 : 1.0;

                      return Positioned(
                        left: x - buttonSize / 2,
                        top: y - buttonSize / 2,
                        child: Transform.scale(
                          scale: scale,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isHovered)
                                Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.onSurface,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item['label'],
                                      style: TextStyle(
                                        color: theme.colorScheme.surface,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                child: FloatingActionButton(
                                  heroTag: 'arc_item_$index',
                                  backgroundColor: isHovered
                                      ? item['color']
                                      : theme.colorScheme.secondaryContainer,
                                  foregroundColor: isHovered
                                      ? Colors.white
                                      : theme.colorScheme.onSecondaryContainer,
                                  onPressed: () {}, // Handled by gesture detector on release
                                  child: Icon(item['icon']),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animController.forward();
  }

  void _updateHover(Offset fabCenter) {
    const double radius = 100.0;
    const double hoverThreshold = 35.0;
    int? nextHovered;

    for (int i = 0; i < _menuItems.length; i++) {
      final double angle = 180.0 + (i * 30.0);
      final double radians = angle * math.pi / 180.0;

      final double dx = radius * math.cos(radians);
      final double dy = radius * math.sin(radians);

      final Offset btnCenter = Offset(fabCenter.dx + dx, fabCenter.dy + dy);
      final double distance = (_dragPosition - btnCenter).distance;

      if (distance < hoverThreshold) {
        nextHovered = i;
        break;
      }
    }

    if (_hoveredIndex != nextHovered) {
      _hoveredIndex = nextHovered;
    }
  }

  void _handleSelection() {
    if (_hoveredIndex == null) return;

    final contextToUse = context;
    final hovered = _hoveredIndex!;

    // Delay bottom sheet execution to let animations resolve cleanly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!contextToUse.mounted) return;

      switch (hovered) {
        case 0: // Decision
          showModalBottomSheet(
            context: contextToUse,
            isScrollControlled: true,
            builder: (context) => const DecisionEditSheet(),
          );
          break;
        case 1: // Learning
          showModalBottomSheet(
            context: contextToUse,
            isScrollControlled: true,
            builder: (context) => const LearningEditSheet(),
          );
          break;
        case 2: // Event
          showModalBottomSheet(
            context: contextToUse,
            isScrollControlled: true,
            builder: (context) => const EventEditSheet(),
          );
          break;
        case 3: // Task
          showModalBottomSheet(
            context: contextToUse,
            isScrollControlled: true,
            builder: (context) => const TaskEditSheet(),
          );
          break;
      }
    });
  }

  void _closeMenu() {
    _animController.reverse().then((_) {
      _removeOverlay();
    });
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    _hoveredIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: (details) {
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final Offset localCenter = Offset(renderBox.size.width / 2, renderBox.size.height / 2);
        final Offset globalCenter = renderBox.localToGlobal(localCenter);
        setState(() {
          _dragPosition = details.globalPosition;
          _hoveredIndex = null;
        });
        _showOverlay(globalCenter);
      },
      onLongPressMoveUpdate: (details) {
        // Handled by the gesture detector inside the overlay to capture off-bounds moves
      },
      onLongPressEnd: (details) {
        // Handled by the gesture detector inside the overlay
      },
      child: FloatingActionButton(
        heroTag: 'main_fab',
        onPressed: widget.onTap,
        child: const Icon(Icons.add),
      ),
    );
  }
}
