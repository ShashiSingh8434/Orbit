import 'package:flutter/material.dart';

/// A small selectable chip for reflection tags.
class ReflectionTagChip extends StatelessWidget {
  const ReflectionTagChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onDeleted,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InputChip(
      label: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: selected
              ? colorScheme.onPrimary
              : colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surfaceContainer,
      onSelected: onTap != null ? (_) => onTap!() : null,
      onDeleted: onDeleted,
      deleteIcon: onDeleted != null
          ? Icon(
              Icons.close_rounded,
              size: 14,
              color: selected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            )
          : null,
      side: BorderSide(
        color: selected ? Colors.transparent : colorScheme.outlineVariant,
        width: 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
