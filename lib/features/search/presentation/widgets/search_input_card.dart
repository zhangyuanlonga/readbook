import 'package:flutter/material.dart';

import '../../../../app/layout/app_adaptive.dart';
import '../../application/search_service.dart';

class SearchInputCard extends StatelessWidget {
  const SearchInputCard({
    super.key,
    required this.isSearching,
    required this.searchContentMode,
    required this.onContentModeChanged,
    this.modeActiveBackgroundColor,
    this.modeActiveForegroundColor,
  });

  final bool isSearching;
  final SearchContentMode searchContentMode;
  final ValueChanged<SearchContentMode> onContentModeChanged;
  final Color? modeActiveBackgroundColor;
  final Color? modeActiveForegroundColor;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: metrics.isCompactDensity ? 4 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ModeChip(
                  icon: Icons.menu_book_rounded,
                  label: '小说',
                  isActive: searchContentMode == SearchContentMode.novel,
                  activeBackgroundColor: modeActiveBackgroundColor,
                  activeForegroundColor: modeActiveForegroundColor,
                  onTap:
                      isSearching
                          ? null
                          : () => onContentModeChanged(SearchContentMode.novel),
                ),
                SizedBox(width: metrics.contentGap),
                _ModeChip(
                  icon: Icons.auto_stories_rounded,
                  label: '漫画',
                  isActive: searchContentMode == SearchContentMode.manga,
                  activeBackgroundColor: modeActiveBackgroundColor,
                  activeForegroundColor: modeActiveForegroundColor,
                  onTap:
                      isSearching
                          ? null
                          : () => onContentModeChanged(SearchContentMode.manga),
                ),
                SizedBox(width: metrics.contentGap),
                _ModeChip(
                  icon: Icons.headphones_rounded,
                  label: '听书',
                  isActive: searchContentMode == SearchContentMode.audio,
                  activeBackgroundColor: modeActiveBackgroundColor,
                  activeForegroundColor: modeActiveForegroundColor,
                  onTap:
                      isSearching
                          ? null
                          : () => onContentModeChanged(SearchContentMode.audio),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.activeBackgroundColor,
    this.activeForegroundColor,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  final Color? activeBackgroundColor;
  final Color? activeForegroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    final bgColor =
        isActive
            ? (activeBackgroundColor ?? colorScheme.primary)
            : colorScheme.surfaceContainerHigh;
    final fgColor =
        isActive
            ? (activeForegroundColor ?? colorScheme.onPrimary)
            : colorScheme.onSurfaceVariant;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.isCompactDensity ? 10 : 12,
            vertical: metrics.isCompactDensity ? 6 : 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: metrics.isCompactDensity ? 15 : 16,
                color: fgColor,
              ),
              SizedBox(width: metrics.isCompactDensity ? 5 : 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
