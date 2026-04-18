import 'package:flutter/material.dart';

import '../../application/search_service.dart';

class SearchInputCard extends StatelessWidget {
  const SearchInputCard({
    super.key,
    required this.isSearching,
    required this.searchContentMode,
    required this.isPreciseBookMatch,
    required this.selectedSourceCount,
    required this.availableSourceCount,
    required this.isLoadingSourceCount,
    required this.onClearResults,
    required this.onContentModeChanged,
    required this.onPreciseMatchChanged,
    required this.onOpenSourceFilter,
    required this.onClearSourceFilter,
    this.modeActiveBackgroundColor,
    this.modeActiveForegroundColor,
    this.optionActiveBackgroundColor,
    this.optionActiveForegroundColor,
  });

  final bool isSearching;
  final SearchContentMode searchContentMode;
  final bool isPreciseBookMatch;
  final int selectedSourceCount;
  final int availableSourceCount;
  final bool isLoadingSourceCount;
  final VoidCallback onClearResults;
  final ValueChanged<SearchContentMode> onContentModeChanged;
  final ValueChanged<bool> onPreciseMatchChanged;
  final VoidCallback onOpenSourceFilter;
  final VoidCallback onClearSourceFilter;
  final Color? modeActiveBackgroundColor;
  final Color? modeActiveForegroundColor;
  final Color? optionActiveBackgroundColor;
  final Color? optionActiveForegroundColor;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 6),
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
          const SizedBox(width: 8),
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
          const SizedBox(width: 12),
          _OptionChip(
            icon: Icons.filter_list_rounded,
            label: _buildSourceLabel(),
            isActive: selectedSourceCount > 0,
            isLoading: isLoadingSourceCount,
            activeBackgroundColor: optionActiveBackgroundColor,
            activeForegroundColor: optionActiveForegroundColor,
            onTap:
                (isSearching || availableSourceCount == 0)
                    ? null
                    : onOpenSourceFilter,
            onClear:
                (selectedSourceCount > 0 && !isSearching)
                    ? onClearSourceFilter
                    : null,
          ),
          const SizedBox(width: 8),
          _OptionChip(
            icon:
                isPreciseBookMatch
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
            label: '精准',
            isActive: isPreciseBookMatch,
            activeBackgroundColor: optionActiveBackgroundColor,
            activeForegroundColor: optionActiveForegroundColor,
            onTap:
                isSearching
                    ? null
                    : () => onPreciseMatchChanged(!isPreciseBookMatch),
          ),
          if (selectedSourceCount > 0 || isPreciseBookMatch) ...[
            const SizedBox(width: 8),
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: isSearching ? null : onClearResults,
              child: const Text('清空'),
            ),
          ],
        ],
      ),
    );
  }

  String _buildSourceLabel() {
    if (isLoadingSourceCount && availableSourceCount == 0) return '书源...';
    if (availableSourceCount == 0) return '无书源';
    if (selectedSourceCount == 0) return '全部$availableSourceCount';
    return '$selectedSourceCount源';
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fgColor),
              const SizedBox(width: 6),
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

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.isLoading = false,
    this.onTap,
    this.onClear,
    this.activeBackgroundColor,
    this.activeForegroundColor,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final bool isLoading;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final Color? activeBackgroundColor;
  final Color? activeForegroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bgColor =
        isActive
            ? (activeBackgroundColor ?? colorScheme.primaryContainer)
            : colorScheme.surfaceContainerHigh;
    final fgColor =
        isActive
            ? (activeForegroundColor ?? colorScheme.onPrimaryContainer)
            : colorScheme.onSurfaceVariant;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 5, onClear != null ? 2 : 8, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: fgColor,
                  ),
                )
              else
                Icon(icon, size: 14, color: fgColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fgColor,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 2),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onClear,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.close_rounded, size: 14, color: fgColor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
