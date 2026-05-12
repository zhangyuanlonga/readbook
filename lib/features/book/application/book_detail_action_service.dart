import '../../../domain/entities/book_detail.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import 'book_metadata_presentation_resolver.dart';

class BookDetailBookshelfActionResult {
  const BookDetailBookshelfActionResult({
    required this.isInBookshelf,
    required this.message,
  });

  final bool isInBookshelf;
  final String message;
}

class BookDetailActionService {
  const BookDetailActionService({required BookshelfService bookshelfService})
    : _bookshelfService = bookshelfService;

  final BookshelfService _bookshelfService;

  Future<BookDetailBookshelfActionResult> toggleBookshelf({
    required bool wasInBookshelf,
    required BookDetail detail,
    required BookDisplayState presentation,
    String? latestChapterTitle,
  }) async {
    if (wasInBookshelf) {
      await _bookshelfService.remove(
        sourceId: detail.sourceId,
        detailUrl: detail.detailUrl,
      );
      return const BookDetailBookshelfActionResult(
        isInBookshelf: false,
        message: '已从书架移除。',
      );
    }

    await _bookshelfService.upsert(
      BookshelfBook(
        bookId: detail.id,
        sourceId: detail.sourceId,
        title: presentation.displayTitle,
        detailUrl: detail.detailUrl,
        author: presentation.displayAuthor,
        coverUrl: presentation.displayCover,
        latestChapter: latestChapterTitle,
        addedAt: DateTime.now(),
      ),
    );
    return const BookDetailBookshelfActionResult(
      isInBookshelf: true,
      message: '已加入书架。',
    );
  }

  Future<void> saveOrganization({
    required BookDetail detail,
    required String? category,
    required List<String> tags,
  }) async {
    await _bookshelfService.setBookCategory(
      sourceId: detail.sourceId,
      detailUrl: detail.detailUrl,
      category: category,
    );
    await _bookshelfService.setBookTags(
      sourceId: detail.sourceId,
      detailUrl: detail.detailUrl,
      tags: tags,
    );
  }
}
