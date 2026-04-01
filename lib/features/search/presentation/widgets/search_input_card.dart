import 'package:flutter/material.dart';

import '../../application/search_service.dart';

class SearchInputCard extends StatelessWidget {
  const SearchInputCard({
    super.key,
    required this.keywordController,
    required this.focusNode,
    required this.isSearching,
    required this.searchContentMode,
    required this.isPreciseBookMatch,
    required this.selectedSourceCount,
    required this.availableSourceCount,
    required this.isLoadingSourceCount,
    required this.onSearch,
    required this.onClearResults,
    required this.onContentModeChanged,
    required this.onPreciseMatchChanged,
    required this.onOpenSourceFilter,
    required this.onClearSourceFilter,
  });

  final TextEditingController keywordController;
  final FocusNode focusNode;
  final bool isSearching;
  final SearchContentMode searchContentMode;
  final bool isPreciseBookMatch;
  final int selectedSourceCount;
  final int availableSourceCount;
  final bool isLoadingSourceCount;
  final VoidCallback onSearch;
  final VoidCallback onClearResults;
  final ValueChanged<SearchContentMode> onContentModeChanged;
  final ValueChanged<bool> onPreciseMatchChanged;
  final VoidCallback onOpenSourceFilter;
  final VoidCallback onClearSourceFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMangaMode = searchContentMode == SearchContentMode.manga;
    final hintText =
        isMangaMode ? '输入漫画名或作者' : '输入书名或作者';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Row 1: Content mode toggle ──
            SegmentedButton<SearchContentMode>(
              segments: const [
                ButtonSegment<SearchContentMode>(
                  value: SearchContentMode.novel,
                  icon: Icon(Icons.menu_book_rounded, size: 18),
                  label: Text('小说'),
                ),
                ButtonSegment<SearchContentMode>(
                  value: SearchContentMode.manga,
                  icon: Icon(Icons.auto_stories_rounded, size: 18),
                  label: Text('漫画'),
                ),
              ],
              selected: <SearchContentMode>{searchContentMode},
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onSelectionChanged:
                  isSearching
                      ? null
                      : (selection) {
                        final mode =
                            selection.isEmpty ? null : selection.first;
                        if (mode != null && mode != searchContentMode) {
                          onContentModeChanged(mode);
                        }
                      },
            ),
            const SizedBox(height: 10),

            // ── Row 2: Search field + search button ──
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: keywordController,
                    focusNode: focusNode,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    textAlignVertical: TextAlignVertical.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 1.2,
                    ),
                    onSubmitted: (_) => onSearch(),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.2,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      filled: false,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: keywordController,
                        builder: (_, value, __) {
                          if (value.text.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return IconButton(
                            tooltip: '清空输入',
                            onPressed: () => keywordController.clear(),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          );
                        },
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: onSearch,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isSearching ? '取消' : '搜索'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Row 3: Options row (source filter + precise match + clear) ──
            _buildOptionsRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsRow(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final sourceLabel = _buildSourceLabel();
    final hasResults = selectedSourceCount > 0 || isPreciseBookMatch;

    return Row(
      children: [
        // Source filter chip
        _OptionChip(
          icon: Icons.filter_list_rounded,
          label: sourceLabel,
          isActive: selectedSourceCount > 0,
          isLoading: isLoadingSourceCount,
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

        // Precise match chip
        _OptionChip(
          icon:
              isPreciseBookMatch
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
          label: '精准',
          isActive: isPreciseBookMatch,
          onTap:
              isSearching
                  ? null
                  : () => onPreciseMatchChanged(!isPreciseBookMatch),
        ),

        const Spacer(),

        // Clear results (only when has results or custom options)
        if (hasResults)
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: colorScheme.onSurfaceVariant,
              textStyle: theme.textTheme.labelSmall,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: isSearching ? null : onClearResults,
            child: const Text('清空'),
          ),
      ],
    );
  }

  String _buildSourceLabel() {
    if (isLoadingSourceCount && availableSourceCount == 0) return '源脚本...';
    if (availableSourceCount == 0) return '无源脚本';
    if (selectedSourceCount == 0) return '全部$availableSourceCount';
    return '$selectedSourceCount源';
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
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final bool isLoading;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bgColor =
        isActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHigh;
    final fgColor =
        isActive
            ? colorScheme.onPrimaryContainer
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
