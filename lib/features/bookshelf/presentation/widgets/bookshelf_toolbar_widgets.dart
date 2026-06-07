import 'package:flutter/material.dart';

import '../../../../app/layout/app_adaptive.dart';
import '../../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../../app/theme/app_border_tokens.dart';
import '../../../../app/widgets/adaptive_filter_bar.dart';
import '../../../../app/widgets/adaptive_search_bar.dart';

class BookshelfFilterChipData {
  const BookshelfFilterChipData({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
}

class BookshelfInlineSearchBar extends StatelessWidget {
  const BookshelfInlineSearchBar({
    super.key,
    required this.palette,
    required this.controller,
    this.focusNode,
    required this.onChanged,
    required this.onClear,
    this.summaryText,
    this.hintText = '搜索书名、作者、标签、分类',
  });

  final ResolvedAdvancedThemePalette palette;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String? summaryText;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return AdaptiveSearchBar(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onClear: onClear,
      hintText: hintText,
      summaryText: summaryText,
      backgroundColor: palette.searchFieldBackgroundColor,
      foregroundColor: palette.textPrimaryColor,
      secondaryColor: palette.textSecondaryColor,
      outlineColor: resolveAppBorderColor(
        Theme.of(context).colorScheme,
        baseColor: palette.outlineColor,
        containerColor: palette.searchFieldBackgroundColor,
        tone: AppBorderTone.strong,
      ),
    );
  }
}

class BookshelfInlineSearchTrigger extends StatelessWidget {
  const BookshelfInlineSearchTrigger({
    super.key,
    required this.palette,
    required this.summaryText,
    required this.onTap,
    this.label = '搜索书架',
  });

  final ResolvedAdvancedThemePalette palette;
  final String summaryText;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = AppAdaptiveMetrics.of(context);

    return SizedBox(
      height: metrics.controlHeight,
      child: Material(
        color: palette.searchFieldBackgroundColor,
        borderRadius: BorderRadius.circular(metrics.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(metrics.cardRadius),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.cardPadding),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: metrics.isCompactDensity ? 17 : 18,
                  color: palette.textSecondaryColor,
                ),
                SizedBox(width: metrics.contentGap),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.textSecondaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: metrics.contentGap),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.isCompactDensity ? 6 : 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceColor.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    summaryText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.textSecondaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BookshelfFilterBar extends StatelessWidget {
  const BookshelfFilterBar({
    super.key,
    required this.palette,
    required this.baseChips,
    required this.customChips,
    required this.highlightFilterAction,
    required this.filterActionMessage,
    required this.onOpenFilterSheet,
    this.showActionButton = true,
  });

  final ResolvedAdvancedThemePalette palette;
  final List<BookshelfFilterChipData> baseChips;
  final List<BookshelfFilterChipData> customChips;
  final bool highlightFilterAction;
  final String filterActionMessage;
  final VoidCallback? onOpenFilterSheet;
  final bool showActionButton;

  @override
  Widget build(BuildContext context) {
    return AdaptiveFilterBar(
      chips: [
        for (final chip in baseChips)
          AdaptiveFilterChipData(
            label: chip.label,
            selected: chip.selected,
            onTap: chip.onTap,
            onLongPress: chip.onLongPress,
          ),
      ],
      secondaryChips: [
        for (final chip in customChips)
          AdaptiveFilterChipData(
            label: chip.label,
            selected: chip.selected,
            onTap: chip.onTap,
            onLongPress: chip.onLongPress,
          ),
      ],
      highlightAction: highlightFilterAction,
      actionTooltip: filterActionMessage,
      onActionPressed: onOpenFilterSheet,
      showActionButton: showActionButton,
      backgroundColor: palette.surfaceColor.withValues(alpha: 0.35),
      selectedColor: palette.noticeSurfaceColor.withValues(alpha: 0.82),
      secondarySelectedColor: palette.noticeSurfaceColor.withValues(
        alpha: 0.88,
      ),
      foregroundColor: palette.textSecondaryColor,
      selectedForegroundColor: palette.textPrimaryColor,
      secondaryForegroundColor: palette.noticeAccentColor,
      borderColor: resolveAppBorderColor(
        Theme.of(context).colorScheme,
        baseColor: palette.cardBorderColor,
        containerColor: palette.surfaceColor,
      ),
      selectedBorderColor: resolveAppBorderColor(
        Theme.of(context).colorScheme,
        baseColor: palette.cardBorderColor,
        containerColor: palette.noticeSurfaceColor,
        tone: AppBorderTone.strong,
      ),
      actionColor:
          highlightFilterAction
              ? palette.primaryColor
              : palette.textSecondaryColor,
    );
  }
}

class BookshelfStepperSettingRow extends StatelessWidget {
  const BookshelfStepperSettingRow({
    super.key,
    required this.title,
    required this.valueLabel,
    required this.onDecrease,
    required this.onIncrease,
    this.subtitle,
    this.enabled = true,
  });

  final String title;
  final String valueLabel;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final String? subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveEnabled = enabled;

    Widget buildButton({
      required IconData icon,
      required VoidCallback? onPressed,
    }) {
      return IconButton(
        onPressed: effectiveEnabled ? onPressed : null,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        iconSize: 17,
        style: IconButton.styleFrom(
          backgroundColor: colorScheme.surfaceContainerLow,
          foregroundColor: colorScheme.onSurface,
          disabledBackgroundColor: colorScheme.surfaceContainerLow.withValues(
            alpha: 0.58,
          ),
          disabledForegroundColor: colorScheme.onSurfaceVariant.withValues(
            alpha: 0.45,
          ),
          minimumSize: const Size(36, 36),
          padding: const EdgeInsets.all(2),
        ),
        icon: Icon(icon),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color:
                        effectiveEnabled
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                  ),
                ),
                if (subtitle case final text?) ...[
                  const SizedBox(height: 3),
                  Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          buildButton(icon: Icons.remove_rounded, onPressed: onDecrease),
          const SizedBox(width: 6),
          Container(
            constraints: const BoxConstraints(minWidth: 60),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: resolveAppBorderColor(
                  colorScheme,
                  containerColor: colorScheme.surfaceContainerLow,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              valueLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color:
                    effectiveEnabled
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 6),
          buildButton(icon: Icons.add_rounded, onPressed: onIncrease),
        ],
      ),
    );
  }
}
