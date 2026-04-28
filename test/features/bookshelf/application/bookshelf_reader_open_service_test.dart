import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/domain/entities/bookshelf_book.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_progress.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_toc_snapshot.dart';
import 'package:shuxiang_reading_next/domain/repositories/local_book_repository.dart';
import 'package:shuxiang_reading_next/features/book/application/book_detail_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_reader_open_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/local_book_import_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_entry_route_resolver.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookshelfReaderOpenService', () {
    late ReaderPreferencesService preferencesService;
    late _FakeLocalBookRepository localBookRepository;
    late BookshelfReaderOpenService service;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      preferencesService = ReaderPreferencesService();
      localBookRepository = _FakeLocalBookRepository();
      service = BookshelfReaderOpenService(
        readerPreferencesService: preferencesService,
        readerEntryRouteResolver: const ReaderEntryRouteResolver(),
        localBookRepository: localBookRepository,
        bookDetailService: BookDetailService(),
      );
    });

    test('prefers persisted reading progress when it matches the book', () async {
      const requestedAtMs = 1700000000000;
      final book = _remoteBook();
      final progress = ReadingProgress(
        bookId: book.bookId,
        sourceId: book.sourceId,
        detailUrl: book.detailUrl,
        chapterId: 'chapter_2',
        chapterUrl: 'https://reader.test/chapter-2',
        chapterTitle: '第二章',
        chapterIndex: 1,
        updatedAt: DateTime.parse('2026-04-28T09:00:00.000Z'),
      );
      await preferencesService.saveProgress(progress);

      final plan = await service.resolve(
        book: book,
        openRequestedAtMs: requestedAtMs,
      );

      expect(plan.action, BookshelfReaderOpenAction.openReader);
      expect(plan.kind, BookshelfReaderOpenKind.progress);
      expect(plan.latestProgress?.chapterId, 'chapter_2');
      expect(plan.readerRoute, contains('chapter_2'));
      expect(plan.readerRoute, contains('openRequestedAtMs=$requestedAtMs'));
      expect(plan.readerRoute, contains('openRouteKind=progress'));
    });

    test('uses toc snapshot before remote fallback when no progress exists', () async {
      const requestedAtMs = 1700000001000;
      final book = _remoteBook();
      await preferencesService.saveTocSnapshot(
        ReaderTocSnapshot(
          bookId: book.bookId,
          sourceId: book.sourceId,
          detailUrl: book.detailUrl,
          title: book.title,
          author: book.author,
          coverUrl: book.coverUrl,
          chapters: const <Chapter>[
            Chapter(
              id: 'volume_1',
              bookId: 'remote_1',
              title: '卷一',
              chapterUrl: '',
              index: 0,
              isVolume: true,
            ),
            Chapter(
              id: 'chapter_1',
              bookId: 'remote_1',
              title: '第一章',
              chapterUrl: 'https://reader.test/chapter-1',
              index: 1,
            ),
          ],
          updatedAt: DateTime.parse('2026-04-28T09:10:00.000Z'),
        ),
      );

      final plan = await service.resolve(
        book: book,
        openRequestedAtMs: requestedAtMs,
      );

      expect(plan.action, BookshelfReaderOpenAction.openReader);
      expect(plan.kind, BookshelfReaderOpenKind.tocSnapshot);
      expect(plan.tocSnapshotHit, isTrue);
      expect(plan.readerRoute, contains('chapter_1'));
      expect(plan.readerRoute, contains('openRouteKind=tocSnapshot'));
    });

    test('uses first local chapter meta instead of full chapter list', () async {
      const requestedAtMs = 1700000002000;
      final book = _localBook();
      final localBook = LocalBook(
        id: book.bookId,
        title: book.title,
        format: LocalBookFormat.epub,
        storagePath: '/tmp/local.epub',
        fileSize: 1024,
        chapterCount: 8,
        indexStatus: LocalBookIndexStatus.ready,
        createdAt: DateTime.parse('2026-04-28T08:00:00.000Z'),
        updatedAt: DateTime.parse('2026-04-28T08:00:00.000Z'),
      );
      localBookRepository.bookById[book.bookId] = localBook;
      localBookRepository.chapterMetaByIndex['${book.bookId}|0'] = LocalChapter(
        id: 'local_chapter_1',
        bookId: book.bookId,
        chapterIndex: 0,
        title: '本地第一章',
        content: '',
        createdAt: DateTime.parse('2026-04-28T08:00:00.000Z'),
        updatedAt: DateTime.parse('2026-04-28T08:00:00.000Z'),
      );

      final plan = await service.resolve(
        book: book,
        openRequestedAtMs: requestedAtMs,
        localBookHint: localBook,
      );

      expect(plan.action, BookshelfReaderOpenAction.openReader);
      expect(plan.kind, BookshelfReaderOpenKind.localFirstChapterMeta);
      expect(plan.localFirstChapterMetaHit, isTrue);
      expect(plan.readerRoute, contains('local_chapter_1'));
      expect(localBookRepository.getChaptersCalls, 0);
      expect(localBookRepository.getChapterMetaByIndexCalls, 1);
    });

    test('keeps txt non-ready local books on reader fallback and starts indexing', () async {
      const requestedAtMs = 1700000003000;
      final book = _localBook();
      final localBook = LocalBook(
        id: book.bookId,
        title: book.title,
        format: LocalBookFormat.txt,
        storagePath: '/tmp/local.txt',
        fileSize: 2048,
        chapterCount: 0,
        indexStatus: LocalBookIndexStatus.indexing,
        createdAt: DateTime.parse('2026-04-28T08:30:00.000Z'),
        updatedAt: DateTime.parse('2026-04-28T08:30:00.000Z'),
      );

      final plan = await service.resolve(
        book: book,
        openRequestedAtMs: requestedAtMs,
        localBookHint: localBook,
      );

      expect(plan.action, BookshelfReaderOpenAction.openReader);
      expect(plan.kind, BookshelfReaderOpenKind.readerFallback);
      expect(plan.shouldStartBackgroundIndex, isTrue);
      expect(plan.feedbackMessage, isNotEmpty);
      expect(plan.readerRoute, contains('bootstrap'));
    });
  });
}

