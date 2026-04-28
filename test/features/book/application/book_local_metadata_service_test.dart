import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/domain/repositories/local_book_repository.dart';
import 'package:shuxiang_reading_next/features/book/application/book_local_metadata_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/local_book_import_service.dart';

void main() {
  test('loads local book only for local source id', () async {
    final repository = _FakeLocalBookRepository();
    final service = BookLocalMetadataService(localBookRepository: repository);

    final localBook = await service.loadLocalBook(
      sourceId: LocalBookImportService.localBookSourceId,
      bookId: 'local_1',
    );
    final remoteBook = await service.loadLocalBook(
      sourceId: 'remote_source',
      bookId: 'local_1',
    );

    expect(localBook?.id, 'local_1');
    expect(remoteBook, isNull);
    expect(repository.requestedBookIds, <String>['local_1']);
  });
}

class _FakeLocalBookRepository implements LocalBookRepository {
  final List<String> requestedBookIds = <String>[];

  @override
  Future<LocalBook?> getBookById(String bookId) async {
    requestedBookIds.add(bookId);
    return LocalBook(
      id: bookId,
      title: '本地图书',
      format: LocalBookFormat.txt,
      storagePath: '/tmp/$bookId.txt',
      fileSize: 1,
      createdAt: DateTime.parse('2026-04-27T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-04-27T00:00:00.000Z'),
    );
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
}
