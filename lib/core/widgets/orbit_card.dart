import 'package:flutter/material.dart';

class OrbitCard extends StatelessWidget {
  const OrbitCard({
    super.key,
    this.title,
    this.titleWidget,
    this.description,
    this.leading,
    this.trailing,
    this.onTap,
    this.margin,
    this.accentColor,
    this.borderColor,
    this.backgroundColor,
    this.titleStyle,
    this.descriptionStyle,
    this.bottomContent,
  }) : assert(title != null || titleWidget != null, 'Either title or titleWidget must be provided');

  final String? title;
  final Widget? titleWidget;
  final String? description;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final Color? accentColor;
  final Color? borderColor;
  final Color? backgroundColor;
  final TextStyle? titleStyle;
  final TextStyle? descriptionStyle;
  final Widget? bottomContent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasDesc = description != null && description!.isNotEmpty;

    return Card(
      elevation: 1,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.25), 
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: borderColor ?? colorScheme.outlineVariant.withValues(alpha: 0.9),
          width: 1,
        ),
      ),
      margin: margin ?? const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (accentColor != null)
                Container(
                  width: 4,
                  color: accentColor,
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (leading != null) ...[
                                  leading!,
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: titleWidget ??
                                      Text(
                                        title!,
                                        style: titleStyle ??
                                            theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                ),
                              ],
                            ),
                            if (hasDesc) ...[
                              const SizedBox(height: 8),
                              Divider(
                                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                                height: 1,
                                thickness: 1,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                description!,
                                style: descriptionStyle ??
                                    theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                            if (bottomContent != null) ...[
                              const SizedBox(height: 8),
                              bottomContent!,
                            ],
                          ],
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 12),
                        trailing!,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
