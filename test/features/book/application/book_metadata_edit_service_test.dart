import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/media/image_selection_service.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/data/repositories/book_metadata_override_repository_impl.dart';
import 'package:shuxiang_reading_next/data/repositories/local_book_repository_impl.dart';
import 'package:shuxiang_reading_next/domain/entities/book_detail.dart';
import 'package:shuxiang_reading_next/domain/entities/book_metadata_override.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/domain/repositories/book_metadata_override_repository.dart';
import 'package:shuxiang_reading_next/domain/repositories/local_book_repository.dart';
import 'package:shuxiang_reading_next/features/book/application/book_metadata_edit_service.dart';
import 'package:shuxiang_reading_next/features/book/application/custom_cover_storage_service.dart';

void main() {
  final now = DateTime.parse('2026-04-27T12:00:00.000Z');

  test(
    'saveRemoteBookMetadata persists override when content differs',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final service = BookMetadataEditService(
        bookMetadataOverrideRepository: BookMetadataOverrideRepositoryImpl(
          database,
        ),
        localBookRepository: LocalBookRepositoryImpl(database),
        imageSelectionService: _FakeImageSelectionService(),
        customCoverStorageService: const _FakeCustomCoverStorageService(),
      );

      final result = await service.saveRemoteBookMetadata(
        detail: const BookDetail(
          id: 'book_1',
          sourceId: 'source_a',
          title: '原始标题',
          detailUrl: 'https://example.com/book/1',
          author: '原始作者',
        ),
        title: '覆盖标题',
        author: '覆盖作者',
        intro: '覆盖简介',
        customCoverPath: '/tmp/custom.png',
      );

      expect(result.metadataOverride, isNotNull);
      final stored = await database.getBookMetadataOverrideByRemoteBook(
        sourceId: 'source_a',
        detailUrl: 'https://example.com/book/1',
      );
      expect(stored?.title, '覆盖标题');
      expect(stored?.author, '覆盖作者');
      expect(stored?.coverPath, '/tmp/custom.png');
    },
  );

  test(
    'saveLocalBookMetadata returns updated local book and reindex flag',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final repository = LocalBookRepositoryImpl(database);
      final localBook = LocalBook(
        id: 'local_1',
        title: '原始标题',
        format: LocalBookFormat.txt,
        storagePath: '/tmp/book.txt',
        fileSize: 1,
        createdAt: now,
        updatedAt: now,
        charset: 'utf-8',
        splitLongChapter: true,
      );
      await repository.upsertBook(localBook);
      final service = BookMetadataEditService(
        bookMetadataOverrideRepository: BookMetadataOverrideRepositoryImpl(
          database,
        ),
        localBookRepository: repository,
        imageSelectionService: _FakeImageSelectionService(),
        customCoverStorageService: const _FakeCustomCoverStorageService(),
      );

      final result = await service.saveLocalBookMetadata(
        localBook: localBook,
        title: '新标题',
        author: '新作者',
        intro: '新简介',
        charset: 'gbk',
        splitLongChapter: false,
      );

      expect(result.localBook.title, '新标题');
      expect(result.localBook.author, '新作者');
      expect(result.localBook.description, '新简介');
      expect(result.needsReindex, isTrue);
    },
  );

  test('pickAndPersistCustomCover returns persisted file path', () async {
    final service = BookMetadataEditService(
      bookMetadataOverrideRepository: _NoopBookMetadataOverrideRepository(),
      localBookRepository: _NoopLocalBookRepository(),
      imageSelectionService: _FakeImageSelectionService(
        picked: PickedImageData(
          bytes: Uint8List.fromList(const <int>[1, 2, 3]),
          name: 'cover.png',
        ),
      ),
      customCoverStorageService: const _FakeCustomCoverStorageService(),
    );

    final path = await service.pickAndPersistCustomCover(
      detail: const BookDetail(
        id: 'book_1',
        sourceId: 'source_a',
        title: '标题',
        detailUrl: 'https://example.com/book/1',
      ),
    );

    expect(path, '/tmp/persisted-cover.png');
  });
}

class _FakeImageSelectionService extends ImageSelectionService {
  _FakeImageSelectionService({this.picked});

  final PickedImageData? picked;

  @override
  Future<PickedImageData?> pickImage({
    required String confirmButtonText,
    Set<String> allowedExtensions = const {'jpg', 'jpeg', 'png', 'webp'},
    ImageSelectionSource source = ImageSelectionSource.auto,
  }) async {
    return picked;
  }
}

class _FakeCustomCoverStorageService extends CustomCoverStorageService {
  const _FakeCustomCoverStorageService();

  @override
  Future<Uri?> persistForBook({
    required String sourceId,
    required String detailUrl,
    required PickedImageData picked,
  }) async {
    return File('/tmp/persisted-cover.png').uri;
  }
}

class _NoopBookMetadataOverrideRepository
    implements BookMetadataOverrideRepository {
  @override
  Future<List<BookMetadataOverride>> getAll() async =>
      const <BookMetadataOverride>[];

  @override
  Future<void> deleteByLocalBookId(String bookId) async {}

  @override
  Future<void> deleteByRemoteBook({
    required String sourceId,
    required String detailUrl,
  }) async {}

  @override
  Future<void> deleteByTargetKey(String targetKey) async {}

  @override
  Future<BookMetadataOverride?> getByLocalBookId(String bookId) async => null;

  @override
  Future<BookMetadataOverride?> getByRemoteBook({
    required String sourceId,
    required String detailUrl,
  }) async => null;

  @override
  Future<BookMetadataOverride?> getByTargetKey(String targetKey) async => null;

  @override
  Future<void> upsert(BookMetadataOverride metadataOverride) async {}
}

class _NoopLocalBookRepository implements LocalBookRepository {
  @override
  Future<void> deleteBook(String bookId) async {}

  @override
  Future<LocalBook?> getBookById(String bookId) async => null;

  @override
  Future<LocalBook?> getBookBySourcePath(String sourcePath) async => null;

  @override
  Future<LocalChapter?> getChapterById(String chapterId) async => null;

  @override
  Future<LocalChapter?> getChapterByIndex(
    String bookId,
    int chapterIndex,
  ) async => null;

  @override
  Future<List<LocalChapter>> getChapterMetas(String bookId) async =>
      const <LocalChapter>[];

  @override
  Future<List<LocalChapter>> getChapters(String bookId) async =>
      const <LocalChapter>[];

  @override
  Future<List<LocalBook>> getAllBooks() async => const <LocalBook>[];

  @override
  Future<void> replaceChapters({
    required String bookId,
    required List<LocalChapter> chapters,
  }) async {}

  @override
  Future<void> updateBookIndexState({
    required String bookId,
    required LocalBookIndexStatus status,
    int? chapterCount,
    String? lastError,
    bool clearLastError = false,
  }) async {}

  @override
  Future<void> updateChapterContent({
    required String chapterId,
    required String content,
    List<String> imageUrls = const <String>[],
    ReaderDocument? document,
  }) async {}

  @override
  Future<void> upsertBook(LocalBook book) async {}
}