BookshelfBook _remoteBook() {
  return BookshelfBook(
    bookId: 'remote_1',
    sourceId: 'remote_source',
    detailUrl: 'https://reader.test/detail',
    title: '远程书',
    addedAt: DateTime.parse('2026-04-28T08:00:00.000Z'),
    author: '作者',
    coverUrl: 'https://reader.test/cover.png',
    latestChapter: '最新章节',
  );
}

BookshelfBook _localBook() {
  return BookshelfBook(
    bookId: 'local_1',
    sourceId: LocalBookImportService.localBookSourceId,
    detailUrl: 'local://book/local_1',
    title: '本地图书',
    addedAt: DateTime.parse('2026-04-28T08:00:00.000Z'),
    author: '作者',
    coverUrl: '',
    latestChapter: '',
  );
}

class _FakeLocalBookRepository implements LocalBookRepository {
  final Map<String, LocalBook> bookById = <String, LocalBook>{};
  final Map<String, LocalChapter> chapterMetaByIndex = <String, LocalChapter>{};
  int getChaptersCalls = 0;
  int getChapterMetaByIndexCalls = 0;

  @override
  Future<LocalBook?> getBookById(String bookId) async => bookById[bookId];

  @override
  Future<LocalChapter?> getChapterMetaByIndex(
    String bookId,
    int chapterIndex,
  ) async {
    getChapterMetaByIndexCalls += 1;
    return chapterMetaByIndex['$bookId|$chapterIndex'];
  }

  @override
  Future<List<LocalChapter>> getChapters(String bookId) async {
    getChaptersCalls += 1;
    return const <LocalChapter>[];
  }

  @override
  Future<void> deleteBook(String bookId) => throw UnimplementedError();

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
  Future<List<LocalChapter>> getChapterMetas(String bookId) =>
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
}
