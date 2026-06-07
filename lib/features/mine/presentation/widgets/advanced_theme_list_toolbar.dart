import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'image_resource_collection_widgets.dart';

class AdvancedThemeListToolbar extends StatelessWidget {
  const AdvancedThemeListToolbar({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.selectedCategory,
    required this.availableCategories,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onCategorySelected,
  });

  final TextEditingController searchController;
  final String searchQuery;
  final String? selectedCategory;
  final List<String> availableCategories;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedCategory = selectedCategory?.trim();
    final categoryLabel =
        normalizedCategory == null || normalizedCategory.isEmpty
            ? '全部分类'
            : normalizedCategory;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final shouldUseCompactCategoryLabel =
        categoryLabel == '全部分类' && textScale > 1.1;
    final categoryControlFlex = shouldUseCompactCategoryLabel ? 3 : 2;
    return Row(
      children: [
        Flexible(
          flex: shouldUseCompactCategoryLabel ? 4 : 5,
          child: CompactCollectionSearchField(
            controller: searchController,
            hintText: '搜索主题名称或分类',
            query: searchQuery,
            onChanged: onSearchChanged,
            onClear: onSearchCleared,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: categoryControlFlex,
          child: PopupMenuButton<String?>(
            tooltip: '分类筛选',
            initialValue: selectedCategory,
            onSelected: onCategorySelected,
            itemBuilder:
                (context) => <PopupMenuEntry<String?>>[
                  const PopupMenuItem<String?>(
                    value: null,
                    child: Center(child: Text('全部分类')),
                  ),
                  ...availableCategories.map(
                    (category) => PopupMenuItem<String?>(
                      value: category,
                      child: Center(child: Text(category)),
                    ),
                  ),
                ],
            child: Container(
              height: 40,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest.withValues(
                  alpha: 0.92,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.28),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 18),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        categoryLabel,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize:
                              math
                                  .max(
                                    11,
                                    (Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.fontSize ??
                                            12) -
                                        (shouldUseCompactCategoryLabel ? 1 : 0),
                                  )
                                  .toDouble(),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
