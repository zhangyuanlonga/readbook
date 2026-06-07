import 'bookshelf_page_models.dart';

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
}
