import 'package:drift/native.dart';
import 'package:flutter_appread/core/errors/error_codes.dart';
import 'package:flutter_appread/core/errors/error_stage.dart';
import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_appread/data/repositories/local_book_repository_impl.dart';
import 'package:flutter_appread/domain/entities/local_book.dart';
import 'package:flutter_appread/features/reader/application/local/local_book_index_service.dart';
import 'package:flutter_appread/features/reader/application/local/local_book_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalBookIndexService', () {
    late AppDatabase database;
    late LocalBookRepositoryImpl repository;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = LocalBookRepositoryImpl(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('writes parsed chapters and marks book ready', () async {
      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      await repository.upsertBook(
        LocalBook(
          id: 'local_index_1',
          title: '索引测试',
          format: LocalBookFormat.txt,
          storagePath: '/tmp/demo.txt',
          fileSize: 1,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final service = LocalBookIndexService(
        localBookRepository: repository,
        parsers: const [_FakeSuccessParser()],
      );

      final chapters = await service.ensureIndexed(bookId: 'local_index_1');

      expect(chapters, hasLength(2));
      final updated = await repository.getBookById('local_index_1');
      expect(updated, isNotNull);
      expect(updated!.indexStatus, LocalBookIndexStatus.ready);
      expect(updated.chapterCount, 2);
    });

    test('marks book failed when parser throws', () async {
      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      await repository.upsertBook(
        LocalBook(
          id: 'local_index_2',
          title: '失败测试',
          format: LocalBookFormat.txt,
          storagePath: '/tmp/demo.txt',
          fileSize: 1,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final service = LocalBookIndexService(
        localBookRepository: repository,
        parsers: const [_FakeFailureParser()],
      );

      await expectLater(
        service.ensureIndexed(bookId: 'local_index_2'),
        throwsA(isA<AppException>()),
      );

      final updated = await repository.getBookById('local_index_2');
      expect(updated, isNotNull);
      expect(updated!.indexStatus, LocalBookIndexStatus.failed);
      expect(updated.chapterCount, 0);
      expect(updated.lastError, contains('模拟解析失败'));
    });
  });
}

class _FakeSuccessParser implements LocalBookParser {
  const _FakeSuccessParser();

  @override
  Future<LocalParsedBook> parse(LocalBook book) async {
    return const LocalParsedBook(
      chapters: [
        LocalParsedChapter(title: '第一章', content: '内容1'),
        LocalParsedChapter(title: '第二章', content: '内容2'),
      ],
    );
  }

  @override
  bool supports(LocalBookFormat format) => true;
}

class _FakeFailureParser implements LocalBookParser {
  const _FakeFailureParser();

  @override
  Future<LocalParsedBook> parse(LocalBook book) {
    throw AppException(
      code: ErrorCode.ruleParse,
      stage: ErrorStage.content,
      briefMessage: '模拟解析失败',
    );
  }

  @override
  bool supports(LocalBookFormat format) => true;
}
