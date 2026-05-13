import 'package:flutter/material.dart';

import '../layout/app_adaptive.dart';

class AdaptiveSettingSection extends StatelessWidget {
  const AdaptiveSettingSection({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding ?? EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: color ?? colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(metrics.cardRadius + 4),
        border: Border.all(
          color:
              borderColor ?? colorScheme.outlineVariant.withValues(alpha: 0.46),
        ),
      ),
      child: child,
    );
  }
}

class AdaptiveSettingTile extends StatelessWidget {
  const AdaptiveSettingTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.active = true,
    this.enabled = true,
    this.loading = false,
    this.dense = false,
    this.padding,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool active;
  final bool enabled;
  final bool loading;
  final bool dense;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final effectiveActive = active && enabled;
    final iconBoxSize =
        dense
            ? metrics.isCompactDensity
                ? 32.0
                : 34.0
            : metrics.isCompactDensity
            ? 36.0
            : 38.0;
    final iconSize = metrics.isCompactDensity ? 19.0 : 20.0;
    final content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: dense ? metrics.minTouchTargetSize : 52,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                color:
                    effectiveActive
                        ? colorScheme.primaryContainer.withValues(alpha: 0.92)
                        : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(metrics.cardRadius * 0.72),
              ),
              child: Icon(
                icon,
                size: iconSize,
                color:
                    effectiveActive
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(width: metrics.contentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      color:
                          enabled
                              ? null
                              : colorScheme.onSurface.withValues(alpha: 0.42),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    maxLines: metrics.isCompactDensity ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color:
                          enabled
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface.withValues(alpha: 0.38),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (loading || trailing != null) ...[
              SizedBox(width: metrics.contentGap),
              if (loading)
                SizedBox(
                  width: metrics.isCompactDensity ? 20 : 22,
                  height: metrics.isCompactDensity ? 20 : 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                )
              else
                IconTheme.merge(
                  data: IconThemeData(
                    color:
                        enabled
                            ? null
                            : colorScheme.onSurface.withValues(alpha: 0.42),
                  ),
                  child: trailing!,
                ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null && onLongPress == null) {
      return content;
    }

    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        borderRadius: BorderRadius.circular(metrics.cardRadius),
        child: content,
      ),
    );
  }
}
