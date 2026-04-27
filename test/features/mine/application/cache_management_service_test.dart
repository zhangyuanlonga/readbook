import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/cache/cover_image_disk_cache.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/domain/entities/book_metadata_override.dart';
import 'package:shuxiang_reading_next/domain/entities/bookshelf_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/local_book_import_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/cache_management_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CacheManagementService', () {
    late AppDatabase database;
    late _FakeBookshelfService bookshelfService;
    late _FakeCoverImageDiskCache coverCache;
    late CacheManagementService service;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      database = AppDatabase(executor: NativeDatabase.memory());
      bookshelfService = _FakeBookshelfService();
      coverCache = _FakeCoverImageDiskCache();
      service = CacheManagementService(
        bookshelfService: bookshelfService,
        database: database,
        coverImageDiskCache: coverCache,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'builds presentation index and clears caches via dependencies',
      () async {
        final now = DateTime.parse('2026-04-27T12:00:00.000Z');
        bookshelfService.books = <BookshelfBook>[
          BookshelfBook(
            bookId: 'local_book_1',
            sourceId: LocalBookImportService.localBookSourceId,
            detailUrl: '/local/1',
            title: '书架标题',
            addedAt: now,
          ),
        ];
        await database.upsertLocalBook(
          LocalBook(
            id: 'local_book_1',
            title: '本地图书',
            format: LocalBookFormat.txt,
            storagePath: '/tmp/local.txt',
            fileSize: 42,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await database.upsertBookMetadataOverride(
          BookMetadataOverride.forLocal(
            bookId: 'local_book_1',
            title: '覆盖标题',
            coverPath: '/tmp/cover.png',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await database.upsertReadingRecord(
          ReadingRecord(
            bookId: 'local_book_1',
            sourceId: LocalBookImportService.localBookSourceId,
            detailUrl: '/local/1',
            bookTitle: '最近阅读标题',
            lastReadAt: now,
          ),
        );
        await database.upsertChapterCache(
          cacheKey: 'local::1',
          bookId: 'local_book_1',
          sourceId: LocalBookImportService.localBookSourceId,
          chapterIndex: 0,
          chapterUrl: '/chapter/1',
          chapterTitle: '第一章',
          content: 'content',
        );

        final index = await service.buildBookPresentationIndex();
        final summaries = await service.watchCachedBooks().first;
        final clearedAll = await service.clearAllCaches();
        final clearedBook = await service.clearBookCache(
          bookId: 'local_book_1',
          coverUrl: 'cover://one',
        );

        expect(index['local_book_1']?.title, '覆盖标题');
        expect(index['local_book_1']?.inBookshelf, isTrue);
        expect(summaries, hasLength(1));
        expect(summaries.first.cachedCount, 1);
        expect(clearedAll, 3);
        expect(clearedBook, isTrue);
        expect(coverCache.clearedUrls, contains('cover://one'));
      },
    );
  });
}

class _FakeBookshelfService extends BookshelfService {
  List<BookshelfBook> books = const <BookshelfBook>[];

  @override
  Future<List<BookshelfBook>> getAll() async => books;
}

class _FakeCoverImageDiskCache extends CoverImageDiskCache {
  _FakeCoverImageDiskCache();

  final List<String> clearedUrls = <String>[];

  @override
  Future<int> clearAll() async => 3;

  @override
  Future<bool> clearByUrl(String imageUrl) async {
    clearedUrls.add(imageUrl);
    return true;
  }
}
