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
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
      ),
      selected: selected,
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surfaceContainerHighest,
      onSelected: onTap != null ? (_) => onTap!() : null,
      deleteIcon: onDeleted != null
          ? Icon(Icons.close, size: 14, color: colorScheme.onSurface.withAlpha(120))
          : null,
      onDeleted: onDeleted,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
