import '../application/private_book_source_service.dart';
import 'private_book_source_presentation.dart';

class PrivateBookSourceListFilter {
  const PrivateBookSourceListFilter._();

  static List<PrivateBookSourceItem> filter(
    List<PrivateBookSourceItem> items,
    String keyword,
  ) {
    final normalized = keyword.trim().toLowerCase();
    if (normalized.isEmpty) {
      return items;
    }
    return items
        .where((item) => _searchTextFor(item).contains(normalized))
        .toList(growable: false);
  }

  static String _searchTextFor(PrivateBookSourceItem item) {
    return [
      item.name,
      item.description,
      item.groupName,
      item.reviewStatus,
      item.normalizationStatus,
      item.normalizationError,
      item.lastTestStatus,
      item.lastTestMessage,
      PrivateBookSourcePresentation.typeLabel(item.supportedTypes),
      PrivateBookSourcePresentation.groupLabel(item.groupName),
      PrivateBookSourcePresentation.reviewLabel(
        item.reviewStatus,
        item.visibility,
      ),
      PrivateBookSourcePresentation.normalizationSearchLabel(
        item.normalizationStatus,
      ),
      PrivateBookSourcePresentation.testLabel(item.lastTestStatus),
    ].join(' ').toLowerCase();
  }
}

class PrivateBookSourceGroupFilterPresenter {
  const PrivateBookSourceGroupFilterPresenter._();

  static String selectedLabel(
    List<PrivateBookSourceGroup> groups,
    String? selectedGroupId,
  ) {
    if (selectedGroupId == null) {
      return '全部分组';
    }
    for (final group in groups) {
      if (group.id == selectedGroupId) {
        return group.displayName;
      }
    }
    return '全部分组';
  }

  static bool isSelectionStale(
    List<PrivateBookSourceGroup> groups,
    String? selectedGroupId,
  ) {
    return selectedGroupId != null &&
        !groups.any((group) => group.id == selectedGroupId);
  }
}
