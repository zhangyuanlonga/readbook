import 'package:flutter/material.dart';

import '../layout/app_adaptive.dart';

class AdaptiveSearchBar extends StatelessWidget {
  const AdaptiveSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onChanged,
    required this.onClear,
    this.hintText = '搜索',
    this.summaryText,
    this.backgroundColor,
    this.foregroundColor,
    this.secondaryColor,
    this.outlineColor,
    this.height,
    this.borderRadius,
    this.onSubmitted,
    this.suffixBuilder,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hintText;
  final String? summaryText;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? secondaryColor;
  final Color? outlineColor;
  final double? height;
  final double? borderRadius;
  final ValueChanged<String>? onSubmitted;
  final Widget Function(BuildContext context, TextEditingValue value)?
  suffixBuilder;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resolvedHeight = height ?? metrics.controlHeight;
    final resolvedRadius = borderRadius ?? metrics.cardRadius;
    final resolvedBackground =
        backgroundColor ?? colorScheme.surfaceContainerHighest;
    final resolvedForeground = foregroundColor ?? colorScheme.onSurface;
    final resolvedSecondary = secondaryColor ?? colorScheme.onSurfaceVariant;

    return SizedBox(
      height: resolvedHeight,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        textAlignVertical: TextAlignVertical.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: metrics.isCompactDensity ? 13.5 : 14,
          height: 1.2,
          color: resolvedForeground,
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            fontSize: metrics.isCompactDensity ? 13.5 : 14,
            height: 1.2,
            color: resolvedSecondary,
          ),
          filled: true,
          fillColor: resolvedBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(resolvedRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(resolvedRadius),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(resolvedRadius),
            borderSide: BorderSide(
              color: outlineColor ?? colorScheme.outline,
              width: 1.2,
            ),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: metrics.isCompactDensity ? 18 : 20,
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: metrics.isCompactDensity ? 36 : 40,
            minHeight: resolvedHeight,
          ),
          suffixIconConstraints: BoxConstraints(minHeight: resolvedHeight),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              if (suffixBuilder != null) {
                return suffixBuilder!(context, value);
              }
              final hasSummary = (summaryText?.trim().isNotEmpty ?? false);
              if (!hasSummary && value.text.isEmpty) {
                return const SizedBox.shrink();
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasSummary)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: metrics.isCompactDensity ? 92 : 120,
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: metrics.isCompactDensity ? 6 : 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh.withValues(
                            alpha: 0.78,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          summaryText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: resolvedSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (value.text.isNotEmpty)
                    IconButton(
                      tooltip: '清空搜索',
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (hasSummary && value.text.isEmpty)
                    SizedBox(width: metrics.isCompactDensity ? 8 : 12),
                ],
              );
            },
          ),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: metrics.isCompactDensity ? 6 : 8,
            vertical: metrics.isCompactDensity ? 8 : 10,
          ),
        ),
      ),
    );
  }
}
