import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/data/repositories/book_metadata_override_repository_impl.dart';
import 'package:shuxiang_reading_next/data/repositories/local_book_repository_impl.dart';
import 'package:shuxiang_reading_next/domain/entities/book_metadata_override.dart';
import 'package:shuxiang_reading_next/domain/entities/bookshelf_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record.dart';
import 'package:shuxiang_reading_next/domain/entities/script_source.dart';
import 'package:shuxiang_reading_next/features/book/application/book_presentation_query_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_presentation_query_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/local_book_import_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_facade.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_contract.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_manifest.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_registry.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_result_models.dart'
    as runtime_models;
import 'package:shuxiang_reading_next/domain/repositories/script_source_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookshelfPresentationQueryService', () {
    late AppDatabase database;
    late BookshelfPresentationQueryService service;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      database = AppDatabase(executor: NativeDatabase.memory());
      service = BookshelfPresentationQueryService(
        database: database,
        bookPresentationQueryService: BookPresentationQueryService(
          bookMetadataOverrideRepository: BookMetadataOverrideRepositoryImpl(
            database,
          ),
        ),
        localBookRepository: LocalBookRepositoryImpl(database),
        sourceRuntimeFacade: _FakeSourceRuntimeFacade(
          runtimeSources: <RegisteredSource>[
            _buildRegisteredSource(id: 'runtime_source', name: '运行时源'),
          ],
          persistedSources: <ScriptSource>[
            ScriptSource(
              id: 'persisted_source',
              name: '持久化源',
              sourceCode: 'capabilities: [manga]',
              enabled: true,
              createdAt: DateTime.parse('2026-04-27T00:00:00.000Z'),
              updatedAt: DateTime.parse('2026-04-27T00:00:00.000Z'),
            ),
          ],
        ),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'loads override map, local books, cache stats and reading records',
      () async {
        final now = DateTime.parse('2026-04-27T12:00:00.000Z');
        await database.upsertLocalBook(
          LocalBook(
            id: 'local_book_1',
            title: '本地图书',
            format: LocalBookFormat.txt,
            storagePath: '/tmp/book.txt',
            fileSize: 128,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await database.upsertBookMetadataOverride(
          BookMetadataOverride.forRemote(
            sourceId: 'remote_source',
            detailUrl: '/detail/1',
            title: '远程覆盖标题',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await database.upsertBookMetadataOverride(
          BookMetadataOverride.forLocal(
            bookId: 'local_book_1',
            title: '本地覆盖标题',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await database.upsertChapterCache(
          cacheKey: 'remote_source::1',
          bookId: 'remote_book_1',
          sourceId: 'remote_source',
          chapterIndex: 0,
          chapterUrl: '/chapter/1',
          chapterTitle: '第一章',
          content: 'content',
        );
        await database.upsertReadingRecord(
          ReadingRecord(
            bookId: 'remote_book_1',
            sourceId: 'remote_source',
            detailUrl: '/detail/1',
            bookTitle: '远程书籍',
            lastReadAt: now,
          ),
        );

        final books = <BookshelfBook>[
          BookshelfBook(
            bookId: 'remote_book_1',
            sourceId: 'remote_source',
            detailUrl: '/detail/1',
            title: '远程书籍',
            addedAt: now,
          ),
          BookshelfBook(
            bookId: 'local_book_1',
            sourceId: LocalBookImportService.localBookSourceId,
            detailUrl: '/local/1',
            title: '本地图书',
            addedAt: now,
          ),
        ];

        final overrideMap = await service.loadBookMetadataOverrideMap(books);
        final localMap = await service.loadLocalBookMap(books);
        final latestTitles = await service.loadLatestCachedChapterTitles(
          const <MapEntry<String, String>>[
            MapEntry('remote_book_1', 'remote_source'),
          ],
        );
        final cachedCounts = await service.loadCachedChapterCounts(
          const <MapEntry<String, String>>[
            MapEntry('remote_book_1', 'remote_source'),
          ],
        );
        final records = await service.listLatestReadingRecords();

        expect(
          overrideMap[BookMetadataOverride.remoteTargetKey(
                sourceId: 'remote_source',
                detailUrl: '/detail/1',
              )]
              ?.title,
          '远程覆盖标题',
        );
        expect(
          overrideMap[BookMetadataOverride.localTargetKey('local_book_1')]
              ?.title,
          '本地覆盖标题',
        );
        expect(localMap['local_book_1']?.title, '本地图书');
        expect(latestTitles['remote_source\u0000remote_book_1'], '第一章');
        expect(cachedCounts['remote_source\u0000remote_book_1'], 1);
        expect(records, hasLength(1));
        expect(records.first.bookId, 'remote_book_1');
      },
    );

    test('merges runtime and persisted source type map', () async {
      final result = await service.loadSourceTypeMap(
        timeout: const Duration(milliseconds: 10),
        inferRuntimeSourceType: (_) => 1,
        inferPersistedSourceType: (_) => 2,
      );

      expect(result['runtime_source'], 1);
      expect(result['persisted_source'], 2);
    });
  });
}

class _FakeSourceRuntimeFacade extends SourceRuntimeFacade {
  _FakeSourceRuntimeFacade({
    required this.runtimeSources,
    required this.persistedSources,
  }) : super(scriptSourceRepository: _FakeScriptSourceRepository());

  final List<RegisteredSource> runtimeSources;
  final List<ScriptSource> persistedSources;

  @override
  List<RegisteredSource> registeredScriptSources({bool enabledOnly = true}) {
    return runtimeSources;
  }

  @override
  Future<List<ScriptSource>> listScriptSources() async {
    return persistedSources;
  }
}

class _FakeScriptSourceRepository implements ScriptSourceRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<List<ScriptSource>> getAll() async => const <ScriptSource>[];

  @override
  Future<ScriptSource?> getById(String id) async => null;

  @override
  Future<void> setEnabled({required String id, required bool enabled}) async {}

  @override
  Future<void> upsert(ScriptSource source) async {}

  @override
  Stream<List<ScriptSource>> watchAll() =>
      const Stream<List<ScriptSource>>.empty();
}

RegisteredSource _buildRegisteredSource({
  required String id,
  required String name,
}) {
  return RegisteredSource(
    runtime: SourceRuntimeInfo(
      id: id,
      name: name,
      group: '测试',
      revision: 'test',
    ),
    definition: RuntimeSourceDefinition(
      manifest: SourceManifest(
        name: name,
        group: '测试',
        author: 'tester',
        description: '',
        capabilities: const <String>{'novel'},
      ),
      search: (_, __) async => const [],
      detail: (_, book) async => book,
      chapters: (_, __) async => const [],
      content:
          (_, __, ___) async =>
              const runtime_models.Content(title: '', content: ''),
    ),
  );
}
