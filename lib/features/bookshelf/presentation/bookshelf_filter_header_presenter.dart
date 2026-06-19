import '../../../domain/entities/bookshelf_book.dart';
import 'bookshelf_page_models.dart';

class BookshelfFilterHeaderPresenter {
  const BookshelfFilterHeaderPresenter();

  String searchSummaryText({
    required bool isSelectionMode,
    required int selectedCount,
    required bool hasSearchKeyword,
    required int filteredCount,
    required String activeFilterLabel,
  }) {
    if (isSelectionMode) {
      return '已选 $selectedCount 本';
    }
    if (hasSearchKeyword) {
      return '结果 $filteredCount 本';
    }
    return '$activeFilterLabel $filteredCount 本';
  }

  bool shouldShowQuickFilters({
    required BookshelfSearchQuickFilterContent content,
    required List<BookshelfBook> books,
    required List<String> userTags,
    required List<String> userCategories,
    required List<String> Function(BookshelfBook book) tagsOfBook,
    required String? Function(BookshelfBook book) categoryOfBook,
  }) {
    return switch (content) {
      BookshelfSearchQuickFilterContent.none => false,
      BookshelfSearchQuickFilterContent.readingStatus => books.isNotEmpty,
      BookshelfSearchQuickFilterContent.tags =>
        userTags.isNotEmpty || books.any((book) => tagsOfBook(book).isEmpty),
      BookshelfSearchQuickFilterContent.categories =>
        userCategories.isNotEmpty ||
            books.any((book) => (categoryOfBook(book) ?? '').isEmpty),
    };
  }

  double searchSectionHeight({
    required bool showSearchBar,
    required bool shouldShowQuickFilters,
    required bool shouldShowExpandedSearch,
  }) {
    final quickFilterHeight = shouldShowQuickFilters ? 46.0 : 0.0;
    final searchHeight = showSearchBar && shouldShowExpandedSearch ? 42.0 : 0.0;
    final gapHeight =
        shouldShowQuickFilters && showSearchBar && shouldShowExpandedSearch
            ? 8.0
            : 0.0;
    return 12 + quickFilterHeight + gapHeight + searchHeight;
  }
}
