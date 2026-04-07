import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/script_source.dart';
import 'package:shuxiang_reading_next/domain/repositories/script_source_repository.dart';
import 'package:shuxiang_reading_next/features/reader/application/chapter_cache_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/chapter_content_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_facade.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_task_gate_service.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_contract.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_manifest.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_registry.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_result_models.dart'
    as runtime_models;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  group('ChapterCacheService', () {
    test('caches chapters with controlled concurrency instead of strict serial execution', () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      final contentService = _RecordingChapterContentService(
        delay: const Duration(milliseconds: 30),
      );
      final service = ChapterCacheService(
        database: database,
        contentService: contentService,
        maxConcurrentLoads: 3,
      );

      final chapters = List<Chapter>.generate(
        5,
        (index) => Chapter(
          id: 'c$index',
          bookId: 'book_1',
          title: '第${index + 1}章',
          chapterUrl: 'https://example.com/$index',
          index: index,
        ),
      );

      final progressEvents = await service
          .cacheRange(
            bookId: 'book_1',
            sourceId: 'source_1',
            chapters: chapters,
            startIndex: 0,
            endIndex: 4,
          )
          .toList();

      expect(contentService.maxConcurrentLoads, greaterThan(1));
      expect(contentService.maxConcurrentLoads, lessThanOrEqualTo(3));
      expect(progressEvents.last.done, 5);
      expect(progressEvents.last.failed, 0);
      expect(progressEvents.last.isCompleted, isTrue);

      await database.close();
    });

    test('serializes browser-heavy source caching', () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      final contentService = _RecordingChapterContentService(
        delay: const Duration(milliseconds: 30),
      );
      final runtimeFacade = _FakeCacheRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(
            id: 'browser_source',
            capabilities: const <String>{'novel', 'browser'},
          ),
        ],
      );
      final service = ChapterCacheService(
        database: database,
        contentService: contentService,
        sourceRuntimeFacade: runtimeFacade,
        maxConcurrentLoads: 6,
      );

      final chapters = List<Chapter>.generate(
        4,
        (index) => Chapter(
          id: 'b$index',
          bookId: 'book_browser',
          title: '第${index + 1}章',
          chapterUrl: 'https://browser.example.com/$index',
          index: index,
        ),
      );

      await service
          .cacheRange(
            bookId: 'book_browser',
            sourceId: 'browser_source',
            chapters: chapters,
            startIndex: 0,
            endIndex: 3,
          )
          .drain<void>();

      expect(contentService.maxConcurrentLoads, 1);
      await database.close();
    });
  });
}

class _RecordingChapterContentService extends ChapterContentService {
  _RecordingChapterContentService({required this.delay})
    : super(
        database: AppDatabase(executor: NativeDatabase.memory()),
        sourceRuntimeFacade: null,
        sourceHealthService: SourceHealthService(),
        taskGateService: SourceRuntimeTaskGateService(maxBudgetCap: 1),
      );

  final Duration delay;
  int _runningLoads = 0;
  int maxConcurrentLoads = 0;

  @override
  Future<ChapterContentResult> load({
    required String sourceId,
    required String chapterUrl,
    String? bookId,
    String? bookTitle,
    String? detailUrl,
    int? chapterIndex,
    String? chapterTitle,
    String? nextChapterUrl,
  }) async {
    _runningLoads += 1;
    if (_runningLoads > maxConcurrentLoads) {
      maxConcurrentLoads = _runningLoads;
    }
    try {
      await Future<void>.delayed(delay);
      return ChapterContentResult(content: 'cached', fromCache: false);
    } finally {
      _runningLoads -= 1;
    }
  }
}

class _FakeCacheRuntimeFacade extends SourceRuntimeFacade {
  _FakeCacheRuntimeFacade({required this.sources})
    : super(scriptSourceRepository: _NoopScriptSourceRepository());

  final List<RegisteredSource> sources;

  @override
  RegisteredSource? registeredScriptSourceById(String sourceId) {
    for (final source in sources) {
      if (source.runtime.id == sourceId) {
        return source;
      }
    }
    return null;
  }
}

RegisteredSource _buildRegisteredSource({
  required String id,
  Set<String> capabilities = const <String>{'novel'},
}) {
  return RegisteredSource(
    runtime: SourceRuntimeInfo(
      id: id,
      name: id,
      group: '测试',
      revision: 'test',
    ),
    definition: RuntimeSourceDefinition(
      manifest: SourceManifest(
        name: id,
        group: '测试',
        author: 'tester',
        description: '',
        capabilities: capabilities,
      ),
      search: (_, __) async => const <runtime_models.Book>[],
      detail: (_, book) async => book,
      chapters: (_, __) async => const <runtime_models.Chapter>[],
      content:
          (_, __, ___) async =>
              const runtime_models.Content(title: '', content: ''),
    ),
  );
}

class _NoopScriptSourceRepository implements ScriptSourceRepository {
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
