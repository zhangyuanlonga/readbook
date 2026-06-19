import 'bookshelf_page_models.dart';
import '../../../domain/entities/bookshelf_book.dart';

enum BookshelfBookActionIntent {
  openDetail,
  openEdit,
  editTags,
  editCategory,
  toggleReadingQueue,
  select,
  delete,
}

class BookshelfBookActionController {
  const BookshelfBookActionController();

  BookshelfBookActionIntent? resolve({
    required BookshelfBookMoreAction action,
    required bool actionsLocked,
  }) {
    if (actionsLocked) {
      return null;
    }
    return switch (action) {
      BookshelfBookMoreAction.detail => BookshelfBookActionIntent.openDetail,
      BookshelfBookMoreAction.edit => BookshelfBookActionIntent.openEdit,
      BookshelfBookMoreAction.tags => BookshelfBookActionIntent.editTags,
      BookshelfBookMoreAction.category =>
        BookshelfBookActionIntent.editCategory,
      BookshelfBookMoreAction.readingQueue =>
        BookshelfBookActionIntent.toggleReadingQueue,
      BookshelfBookMoreAction.select => BookshelfBookActionIntent.select,
      BookshelfBookMoreAction.delete => BookshelfBookActionIntent.delete,
    };
  }

  Future<BookshelfBookRemovalResult> removeBooks(
    Iterable<BookshelfBook> books, {
    required Future<void> Function(BookshelfBook book) removeBook,
  }) async {
    var removedCount = 0;
    var failureCount = 0;
    for (final book in books) {
      try {
        await removeBook(book);
        removedCount += 1;
      } catch (_) {
        failureCount += 1;
      }
    }
    return BookshelfBookRemovalResult(
      removedCount: removedCount,
      failureCount: failureCount,
    );
  }
}

class BookshelfBookRemovalResult {
  const BookshelfBookRemovalResult({
    required this.removedCount,
    required this.failureCount,
  });

  final int removedCount;
  final int failureCount;

  bool get hasFailures => failureCount > 0;

  String get singleDeleteMessage {
    return hasFailures ? '删除失败，请稍后重试。' : '已从书架删除。';
  }

  String get batchDeleteMessage {
    if (hasFailures) {
      return '已删除 $removedCount 本书，失败 $failureCount 本。';
    }
    return '已删除 $removedCount 本书。';
  }
}
