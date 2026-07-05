import 'package:flutter/material.dart';

/// An expandable accordion card for "How to Use" sections in the guide.
class UsageAccordion extends StatefulWidget {
  final String title;
  final IconData icon;
  final String details;

  const UsageAccordion({
    super.key,
    required this.title,
    required this.icon,
    required this.details,
  });

  @override
  State<UsageAccordion> createState() => _UsageAccordionState();
}

class _UsageAccordionState extends State<UsageAccordion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(widget.icon, color: cs.primary),
          title: Text(
            widget.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          onExpansionChanged: (val) => setState(() => _expanded = val),
          trailing: Icon(
            _expanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: cs.primary,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                widget.details,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
