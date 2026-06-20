import 'package:flutter/material.dart';

import '../../theme/app_component_theme_tokens.dart';

enum AppSurfaceTone { standard, muted, elevated, transparent }

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.tone = AppSurfaceTone.standard,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius,
    this.borderColor,
    this.backgroundColor,
    this.clipBehavior = Clip.none,
    this.onTap,
  });

  final Widget child;
  final AppSurfaceTone tone;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final Clip clipBehavior;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = appComponentThemeTokensOf(context);
    final radius = borderRadius ?? BorderRadius.circular(tokens.card.radius);
    final resolvedColor = backgroundColor ?? _backgroundColor(colorScheme);
    final resolvedBorder =
        tone == AppSurfaceTone.transparent
            ? Colors.transparent
            : borderColor ?? colorScheme.outlineVariant.withValues(alpha: 0.46);
    final shadows =
        tone == AppSurfaceTone.elevated
            ? <BoxShadow>[
              BoxShadow(
                color: colorScheme.shadow.withValues(
                  alpha: tokens.card.shadowAlpha,
                ),
                blurRadius: tokens.card.shadowBlur,
                offset: Offset(0, tokens.card.shadowOffsetY),
              ),
            ]
            : null;

    final content = Container(
      margin: margin,
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: resolvedColor,
        borderRadius: radius,
        border: Border.all(
          color: resolvedBorder,
          width: tokens.card.borderWidth,
        ),
        boxShadow: shadows,
      ),
      child: child,
    );

    if (onTap == null) {
      return content;
    }
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(borderRadius: radius, onTap: onTap, child: content),
    );
  }

  Color _backgroundColor(ColorScheme colorScheme) {
    return switch (tone) {
      AppSurfaceTone.standard => colorScheme.surface,
      AppSurfaceTone.muted => colorScheme.surfaceContainerLow,
      AppSurfaceTone.elevated => colorScheme.surfaceContainerLowest,
      AppSurfaceTone.transparent => Colors.transparent,
    };
  }
}

class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.tone = AppSurfaceTone.standard,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final AppSurfaceTone tone;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasHeader =
        title != null ||
        subtitle != null ||
        leading != null ||
        trailing != null;
    return AppSurface(
      tone: tone,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasHeader) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 10)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    this.spacing = 10,
    this.tone = AppSurfaceTone.muted,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;
  final double spacing;
  final AppSurfaceTone tone;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) SizedBox(height: spacing),
            children[index],
          ],
        ],
      ),
    );
  }
}
