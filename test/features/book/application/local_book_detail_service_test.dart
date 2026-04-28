import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/data/repositories/local_book_repository_impl.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_chapter.dart';
import 'package:shuxiang_reading_next/features/book/application/local_book_detail_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_index_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reading_record_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  group('LocalBookDetailService', () {
    late AppDatabase database;
    late LocalBookRepositoryImpl repository;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = LocalBookRepositoryImpl(database);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'loads local book detail with explicitly injected dependencies',
      () async {
        final now = DateTime.parse('2026-04-27T12:00:00.000Z');
        const bookId = 'local_book_1';
        await repository.upsertBook(
          LocalBook(
            id: bookId,
            title: '本地图书',
            format: LocalBookFormat.txt,
            storagePath: '/tmp/book.txt',
            fileSize: 128,
            createdAt: now,
            updatedAt: now,
            indexStatus: LocalBookIndexStatus.ready,
            chapterCount: 1,
          ),
        );
        await repository.replaceChapters(
          bookId: bookId,
          chapters: <LocalChapter>[
            LocalChapter(
              id: 'chapter_1',
              bookId: bookId,
              chapterIndex: 0,
              title: '第一章',
              content: '正文',
              createdAt: now,
              updatedAt: now,
            ),
          ],
        );

        final service = LocalBookDetailService(
          localBookRepository: repository,
          indexService: _FakeLocalBookIndexService(repository, database),
        );

        final result = await service.load(
          bookId: bookId,
          mode: LocalBookDetailLoadMode.withContent,
        );

        expect(result.book.id, bookId);
        expect(result.chapters, hasLength(1));
        expect(result.chapters.first.content, '正文');
      },
    );

    test('loads directory-only detail without body payload', () async {
      final now = DateTime.parse('2026-04-27T12:00:00.000Z');
      const bookId = 'local_book_meta_1';
      await repository.upsertBook(
        LocalBook(
          id: bookId,
          title: '本地图书目录',
          format: LocalBookFormat.epub,
          storagePath: '/tmp/book.epub',
          fileSize: 128,
          createdAt: now,
          updatedAt: now,
          indexStatus: LocalBookIndexStatus.ready,
          chapterCount: 1,
        ),
      );
      await repository.replaceChapters(
        bookId: bookId,
        chapters: <LocalChapter>[
          LocalChapter(
            id: 'chapter_meta_1',
            bookId: bookId,
            chapterIndex: 0,
            title: '第一章',
            content: '正文',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      final service = LocalBookDetailService(
        localBookRepository: repository,
        indexService: _FakeLocalBookIndexService(repository, database),
      );

      final result = await service.load(
        bookId: bookId,
        mode: LocalBookDetailLoadMode.directoryOnly,
      );

      expect(result.chapters, hasLength(1));
      expect(result.chapters.first.title, '第一章');
      expect(result.chapters.first.content, isEmpty);
    });
  });
}

class _FakeLocalBookIndexService extends LocalBookIndexService {
  _FakeLocalBookIndexService(this._repository, AppDatabase database)
    : super(
        localBookRepository: _repository,
        readingRecordService: ReadingRecordService(database: database),
      );

  final LocalBookRepositoryImpl _repository;

  @override
  Future<LocalBook?> refreshBookState({required String bookId}) {
    return _repository.getBookById(bookId);
  }

  @override
  Future<List<LocalChapter>> ensureIndexed({
    required String bookId,
    bool force = false,
  }) async {
    return _repository.getChapters(bookId);
  }
}
