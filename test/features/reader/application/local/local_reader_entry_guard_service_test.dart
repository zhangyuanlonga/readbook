import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/bookmark.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record.dart';
import 'package:shuxiang_reading_next/domain/repositories/local_book_repository.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_reader_entry_guard_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_reader_identity.dart';

void main() {
  group('LocalReaderEntryGuardService', () {
    late _FakeLocalBookRepository repository;
    late LocalReaderEntryGuardService service;

    setUp(() {
      repository = _FakeLocalBookRepository();
      service = LocalReaderEntryGuardService(localBookRepository: repository);
    });

    test('returns unavailable when local book is removed', () async {
      final result = await service.guardRecord(_record());

      expect(result.action, LocalReaderEntryGuardAction.unavailable);
      expect(result.route, isNull);
      expect(result.message, contains('移除'));
    });

    test('opens local detail when book is not ready', () async {
      repository.books['book_1'] = _book(
        indexStatus: LocalBookIndexStatus.failed,
        chapterCount: 0,
      );

      final result = await service.guardRecord(_record());

      expect(result.action, LocalReaderEntryGuardAction.openDetail);
      expect(result.route, contains('/book/book_1'));
      expect(result.message, contains('索引失败'));
    });

    test('opens local detail when target chapter is missing', () async {
      repository.books['book_1'] = _book();

      final result = await service.guardRecord(_record());

      expect(result.action, LocalReaderEntryGuardAction.openDetail);
      expect(result.route, contains('/book/book_1'));
      expect(result.message, contains('章节已缺失'));
    });

    test('opens existing chapter and preserves bookmark id', () async {
      repository.books['book_1'] = _book();
      repository.chaptersById['chapter_2'] = _chapter(
        id: 'chapter_2',
        index: 1,
      );

      final result = await service.guardBookmark(
        Bookmark(
          id: 'bookmark_1',
          bookId: 'book_1',
          chapterId: 'chapter_2',
          chapterIndex: 1,
          startOffset: 0,
          endOffset: 4,
          snippet: '摘录',
          createdAt: DateTime.utc(2026, 5, 12),
          updatedAt: DateTime.utc(2026, 5, 12),
        ),
      );

      expect(result.action, LocalReaderEntryGuardAction.openReader);
      expect(result.route, contains('/reader/book_1/chapter_2'));
      expect(result.route, contains('bookmarkId=bookmark_1'));
      expect(result.message, isNull);
    });

    test('falls back to first chapter for bootstrap record', () async {
      repository.books['book_1'] = _book();
      repository.chaptersByIndex['book_1|0'] = _chapter(
        id: 'chapter_1',
        index: 0,
      );

      final result = await service.guardRecord(
        ReadingRecord(
          bookId: 'book_1',
          sourceId: LocalReaderIdentity.localSourceId,
          detailUrl: LocalReaderIdentity.buildBookDetailUrl('book_1'),
          bookTitle: '本地图书',
          lastChapterId: 'bootstrap',
          lastReadAt: DateTime.utc(2026, 5, 12),
        ),
      );

      expect(result.action, LocalReaderEntryGuardAction.openReader);
      expect(result.route, contains('/reader/book_1/chapter_1'));
    });
  });
}

ReadingRecord _record() {
  return ReadingRecord(
    bookId: 'book_1',
    sourceId: LocalReaderIdentity.localSourceId,
    detailUrl: LocalReaderIdentity.buildBookDetailUrl('book_1'),
    bookTitle: '本地图书',
    lastChapterId: 'chapter_2',
    lastChapterTitle: '第二章',
    lastChapterIndex: 1,
    lastChapterUrl: LocalReaderIdentity.buildChapterUrl('chapter_2'),
    lastReadAt: DateTime.utc(2026, 5, 12),
  );
}

LocalBook _book({
  LocalBookIndexStatus indexStatus = LocalBookIndexStatus.ready,
  int chapterCount = 2,
}) {
  return LocalBook(
    id: 'book_1',
    title: '本地图书',
    format: LocalBookFormat.txt,
    storagePath: '/tmp/book.txt',
    fileSize: 100,
    indexStatus: indexStatus,
    chapterCount: chapterCount,
    createdAt: DateTime.utc(2026, 5, 12),
    updatedAt: DateTime.utc(2026, 5, 12),
  );
}

LocalChapter _chapter({required String id, required int index}) {
  return LocalChapter(
    id: id,
    bookId: 'book_1',
    chapterIndex: index,
    title: '第 ${index + 1} 章',
    content: '正文',
    createdAt: DateTime.utc(2026, 5, 12),
    updatedAt: DateTime.utc(2026, 5, 12),
  );
}

class _FakeLocalBookRepository implements LocalBookRepository {
  final Map<String, LocalBook> books = <String, LocalBook>{};
  final Map<String, LocalChapter> chaptersById = <String, LocalChapter>{};
  final Map<String, LocalChapter> chaptersByIndex = <String, LocalChapter>{};

  @override
  Future<LocalBook?> getBookById(String bookId) async => books[bookId];

  @override
  Future<LocalChapter?> getChapterById(String chapterId) async {
    return chaptersById[chapterId];
  }

  @override
  Future<LocalChapter?> getChapterMetaById(String chapterId) async {
    return chaptersById[chapterId];
  }

  @override
  Future<LocalChapter?> getChapterMetaByIndex(
    String bookId,
    int chapterIndex,
  ) async {
    return chaptersByIndex['$bookId|$chapterIndex'];
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
  Stream<List<LocalBook>> watchAllBooks() =>
      Stream<List<LocalBook>>.value(books.values.toList(growable: false));
}
