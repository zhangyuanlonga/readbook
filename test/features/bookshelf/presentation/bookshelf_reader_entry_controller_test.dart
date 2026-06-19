import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/domain/entities/bookshelf_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_progress.dart';
import 'package:shuxiang_reading_next/domain/repositories/local_book_repository.dart';
import 'package:shuxiang_reading_next/features/book/application/book_detail_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_page_route_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_reader_open_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/local_book_import_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_reader_entry_controller.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_entry_route_resolver.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookshelfReaderEntryController', () {
    late BookshelfReaderEntryController controller;
    late _FakeLocalBookRepository localBookRepository;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      localBookRepository = _FakeLocalBookRepository();
      final preferencesService = ReaderPreferencesService();
      final pageRouteService = BookshelfPageRouteService(
        readerPreferencesService: preferencesService,
        readerEntryRouteResolver: const ReaderEntryRouteResolver(),
      );
      controller = BookshelfReaderEntryController(
        readerOpenService: BookshelfReaderOpenService(
          readerPreferencesService: preferencesService,
          readerEntryRouteResolver: const ReaderEntryRouteResolver(),
          localBookRepository: localBookRepository,
          bookDetailService: BookDetailService(),
        ),
        pageRouteService: pageRouteService,
        localBookSourceId: LocalBookImportService.localBookSourceId,
      );
    });

    test('resolves detail route through entry controller', () {
      final route = controller.resolveDetailRoute(
        _remoteBook(),
        heroTag: 'hero_1',
        initialEditMode: true,
      );

      expect(route, contains('/book/remote_1'));
      expect(route, contains('heroTag=hero_1'));
      expect(route, contains('mode=edit'));
    });

    test('resolves reader fallback plan through entry controller', () {
      final plan = controller.fallbackPlan(_remoteBook());

      expect(plan.action, BookshelfReaderOpenAction.openReader);
      expect(plan.kind, BookshelfReaderOpenKind.readerFallback);
      expect(plan.readerRoute, contains('/reader/remote_1'));
    });

    test('resolves imported local open plan with local book hint', () async {
      final book = _localBookshelfBook();
      final localBook = LocalBook(
        id: book.bookId,
        title: book.title,
        format: LocalBookFormat.txt,
        storagePath: '/tmp/local.txt',
        fileSize: 2048,
        chapterCount: 0,
        indexStatus: LocalBookIndexStatus.indexing,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      final plan = await controller.resolveImportedLocalOpenPlan(
        book: book,
        localBook: localBook,
        openRequestedAtMs: 1700000000000,
      );

      expect(plan.action, BookshelfReaderOpenAction.openReader);
      expect(plan.kind, BookshelfReaderOpenKind.readerFallback);
      expect(plan.shouldStartBackgroundIndex, isTrue);
      expect(localBookRepository.getBookByIdCalls, 0);
    });

    test('matches progress after reader exit by source and detail url', () {
      final book = _remoteBook();
      final progress = ReadingProgress(
        bookId: book.bookId,
        sourceId: book.sourceId,
        detailUrl: book.detailUrl,
        chapterId: 'chapter_1',
        chapterUrl: 'https://reader.test/chapter-1',
        chapterTitle: '第一章',
        chapterIndex: 0,
        updatedAt: DateTime.utc(2026),
      );

      expect(
        controller.matchingProgressAfterExit(
          latestProgress: progress,
          book: book,
        ),
        same(progress),
      );
      expect(
        controller.matchingProgressAfterExit(
          latestProgress: ReadingProgress(
            bookId: progress.bookId,
            sourceId: progress.sourceId,
            detailUrl: 'https://other.test',
            chapterId: progress.chapterId,
            chapterUrl: progress.chapterUrl,
            chapterTitle: progress.chapterTitle,
            chapterIndex: progress.chapterIndex,
            updatedAt: progress.updatedAt,
          ),
          book: book,
        ),
        isNull,
      );
    });
  });
}

BookshelfBook _remoteBook() {
  return BookshelfBook(
    bookId: 'remote_1',
    sourceId: 'remote_source',
    title: '远程书',
    detailUrl: 'https://reader.test/detail',
    addedAt: DateTime.utc(2026),
    author: '作者',
    coverUrl: 'https://reader.test/cover.png',
  );
}

BookshelfBook _localBookshelfBook() {
  return BookshelfBook(
    bookId: 'local_1',
    sourceId: LocalBookImportService.localBookSourceId,
    title: '本地图书',
    detailUrl: 'local://book/local_1',
    addedAt: DateTime.utc(2026),
  );
}

class _FakeLocalBookRepository implements LocalBookRepository {
  int getBookByIdCalls = 0;

  @override
  Future<LocalBook?> getBookById(String bookId) async {
    getBookByIdCalls += 1;
    return null;
  }

  @override
  Future<void> deleteBook(String bookId) => throw UnimplementedError();

  @override
  Future<LocalBook?> findBookByImportFingerprint({
    required LocalBookFormat format,
    required String title,
    required int sourceFileSize,
  }) => throw UnimplementedError();

  @override
  Future<List<LocalBook>> getAllBooks() => throw UnimplementedError();

  @override
  Future<LocalBook?> getBookBySourcePath(String sourcePath) =>
      throw UnimplementedError();

  @override
  Future<LocalChapter?> getChapterById(String chapterId) =>
      throw UnimplementedError();

  @override
  Future<LocalChapter?> getChapterByIndex(String bookId, int chapterIndex) =>
      throw UnimplementedError();

  @override
  Future<LocalChapter?> getChapterContentById(String chapterId) =>
      throw UnimplementedError();

  @override
  Future<LocalChapter?> getChapterContentByIndex(
    String bookId,
    int chapterIndex,
  ) => throw UnimplementedError();

  @override
  Future<LocalChapter?> getChapterMetaById(String chapterId) =>
      throw UnimplementedError();

  @override
  Future<LocalChapter?> getChapterMetaByIndex(
    String bookId,
    int chapterIndex,
  ) => throw UnimplementedError();

  @override
  Future<List<LocalChapter>> getChapterMetas(String bookId) =>
      throw UnimplementedError();

  @override
  Future<List<LocalChapter>> getChapters(String bookId) =>
      throw UnimplementedError();

  @override
  Future<void> replaceChapters({
    required String bookId,
    required List<LocalChapter> chapters,
  }) => throw UnimplementedError();

  @override
  Future<void> updateBookIndexState({
    required String bookId,
    required LocalBookIndexStatus status,
    int? chapterCount,
    String? lastError,
    bool clearLastError = false,
  }) => throw UnimplementedError();

  @override
  Future<void> updateChapterContent({
    required String chapterId,
    required String content,
    List<String> imageUrls = const <String>[],
    ReaderDocument? document,
  }) => throw UnimplementedError();

  @override
  Future<void> upsertBook(LocalBook book) => throw UnimplementedError();

  @override
  Stream<List<LocalBook>> watchAllBooks() {
    return Stream<List<LocalBook>>.value(const <LocalBook>[]);
  }
}
