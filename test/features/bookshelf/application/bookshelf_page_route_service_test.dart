import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/domain/entities/bookshelf_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_progress.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record.dart';
import 'package:shuxiang_reading_next/domain/repositories/local_book_repository.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_page_route_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_reader_entry_guard_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_reader_identity.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_entry_route_resolver.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookshelfPageRouteService', () {
    late ReaderPreferencesService preferencesService;
    late BookshelfPageRouteService service;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      preferencesService = ReaderPreferencesService();
      service = BookshelfPageRouteService(
        readerPreferencesService: preferencesService,
        readerEntryRouteResolver: const ReaderEntryRouteResolver(),
      );
    });

    test('uses matched progress route for latest reading record', () async {
      final record = _record();
      await preferencesService.saveProgress(
        ReadingProgress(
          bookId: record.bookId,
          sourceId: record.sourceId,
          detailUrl: record.detailUrl,
          chapterId: 'chapter_2',
          chapterUrl: 'https://reader.test/chapter-2',
          chapterTitle: '第二章',
          chapterIndex: 1,
          updatedAt: DateTime.parse('2026-04-28T10:00:00.000Z'),
        ),
      );

      final resolution = await service.resolveLatestReadingRecordRoute(record);
      final route = resolution.route;

      expect(route, contains('/reader/'));
      expect(route, contains('chapter_2'));
    });

    test('falls back to detail route when no chapter locator exists', () async {
      final resolution = await service.resolveLatestReadingRecordRoute(
        ReadingRecord(
          bookId: 'book_detail_only',
          sourceId: 'source_detail_only',
          detailUrl: 'https://detail.test/book-detail-only',
          bookTitle: '测试书',
          lastReadAt: DateTime.utc(2026, 4, 28),
        ),
      );
      final route = resolution.route;

      expect(route, contains('/book/book_detail_only'));
      expect(route, contains('detailUrl='));
    });

    test('builds bookshelf fallback, progress and detail routes', () {
      final book = _book();
      final progress = ReadingProgress(
        bookId: book.bookId,
        sourceId: book.sourceId,
        detailUrl: book.detailUrl,
        chapterId: 'chapter_1',
        chapterUrl: 'https://reader.test/chapter-1',
        chapterTitle: '第一章',
        chapterIndex: 0,
        updatedAt: DateTime.parse('2026-04-28T10:00:00.000Z'),
      );

      expect(service.resolveReaderFallbackRoute(book), contains('/reader/'));
      expect(service.resolveProgressRoute(progress), contains('chapter_1'));
      expect(
        service.resolveBookDetailRoute(book, heroTag: 'hero_1'),
        contains('heroTag=hero_1'),
      );
    });

    test(
      'uses local progress guard resolution for continue reading route',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final localService = BookshelfPageRouteService(
          readerPreferencesService: ReaderPreferencesService(
            preferences: prefs,
          ),
          readerEntryRouteResolver: const ReaderEntryRouteResolver(),
          localReaderEntryGuardService: const _FakeLocalReaderEntryGuardService(
            progressResult: LocalReaderEntryGuardResult.openDetail(
              route: '/book/book_1?sourceId=local',
              message: '本地目录未就绪',
            ),
          ),
        );
        final record = ReadingRecord(
          bookId: 'book_1',
          sourceId: LocalReaderIdentity.localSourceId,
          detailUrl: LocalReaderIdentity.buildBookDetailUrl('book_1'),
          bookTitle: '本地图书',
          lastReadAt: DateTime.utc(2026, 4, 28),
        );
        await localService.resolveLatestReadingRecordRoute(record);
        await ReaderPreferencesService(preferences: prefs).saveProgress(
          ReadingProgress(
            bookId: 'book_1',
            sourceId: LocalReaderIdentity.localSourceId,
            detailUrl: LocalReaderIdentity.buildBookDetailUrl('book_1'),
            chapterId: 'chapter_1',
            chapterUrl: LocalReaderIdentity.buildChapterUrl('chapter_1'),
            chapterTitle: '第一章',
            chapterIndex: 0,
            updatedAt: DateTime.parse('2026-04-28T10:00:00.000Z'),
          ),
        );

        final resolution = await localService.resolveLatestReadingRecordRoute(
          record,
        );

        expect(resolution.route, '/book/book_1?sourceId=local');
        expect(resolution.message, '本地目录未就绪');
      },
    );

    test('uses record locator when no matched progress exists', () async {
      final resolution = await service.resolveLatestReadingRecordRoute(
        _record(),
      );

      expect(resolution.route, contains('/reader/'));
      expect(resolution.route, contains('chapter_1'));
      expect(resolution.route, contains('chapterIndex=0'));
    });
  });
}

ReadingRecord _record() {
  return ReadingRecord(
    bookId: 'book_1',
    sourceId: 'source_1',
    detailUrl: 'https://detail.test/book-1',
    bookTitle: '测试书',
    bookAuthor: '作者',
    coverUrl: 'https://image.test/cover.jpg',
    lastChapterId: 'chapter_1',
    lastChapterTitle: '第一章',
    lastChapterIndex: 0,
    lastChapterUrl: 'https://reader.test/chapter-1',
    lastReadAt: DateTime.utc(2026, 4, 28),
  );
}

BookshelfBook _book() {
  return BookshelfBook(
    bookId: 'book_1',
    sourceId: 'source_1',
    detailUrl: 'https://detail.test/book-1',
    title: '测试书',
    author: '作者',
    coverUrl: 'https://image.test/cover.jpg',
    addedAt: DateTime.parse('2026-04-28T10:00:00.000Z'),
  );
}

class _FakeLocalReaderEntryGuardService extends LocalReaderEntryGuardService {
  const _FakeLocalReaderEntryGuardService({
    this.progressResult = const LocalReaderEntryGuardResult.openReader(
      '/reader/book_1/chapter_1',
    ),
  }) : super(localBookRepository: const _UnusedLocalBookRepository());

  final LocalReaderEntryGuardResult progressResult;

  @override
  Future<LocalReaderEntryGuardResult> guardProgress(
    ReadingProgress progress,
  ) async {
    return progressResult;
  }
}

class _UnusedLocalBookRepository implements LocalBookRepository {
  const _UnusedLocalBookRepository();

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
  Future<LocalBook?> getBookById(String bookId) => throw UnimplementedError();

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
  Future<List<LocalChapter>> getChapterMetas(String bookId) =>
      throw UnimplementedError();

  @override
  Future<LocalChapter?> getChapterMetaById(String chapterId) =>
      throw UnimplementedError();

  @override
  Future<LocalChapter?> getChapterMetaByIndex(
    String bookId,
    int chapterIndex,
  ) => throw UnimplementedError();

  @override
  Future<List<LocalChapter>> getChapters(String bookId) =>
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
  Stream<List<LocalBook>> watchAllBooks() => throw UnimplementedError();
}
