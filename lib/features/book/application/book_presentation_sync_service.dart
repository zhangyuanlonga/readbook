import '../../../domain/entities/book_detail.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reader_toc_snapshot.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../../reader/application/reader_preferences_service.dart';
import '../../reader/application/reading_record_service.dart';
import 'book_metadata_presentation_resolver.dart';

class BookPresentationSyncService {
  const BookPresentationSyncService({
    required ReaderPreferencesService readerPreferencesService,
    required ReadingRecordService readingRecordService,
    required BookshelfService bookshelfService,
  }) : _readerPreferencesService = readerPreferencesService,
       _readingRecordService = readingRecordService,
       _bookshelfService = bookshelfService;

  final ReaderPreferencesService _readerPreferencesService;
  final ReadingRecordService _readingRecordService;
  final BookshelfService _bookshelfService;

  Future<void> syncPresentation({
    required BookDetail detail,
    required List<Chapter> chapters,
    required BookDisplayState presentation,
    required bool isInBookshelf,
    String? latestChapterTitle,
  }) async {
    try {
      await _readerPreferencesService.saveTocSnapshot(
        ReaderTocSnapshot(
          bookId: detail.id,
          sourceId: detail.sourceId,
          detailUrl: detail.detailUrl,
          title: presentation.displayTitle,
          author: presentation.displayAuthor,
          coverUrl: presentation.displayCover,
          chapters: chapters,
          updatedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // Ignore toc snapshot persistence failures when refreshing presentation.
    }

    await _readingRecordService.syncBookPresentation(
      bookId: detail.id,
      bookTitle: presentation.displayTitle,
      bookAuthor: presentation.displayAuthor,
      coverUrl: presentation.displayCover,
    );

    if (!isInBookshelf) {
      return;
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
  }
}
