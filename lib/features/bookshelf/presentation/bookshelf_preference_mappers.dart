import '../application/bookshelf_page_state.dart';
import '../application/bookshelf_service.dart';
import 'bookshelf_page_models.dart';

BookshelfSortMode sortModeFromStorageValue(String value) {
  return switch (value) {
    BookshelfService.recentReadSortMode => BookshelfSortMode.recentRead,
    BookshelfService.readingProgressSortMode =>
      BookshelfSortMode.readingProgress,
    BookshelfService.createdAtSortMode => BookshelfSortMode.createdAt,
    BookshelfService.authorSortMode => BookshelfSortMode.author,
    BookshelfService.titleSortMode => BookshelfSortMode.title,
    _ => BookshelfSortMode.defaultOrder,
  };
}

String sortModeStorageValue(BookshelfSortMode mode) {
  return switch (mode) {
    BookshelfSortMode.defaultOrder => BookshelfService.defaultSortMode,
    BookshelfSortMode.recentRead => BookshelfService.recentReadSortMode,
    BookshelfSortMode.readingProgress =>
      BookshelfService.readingProgressSortMode,
    BookshelfSortMode.createdAt => BookshelfService.createdAtSortMode,
    BookshelfSortMode.author => BookshelfService.authorSortMode,
    BookshelfSortMode.title => BookshelfService.titleSortMode,
  };
}

String sortModeLabel(BookshelfSortMode mode) {
  return switch (mode) {
    BookshelfSortMode.defaultOrder => '默认排序',
    BookshelfSortMode.recentRead => '最近阅读',
    BookshelfSortMode.readingProgress => '阅读进度',
    BookshelfSortMode.createdAt => '创建时间',
    BookshelfSortMode.author => '作者',
    BookshelfSortMode.title => '书名',
  };
}

String sortModeDescription(BookshelfSortMode mode) {
  return switch (mode) {
    BookshelfSortMode.defaultOrder => '优先按最近阅读，其次按加入书架时间。',
    BookshelfSortMode.recentRead => '最近打开或更新阅读位置的书籍排在前面。',
    BookshelfSortMode.readingProgress => '按当前阅读进度从高到低排序。',
    BookshelfSortMode.createdAt => '按加入书架时间从新到旧排序。',
    BookshelfSortMode.author => '按作者名称排序，缺少作者信息的书排在后面。',
    BookshelfSortMode.title => '按书名排序，相同书名再按加入时间兜底。',
  };
}

BookshelfGridVisualStyle gridVisualStyleFromStorageValue(String value) {
  return switch (value) {
    BookshelfService.gridOverlayTitleVisualStyle =>
      BookshelfGridVisualStyle.overlayTitle,
    BookshelfService.gridCoverOnlyVisualStyle =>
      BookshelfGridVisualStyle.coverOnly,
    _ => BookshelfGridVisualStyle.standard,
  };
}

String gridVisualStyleStorageValue(BookshelfGridVisualStyle value) {
  return switch (value) {
    BookshelfGridVisualStyle.standard =>
      BookshelfService.gridStandardVisualStyle,
    BookshelfGridVisualStyle.overlayTitle =>
      BookshelfService.gridOverlayTitleVisualStyle,
    BookshelfGridVisualStyle.coverOnly =>
      BookshelfService.gridCoverOnlyVisualStyle,
  };
}

String gridVisualStyleLabel(BookshelfGridVisualStyle value) {
  return switch (value) {
    BookshelfGridVisualStyle.standard => '标准',
    BookshelfGridVisualStyle.overlayTitle => '封面叠字',
    BookshelfGridVisualStyle.coverOnly => '仅封面',
  };
}

BookshelfProgressInfoMode progressInfoModeFromStorageValue(String value) {
  return switch (value) {
    BookshelfService.progressInfoModeUnreadChapters =>
      BookshelfProgressInfoMode.unreadChapters,
    _ => BookshelfProgressInfoMode.progressBar,
  };
}

String progressInfoModeStorageValue(BookshelfProgressInfoMode value) {
  return switch (value) {
    BookshelfProgressInfoMode.progressBar =>
      BookshelfService.progressInfoModeProgressBar,
    BookshelfProgressInfoMode.unreadChapters =>
      BookshelfService.progressInfoModeUnreadChapters,
  };
}

String progressInfoModeLabel(BookshelfProgressInfoMode value) {
  return switch (value) {
    BookshelfProgressInfoMode.progressBar => '进度条',
    BookshelfProgressInfoMode.unreadChapters => '未读章节数',
  };
}

BookshelfSearchQuickFilterContent searchQuickFilterContentFromStorageValue(
  String value,
) {
  return switch (value) {
    'tags' => BookshelfSearchQuickFilterContent.tags,
    'categories' => BookshelfSearchQuickFilterContent.categories,
    _ => BookshelfSearchQuickFilterContent.none,
  };
}

String searchQuickFilterContentStorageValue(
  BookshelfSearchQuickFilterContent value,
) {
  return switch (value) {
    BookshelfSearchQuickFilterContent.tags => 'tags',
    BookshelfSearchQuickFilterContent.categories => 'categories',
    BookshelfSearchQuickFilterContent.none => 'none',
  };
}

String searchQuickFilterContentLabel(BookshelfSearchQuickFilterContent value) {
  return switch (value) {
    BookshelfSearchQuickFilterContent.tags => '标签',
    BookshelfSearchQuickFilterContent.categories => '分类',
    BookshelfSearchQuickFilterContent.none => '不显示',
  };
}
