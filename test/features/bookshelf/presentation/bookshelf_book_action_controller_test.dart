import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_book_action_controller.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_page_models.dart';

void main() {
  group('BookshelfBookActionController', () {
    const controller = BookshelfBookActionController();

    test('returns null when book actions are locked', () {
      expect(
        controller.resolve(
          action: BookshelfBookMoreAction.detail,
          actionsLocked: true,
        ),
        isNull,
      );
    });

    test('maps more menu actions to page intents', () {
      expect(
        controller.resolve(
          action: BookshelfBookMoreAction.detail,
          actionsLocked: false,
        ),
        BookshelfBookActionIntent.openDetail,
      );
      expect(
        controller.resolve(
          action: BookshelfBookMoreAction.edit,
          actionsLocked: false,
        ),
        BookshelfBookActionIntent.openEdit,
      );
      expect(
        controller.resolve(
          action: BookshelfBookMoreAction.tags,
          actionsLocked: false,
        ),
        BookshelfBookActionIntent.editTags,
      );
      expect(
        controller.resolve(
          action: BookshelfBookMoreAction.category,
          actionsLocked: false,
        ),
        BookshelfBookActionIntent.editCategory,
      );
      expect(
        controller.resolve(
          action: BookshelfBookMoreAction.readingQueue,
          actionsLocked: false,
        ),
        BookshelfBookActionIntent.toggleReadingQueue,
      );
      expect(
        controller.resolve(
          action: BookshelfBookMoreAction.select,
          actionsLocked: false,
        ),
        BookshelfBookActionIntent.select,
      );
      expect(
        controller.resolve(
          action: BookshelfBookMoreAction.delete,
          actionsLocked: false,
        ),
        BookshelfBookActionIntent.delete,
      );
    });
  });
}
