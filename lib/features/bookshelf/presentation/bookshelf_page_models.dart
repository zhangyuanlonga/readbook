import '../application/bookshelf_page_state.dart';
import '../application/bookshelf_service.dart';
import '../../book/application/book_reading_status_service.dart';

enum BookshelfMoreAction { selectBooks, sortBooks, settings, importLocal }

enum BookshelfGridVisualStyle { standard, overlayTitle, coverOnly }

enum BookshelfProgressInfoMode { progressBar, unreadChapters }

enum BookshelfBookMoreAction {
  detail,
  edit,
  tags,
  category,
  readingQueue,
  select,
  delete,
}

class BookTagEditorResult {
  const BookTagEditorResult({required this.tags, required this.createdItems});

  final List<String> tags;
  final List<BookshelfTaxonomyItem> createdItems;
}

class BookCategoryEditorResult {
  const BookCategoryEditorResult({
    required this.category,
    required this.createdItems,
  });

  final String? category;
  final List<BookshelfTaxonomyItem> createdItems;
}

enum BookshelfSearchQuickFilterContent { none, tags, categories }

class BookshelfProgressDisplay {
  const BookshelfProgressDisplay({
    required this.progressValue,
    required this.summaryText,
    required this.trailingLabel,
    required this.unreadLabel,
    required this.hasProgress,
    required this.hasUnreadChapters,
  });

  final double progressValue;
  final String summaryText;
  final String trailingLabel;
  final String unreadLabel;
  final bool hasProgress;
  final bool hasUnreadChapters;

  @override
  bool operator ==(Object other) {
    return other is BookshelfProgressDisplay &&
        other.progressValue == progressValue &&
        other.summaryText == summaryText &&
        other.trailingLabel == trailingLabel &&
        other.unreadLabel == unreadLabel &&
        other.hasProgress == hasProgress &&
        other.hasUnreadChapters == hasUnreadChapters;
  }

  @override
  int get hashCode => Object.hash(
    progressValue,
    summaryText,
    trailingLabel,
    unreadLabel,
    hasProgress,
    hasUnreadChapters,
  );
}

typedef BookshelfFilterAlias = BookshelfFilter;
typedef BookshelfSortModeAlias = BookshelfSortMode;
typedef BookshelfReadingStatusAlias = BookReadingStatus;
typedef BookshelfViewKindAlias = BookshelfViewKind;
typedef BookshelfBatchActionAlias = BookshelfBatchAction;
typedef BookshelfSelectionStateAlias = BookshelfSelectionState;
typedef BookshelfViewSelectionAlias = BookshelfViewSelection;
typedef BookshelfBookCardStateAlias = BookshelfBookCardState;
