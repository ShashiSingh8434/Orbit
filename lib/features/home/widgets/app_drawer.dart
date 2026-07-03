import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = ref.watch(authStateProvider).value;
    final isDark = theme.brightness == Brightness.dark;

    // ── Gradient palette ─────────────────────────────────────────────────────
    // Dark  → deep space: near-black → indigo-navy
    // Light → airy sky:   cool white-blue → soft indigo tint
    final gradientColors = isDark
        ? const [
  Color(0xFF05070F), // Space Black
  Color(0xFF0D1535), // Deep Navy
  Color(0xFF2A2452), // Deep Violet Nebula
  Color(0xFF060A15), // Midnight Black
          ]
        : const [
        Color(0xFFF8FAFF), // Pure Sky White
        Color(0xFFE9F1FF), // Soft Blue
        Color(0xFFE8E6FF), // Lavender Mist
        Color(0xFFF6F8FF), // White Glows
          ];

    // ── Per-theme text / icon colours ────────────────────────────────────────
    final labelColor = isDark ? Colors.white60 : colorScheme.onSurfaceVariant;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : colorScheme.outline.withValues(alpha: 0.30);
    final selectedHighlight = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : colorScheme.primary.withValues(alpha: 0.10);

    // Header gradient
    final headerColors = isDark
        ? [
            colorScheme.primary.withValues(alpha: 0.28),
            const Color(0xFF1A56DB).withValues(alpha: 0.12),
          ]
        : [
            colorScheme.primary.withValues(alpha: 0.14),
            colorScheme.secondary.withValues(alpha: 0.06),
          ];
    final headerBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : colorScheme.outline.withValues(alpha: 0.20);

    return SafeArea(
      bottom: false,
      child: Drawer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.35, 0.70, 1.0],
              colors: gradientColors,
            ),
          ),
          child: Column(
            children: [
              // ── Profile Header ──────────────────────────────────────────────
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: headerColors,
                  ),
                  border: Border(
                    bottom: BorderSide(color: headerBorder),
                  ),
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.20),
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  child: user?.photoURL == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 36,
                          color: isDark ? Colors.white70 : colorScheme.primary,
                        )
                      : null,
                ),
                accountName: Text(
                  user?.displayName ?? 'Orbit User',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDark ? Colors.white : colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                accountEmail: Text(
                  user?.email ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? Colors.white60
                        : colorScheme.onSurface.withValues(alpha: 0.60),
                  ),
                ),
              ),

              // ── Navigation Items ────────────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  children: [
                    _DrawerItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      isDark: isDark,
                      selected: GoRouterState.of(context).matchedLocation == AppRoutes.home,
                      selectedHighlight: selectedHighlight,
                      colorScheme: colorScheme,
                      onTap: () {
                        Navigator.pop(context);
                        context.go(AppRoutes.home);
                      },
                    ),

                    _SectionDivider(label: 'FEATURES', labelColor: labelColor, dividerColor: dividerColor),

                    _DrawerItem(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Reflections',
                      isDark: isDark,
                      selectedHighlight: selectedHighlight,
                      colorScheme: colorScheme,
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppRoutes.reflections);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.task_alt_rounded,
                      label: 'Tasks',
                      isDark: isDark,
                      selectedHighlight: selectedHighlight,
                      colorScheme: colorScheme,
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppRoutes.tasks);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.gavel_rounded,
                      label: 'Decisions',
                      isDark: isDark,
                      selectedHighlight: selectedHighlight,
                      colorScheme: colorScheme,
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppRoutes.decisions);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.event_rounded,
                      label: 'Events',
                      isDark: isDark,
                      selectedHighlight: selectedHighlight,
                      colorScheme: colorScheme,
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppRoutes.events);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.lightbulb_outline_rounded,
                      label: 'Learnings',
                      isDark: isDark,
                      selectedHighlight: selectedHighlight,
                      colorScheme: colorScheme,
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppRoutes.learnings);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.school_rounded,
                      label: 'Academic',
                      isDark: isDark,
                      selected: GoRouterState.of(context).matchedLocation == AppRoutes.academic,
                      selectedHighlight: selectedHighlight,
                      colorScheme: colorScheme,
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppRoutes.academic);
                      },
                    ),

                    _SectionDivider(label: 'MORE', labelColor: labelColor, dividerColor: dividerColor),

                    _DrawerItem(
                      icon: Icons.help_outline_rounded,
                      label: 'How to use Orbit',
                      isDark: isDark,
                      selectedHighlight: selectedHighlight,
                      colorScheme: colorScheme,
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppRoutes.guide);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      isDark: isDark,
                      selectedHighlight: selectedHighlight,
                      colorScheme: colorScheme,
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppRoutes.settings);
                      },
                    ),

                    Divider(height: 24, color: dividerColor),

                    _DrawerItem(
                      icon: Icons.star_rounded,
                      label: 'Bonus',
                      isDark: isDark,
                      accent: true,
                      selectedHighlight: selectedHighlight,
                      colorScheme: colorScheme,
                      onTap: () {
                        Navigator.pop(context);
                        context.push(AppRoutes.bonus);
                      },
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section Divider ───────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({
    required this.label,
    required this.labelColor,
    required this.dividerColor,
  });

  final String label;
  final Color labelColor;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: labelColor,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: dividerColor, height: 1)),
        ],
      ),
    );
  }
}

// ── Drawer Item ───────────────────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    required this.selectedHighlight,
    required this.colorScheme,
    this.selected = false,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final bool selected;
  final bool accent;
  final Color selectedHighlight;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    // Dark theme  → white-toned palette
    // Light theme → theme colour palette
    final Color iconColor;
    final Color textColor;

    if (accent) {
      // Bonus item: amber on dark, deep amber on light
      iconColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
      textColor = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
    } else if (selected) {
      // Active route: sky-blue on dark, primary on light
      iconColor = isDark ? const Color(0xFF60A5FA) : colorScheme.primary;
      textColor = isDark ? const Color(0xFF93C5FD) : colorScheme.primary;
    } else {
      // Default: soft white on dark, onSurface on light
      iconColor = isDark ? Colors.white60 : colorScheme.onSurfaceVariant;
      textColor = isDark ? Colors.white : colorScheme.onSurface;
    }

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      tileColor: Colors.transparent,
      selectedTileColor: selectedHighlight,
      selected: selected,
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: textColor,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
