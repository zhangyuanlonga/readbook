import 'package:flutter/material.dart';

import '../layout/app_adaptive.dart';

class AdaptiveListTile extends StatelessWidget {
  const AdaptiveListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.enabled = true,
    this.selected = false,
    this.dense = false,
    this.autofocus = false,
    this.focusNode,
    this.mouseCursor,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? padding;
  final bool enabled;
  final bool selected;
  final bool dense;
  final bool autofocus;
  final FocusNode? focusNode;
  final MouseCursor? mouseCursor;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveOnTap = enabled ? onTap : null;
    final effectiveOnLongPress = enabled ? onLongPress : null;
    final minHeight =
        dense ? metrics.listTileMinHeight - 8 : metrics.listTileMinHeight;

    return Semantics(
      button: onTap != null || onLongPress != null,
      selected: selected,
      enabled: enabled,
      child: InkWell(
        focusNode: focusNode,
        autofocus: autofocus,
        mouseCursor: mouseCursor,
        onTap: effectiveOnTap,
        onLongPress: effectiveOnLongPress,
        borderRadius: BorderRadius.circular(metrics.cardRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color:
                selected
                    ? colorScheme.primaryContainer.withValues(alpha: 0.54)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(metrics.cardRadius),
          ),
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding:
                padding ??
                EdgeInsets.symmetric(
                  horizontal: metrics.cardPadding,
                  vertical:
                      dense
                          ? metrics.isCompactDensity
                              ? 4
                              : 6
                          : metrics.isCompactDensity
                          ? 6
                          : 8,
                ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  SizedBox(width: metrics.contentGap),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconTheme.merge(
                        data: IconThemeData(
                          color:
                              enabled
                                  ? null
                                  : colorScheme.onSurface.withValues(
                                    alpha: 0.42,
                                  ),
                        ),
                        child: DefaultTextStyle.merge(
                          style: TextStyle(
                            color:
                                enabled
                                    ? null
                                    : colorScheme.onSurface.withValues(
                                      alpha: 0.42,
                                    ),
                          ),
                          child: title,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        DefaultTextStyle.merge(
                          style: TextStyle(
                            color:
                                enabled
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.onSurface.withValues(
                                      alpha: 0.38,
                                    ),
                          ),
                          child: subtitle!,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  SizedBox(width: metrics.contentGap),
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
        ),
      ),
    );
  }
}
