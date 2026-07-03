import 'package:flutter/material.dart';

class StyledTabBar extends StatelessWidget {
  final TabController controller;

  const StyledTabBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TabBar(
      controller: controller,
      indicatorColor: colorScheme.primary,
      indicatorWeight: 3,
      labelColor: colorScheme.primary,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      tabs: const [
        Tab(icon: Icon(Icons.edit_note_rounded), text: 'Manual'),
        Tab(icon: Icon(Icons.auto_awesome_rounded), text: 'AI Assistant'),
      ],
    );
  }
}
