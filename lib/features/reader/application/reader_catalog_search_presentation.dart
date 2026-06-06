import 'reader_catalog_search_service.dart';

/// 目录搜索结果展示门面。
///
/// 搜索命中仍由 `ReaderCatalogSearchService` 负责，这里只处理桌面 / 移动共用的
/// 分组和倒序规则，避免两个 catalog surface 各自维护排序逻辑。
class ReaderCatalogSearchPresenter {
  const ReaderCatalogSearchPresenter();

  ReaderCatalogSearchPresentation resolve({
    required List<ReaderCatalogSearchEntry> entries,
    required bool descending,
  }) {
    final tocEntries = _ordered(
      entries.where((entry) => !entry.isContent),
      descending: descending,
    );
    final contentEntries = _ordered(
      entries.where((entry) => entry.isContent),
      descending: descending,
    );
    return ReaderCatalogSearchPresentation(
      tocEntries: tocEntries,
      contentEntries: contentEntries,
    );
  }

  List<ReaderCatalogSearchEntry> _ordered(
    Iterable<ReaderCatalogSearchEntry> entries, {
    required bool descending,
  }) {
    final ordered = entries.toList(growable: false);
    if (descending) {
      ordered.sort((a, b) => b.chapterIndex.compareTo(a.chapterIndex));
    }
    return List<ReaderCatalogSearchEntry>.unmodifiable(ordered);
  }
}

class ReaderCatalogSearchPresentation {
  const ReaderCatalogSearchPresentation({
    required this.tocEntries,
    required this.contentEntries,
  });

  final List<ReaderCatalogSearchEntry> tocEntries;
  final List<ReaderCatalogSearchEntry> contentEntries;

  bool get isEmpty => tocEntries.isEmpty && contentEntries.isEmpty;
}
