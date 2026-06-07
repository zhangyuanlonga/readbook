import 'advanced_theme_list_page_state.dart';
import 'advanced_theme_service.dart';

class AdvancedThemeListQueryController {
  const AdvancedThemeListQueryController();

  List<AdvancedThemeSummary> sortThemeSummaries({
    required List<AdvancedThemeSummary> themes,
    required String? activeThemeId,
    required AdvancedThemeSortMode sortMode,
  }) {
    return List<AdvancedThemeSummary>.from(themes)..sort((a, b) {
      final aIsActive = a.id == activeThemeId;
      final bIsActive = b.id == activeThemeId;
      if (aIsActive != bIsActive) {
        return aIsActive ? -1 : 1;
      }
      return switch (sortMode) {
        AdvancedThemeSortMode.updatedDesc => b.updatedAt.compareTo(a.updatedAt),
        AdvancedThemeSortMode.nameAsc => a.name.compareTo(b.name),
        AdvancedThemeSortMode.categoryAsc => compareThemeCategory(a, b),
      };
    });
  }

  int compareThemeCategory(AdvancedThemeSummary a, AdvancedThemeSummary b) {
    final categoryA = a.category?.trim() ?? '';
    final categoryB = b.category?.trim() ?? '';
    if (categoryA.isNotEmpty && categoryB.isNotEmpty) {
      final compare = categoryA.compareTo(categoryB);
      if (compare != 0) {
        return compare;
      }
    } else if (categoryA.isNotEmpty) {
      return -1;
    } else if (categoryB.isNotEmpty) {
      return 1;
    }
    return a.name.compareTo(b.name);
  }

  bool hasSamePreviewContent({
    required List<AdvancedThemeSummary> previous,
    required List<AdvancedThemeSummary> next,
  }) {
    if (previous.length != next.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index += 1) {
      final previousItem = previous[index];
      final nextItem = next[index];
      if (previousItem.id != nextItem.id) {
        return false;
      }
      if (previousItem.lightMode.wallpaperPath !=
              nextItem.lightMode.wallpaperPath ||
          previousItem.darkMode.wallpaperPath !=
              nextItem.darkMode.wallpaperPath) {
        return false;
      }
    }
    return true;
  }

  List<String> availableCategories(List<AdvancedThemeSummary> summaries) {
    final categories = summaries
      .map((theme) => theme.category?.trim() ?? '')
      .where((category) => category.isNotEmpty)
      .toSet()
      .toList(growable: false)..sort();
    return categories;
  }

  List<AdvancedThemeSummary> visibleThemes({
    required List<AdvancedThemeSummary> summaries,
    required String searchQuery,
    required String? selectedCategory,
  }) {
    final keyword = searchQuery.trim().toLowerCase();
    final categoryFilter = selectedCategory?.trim() ?? '';
    return summaries
        .where((theme) {
          if (categoryFilter.isNotEmpty &&
              (theme.category?.trim() ?? '') != categoryFilter) {
            return false;
          }
          if (keyword.isEmpty) {
            return true;
          }
          final haystacks = <String>[
            theme.name,
            theme.category ?? '',
          ].map((item) => item.toLowerCase());
          return haystacks.any((item) => item.contains(keyword));
        })
        .toList(growable: false);
  }

  Set<String> pruneSelectedThemeIds({
    required Iterable<AdvancedThemeSummary> visibleThemes,
    required Set<String> selectedThemeIds,
  }) {
    final visibleIds = visibleThemes.map((theme) => theme.id).toSet();
    return selectedThemeIds.where((id) => visibleIds.contains(id)).toSet();
  }

  bool areAllVisibleThemesSelected({
    required Iterable<AdvancedThemeSummary> visibleThemes,
    required Set<String> selectedThemeIds,
  }) {
    final visibleList = visibleThemes.toList(growable: false);
    return visibleList.isNotEmpty &&
        visibleList.every((theme) => selectedThemeIds.contains(theme.id));
  }
}
