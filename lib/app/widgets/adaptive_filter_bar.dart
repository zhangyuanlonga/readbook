import 'package:flutter/material.dart';

import '../layout/app_adaptive.dart';
import '../motion/app_motion.dart';
import '../theme/app_component_theme_tokens.dart';
import 'foundation/app_button.dart';

class AdaptiveFilterChipData {
  const AdaptiveFilterChipData({
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

class AdaptiveFilterBar extends StatelessWidget {
  const AdaptiveFilterBar({
    super.key,
    required this.chips,
    this.secondaryChips = const <AdaptiveFilterChipData>[],
    this.showActionButton = true,
    this.actionLabel = '筛选',
    this.actionTooltip = '',
    this.actionIcon = Icons.filter_list_rounded,
    this.onActionPressed,
    this.highlightAction = false,
    this.backgroundColor,
    this.selectedColor,
    this.secondarySelectedColor,
    this.foregroundColor,
    this.selectedForegroundColor,
    this.secondaryForegroundColor,
    this.borderColor,
    this.selectedBorderColor,
    this.actionColor,
  });

  final List<AdaptiveFilterChipData> chips;
  final List<AdaptiveFilterChipData> secondaryChips;
  final bool showActionButton;
  final String actionLabel;
  final String actionTooltip;
  final IconData actionIcon;
  final VoidCallback? onActionPressed;
  final bool highlightAction;
  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? secondarySelectedColor;
  final Color? foregroundColor;
  final Color? selectedForegroundColor;
  final Color? secondaryForegroundColor;
  final Color? borderColor;
  final Color? selectedBorderColor;
  final Color? actionColor;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final chipTextStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600);
    final height = metrics.chipHeight + (metrics.isCompactDensity ? 0 : 2);
    final componentTokens = appComponentThemeTokensOf(context);

    Widget buildChip(AdaptiveFilterChipData chip, {bool secondary = false}) {
      final selected = chip.selected;
      final motionDuration = AppMotion.durationOf(context, AppMotion.fast);
      final resolvedSelectedColor =
          secondary
              ? (secondarySelectedColor ?? colorScheme.secondaryContainer)
              : (selectedColor ?? colorScheme.primaryContainer);
      final resolvedForeground =
          foregroundColor ?? colorScheme.onSurfaceVariant;
      return Padding(
        padding: EdgeInsets.only(right: metrics.isCompactDensity ? 6 : 8),
        child: AnimatedScale(
          duration: motionDuration,
          curve: AppMotion.standard,
          scale: selected ? 1.018 : 1,
          child: GestureDetector(
            onLongPress: chip.onLongPress,
            child: ChoiceChip(
              label: Text(chip.label),
              labelPadding: EdgeInsets.symmetric(
                horizontal: metrics.isCompactDensity ? 2 : 4,
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              selected: selected,
              showCheckmark: false,
              onSelected: chip.onTap == null ? null : (_) => chip.onTap!.call(),
              backgroundColor:
                  backgroundColor ??
                  colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
              selectedColor: resolvedSelectedColor,
              labelStyle: chipTextStyle?.copyWith(
                color:
                    selected
                        ? (secondary
                            ? (secondaryForegroundColor ??
                                colorScheme.onSecondaryContainer)
                            : (selectedForegroundColor ??
                                colorScheme.onPrimaryContainer))
                        : resolvedForeground,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  componentTokens.selection.chipRadius,
                ),
              ),
              side: BorderSide(
                color:
                    selected
                        ? (selectedBorderColor ?? colorScheme.outlineVariant)
                        : (borderColor ?? colorScheme.outlineVariant),
                width: componentTokens.selection.chipBorderWidth,
              ),
            ),
          ),
        ),
      );
    }

    final action = AppButton(
      variant: AppButtonVariant.text,
      size: AppButtonSize.compact,
      onPressed: onActionPressed,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(0, height)),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: metrics.isCompactDensity ? 4 : 6),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              componentTokens.selection.segmentRadius,
            ),
          ),
        ),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: WidgetStatePropertyAll(
          actionColor ??
              (highlightAction
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant),
        ),
      ),
      icon: Icon(actionIcon, size: 18),
      label: actionLabel,
    );

    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...chips.map((chip) => buildChip(chip)),
                ...secondaryChips.map(
                  (chip) => buildChip(chip, secondary: true),
                ),
              ],
            ),
          ),
          if (showActionButton) ...[
            SizedBox(width: metrics.isCompactDensity ? 4 : 6),
            Tooltip(message: actionTooltip, child: action),
          ],
        ],
      ),
    );
  }
}
