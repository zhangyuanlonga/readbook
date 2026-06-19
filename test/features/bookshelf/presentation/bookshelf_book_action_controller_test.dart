import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/bookshelf_book.dart';
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

    test('counts successful and failed book removals', () async {
      final result = await controller.removeBooks(
        <BookshelfBook>[
          _book(id: 'book_1'),
          _book(id: 'book_2'),
          _book(id: 'book_3'),
        ],
        removeBook: (book) async {
          if (book.bookId == 'book_2') {
            throw StateError('remove failed');
          }
        },
      );

      expect(result.removedCount, 2);
      expect(result.failureCount, 1);
      expect(result.hasFailures, isTrue);
      expect(result.batchDeleteMessage, '已删除 2 本书，失败 1 本。');
      expect(result.singleDeleteMessage, '删除失败，请稍后重试。');
    });

    test('formats successful removal messages', () async {
      final result = await controller.removeBooks(<BookshelfBook>[
        _book(id: 'book_1'),
      ], removeBook: (_) async {});

      expect(result.removedCount, 1);
      expect(result.failureCount, 0);
      expect(result.batchDeleteMessage, '已删除 1 本书。');
      expect(result.singleDeleteMessage, '已从书架删除。');
    });
  });
}

BookshelfBook _book({required String id}) {
  return BookshelfBook(
    bookId: id,
    sourceId: 'source',
    title: '测试书籍 $id',
    detailUrl: 'https://example.com/books/$id',
    addedAt: DateTime(2026),
    author: '作者',
  );
}
