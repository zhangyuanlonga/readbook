import '../../../domain/entities/app_advanced_theme.dart';
import '../application/advanced_theme_service.dart';

class AdvancedThemeBatchActionController {
  const AdvancedThemeBatchActionController();

  bool hasSelection(List<AdvancedThemeSummary> selectedThemes) {
    return selectedThemes.isNotEmpty;
  }

  Set<String> selectedIds(List<AdvancedThemeSummary> selectedThemes) {
    return selectedThemes.map((theme) => theme.id).toSet();
  }

  List<AppAdvancedTheme> applyCategory({
    required List<AppAdvancedTheme> themes,
    required Set<String> selectedIds,
    required String? category,
  }) {
    return themes
        .map((theme) {
          if (!selectedIds.contains(theme.id)) {
            return theme;
          }
          return category == null
              ? theme.copyWith(clearCategory: true)
              : theme.copyWith(category: category);
        })
        .toList(growable: false);
  }

  String categoryUpdatedMessage({
    required int count,
    required String? category,
  }) {
    return category == null
        ? '已清空 $count 个主题的分类'
        : '已将 $count 个主题归类到「$category」';
  }

  String deleteCompletedMessage({
    required int successCount,
    required int failureCount,
  }) {
    if (successCount == 0) {
      return '批量删除失败，请稍后重试。';
    }
    if (failureCount > 0) {
      return '已删除 $successCount 个主题，失败 $failureCount 个。';
    }
    return '已删除 $successCount 个主题。';
  }
}
