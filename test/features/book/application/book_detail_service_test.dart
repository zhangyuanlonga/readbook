import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/core/logging/app_logger.dart';
import 'package:shuxiang_reading_next/domain/entities/script_source.dart';
import 'package:shuxiang_reading_next/domain/repositories/script_source_repository.dart';
import 'package:shuxiang_reading_next/features/book/application/book_detail_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_diagnostic_execution_container.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_facade.dart';
import 'package:shuxiang_reading_next/runtime/session/source_session.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_contract.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_manifest.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_registry.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_result_models.dart'
    as runtime_models;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookDetailService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('loads detail and chapters from runtime facade', () async {
      final healthService = SourceHealthService();
      final logger = _RecordingLogger();
      final runtimeFacade = _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 'source_1', name: '脚本源'),
        ],
        detailedBooksBySourceId: <String, runtime_models.Book>{
          'source_1': const runtime_models.Book(
            title: '测试书籍',
            author: '作者A',
            intro: '简介A',
            cover: 'https://example.com/cover.jpg',
            detailUrl: 'https://example.com/book/1',
            extra: <String, dynamic>{
              'catalogUrl': 'https://example.com/book/1/catalog',
            },
          ),
        },
        chaptersBySourceId: <String, List<runtime_models.Chapter>>{
          'source_1': const <runtime_models.Chapter>[
            runtime_models.Chapter(
              title: '第一卷',
              url: '',
              index: 0,
              isVolume: true,
            ),
            runtime_models.Chapter(
              title: '第一章',
              url: 'https://example.com/book/1/ch1',
              index: 1,
            ),
          ],
        },
      );
      final service = BookDetailService(
        sourceRuntimeFacade: runtimeFacade,
        sourceHealthService: healthService,
        logger: logger,
      );

      final result = await service.load(
        sourceId: 'source_1',
        bookId: 'book_1',
        detailUrl: 'https://example.com/book/1',
        fallbackTitle: '后备标题',
        forceRefresh: true,
      );

      expect(result.detail.title, '测试书籍');
      expect(result.detail.author, '作者A');
      expect(result.detail.tocUrl, 'https://example.com/book/1/catalog');
      expect(result.chapters, hasLength(2));
      expect(result.chapters.first.title, '第一卷');
      expect(result.chapters.first.isVolume, isTrue);
      expect(result.chapters.last.title, '第一章');
      expect(
        result.chapters.last.id,
        'book_1:${Uri.encodeComponent('https://example.com/book/1/ch1')}',
      );
      expect(result.chapters.last.isVolume, isFalse);
      expect(result.sourceName, '脚本源');
      expect(result.tocFromCache, isFalse);
      expect(result.tocError, isNull);
      final snapshot = healthService.snapshotFor('source_1');
      expect(snapshot.totalSuccesses, 2);
      expect(logger.infoLogs, contains('Runtime detail success'));
      expect(logger.infoLogs, contains('Runtime chapters success'));
    });

    test('returns cached detail snapshot on repeated load', () async {
      final service = BookDetailService(
        sourceRuntimeFacade: _FakeRuntimeFacade(
          sources: <RegisteredSource>[
            _buildRegisteredSource(id: 'source_2', name: '脚本源B'),
          ],
          detailedBooksBySourceId: <String, runtime_models.Book>{
            'source_2': const runtime_models.Book(
              title: '缓存书籍',
              author: '作者B',
              detailUrl: 'https://example.com/book/2',
            ),
          },
          chaptersBySourceId: <String, List<runtime_models.Chapter>>{
            'source_2': const <runtime_models.Chapter>[
              runtime_models.Chapter(
                title: '第二章',
                url: 'https://example.com/book/2/ch2',
                index: 1,
              ),
            ],
          },
        ),
      );

      await service.load(
        sourceId: 'source_2',
        bookId: 'book_2',
        detailUrl: 'https://example.com/book/2',
      );
      final cached = service.peekCached(
        sourceId: 'source_2',
        detailUrl: 'https://example.com/book/2',
      );

      expect(cached, isNotNull);
      expect(cached!.tocFromCache, isTrue);
      expect(cached.chapters, hasLength(1));
    });

    test('throws unknown source when runtime source is missing', () async {
      final healthService = SourceHealthService();
      final service = BookDetailService(
        sourceRuntimeFacade: _FakeRuntimeFacade(
          sources: const <RegisteredSource>[],
        ),
        sourceHealthService: healthService,
      );

      try {
        await service.load(
          sourceId: 'missing',
          bookId: 'book',
          detailUrl: 'https://example.com/book',
        );
        fail('expected AppException');
      } on AppException catch (error) {
        expect(error.code, ErrorCode.unknownSource);
        expect(error.stage, ErrorStage.detail);
        expect(error.briefMessage, contains('未找到书源'));
        final snapshot = healthService.snapshotFor('missing');
        expect(snapshot.totalFailures, 1);
        expect(snapshot.lastFailureReason, contains('未找到书源'));
      }
    });

    test('background refresh uses diagnostic container flow', () async {
      final runtimeFacade = _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 'source_refresh', name: '后台刷新源'),
        ],
        detailedBooksBySourceId: <String, runtime_models.Book>{
          'source_refresh': const runtime_models.Book(
            title: '刷新书籍',
            author: '作者R',
            detailUrl: 'https://example.com/book/r',
          ),
        },
        chaptersBySourceId: <String, List<runtime_models.Chapter>>{
          'source_refresh': const <runtime_models.Chapter>[
            runtime_models.Chapter(
              title: '第一章',
              url: 'https://example.com/book/r/1',
              index: 0,
            ),
          ],
        },
      );
      final service = BookDetailService(sourceRuntimeFacade: runtimeFacade);

      final result = await service.loadForBackgroundRefresh(
        sourceId: 'source_refresh',
        bookId: 'book_refresh',
        detailUrl: 'https://example.com/book/r',
        cancellationHandle: const SessionCancellationHandle(
          isCancelled: _alwaysFalse,
        ),
      );

      expect(result, isNotNull);
      expect(result!.detail.title, '刷新书籍');
      expect(result.chapters, hasLength(1));
      final cached = service.peekCached(
        sourceId: 'source_refresh',
        detailUrl: 'https://example.com/book/r',
      );
      expect(cached, isNotNull);
      expect(cached!.detail.title, '刷新书籍');
      expect(cached.chapters, hasLength(1));
      expect(cached.tocFromCache, isTrue);
      expect(runtimeFacade.createdDiagnosticContainerCount, 1);
      expect(runtimeFacade.disposedDiagnosticContainerCount, 1);
      expect(runtimeFacade.lastDiagnosticCancellationHandleWasSet, isFalse);
    });
  });
}

bool _alwaysFalse() => false;

class _RecordingLogger implements AppLogger {
  final List<String> infoLogs = <String>[];

  @override
  void info(String message, {Map<String, Object?> context = const {}}) {
    infoLogs.add(message);
  }

  @override
  void warn(String message, {Map<String, Object?> context = const {}}) {}

  @override
  void error(
    String message, {
    AppException? exception,
    Map<String, Object?> context = const {},
  }) {}
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

class _FakeRuntimeFacade extends SourceRuntimeFacade {
  _FakeRuntimeFacade({
    required this.sources,
    this.detailedBooksBySourceId = const <String, runtime_models.Book>{},
    this.chaptersBySourceId = const <String, List<runtime_models.Chapter>>{},
  }) : super(scriptSourceRepository: _FakeScriptSourceRepository());

  final List<RegisteredSource> sources;
  final Map<String, runtime_models.Book> detailedBooksBySourceId;
  final Map<String, List<runtime_models.Chapter>> chaptersBySourceId;
  runtime_models.Book? lastDetailBook;
  int createdDiagnosticContainerCount = 0;
  int disposedDiagnosticContainerCount = 0;
  bool lastDiagnosticCancellationHandleWasSet = false;

  @override
  RegisteredSource? registeredScriptSourceById(String sourceId) {
    for (final source in sources) {
      if (source.runtime.id == sourceId) {
        return source;
      }
    }
    return null;
  }

  @override
  Future<RegisteredSource?> ensureRegisteredScriptSourceById(
    String sourceId,
  ) async {
    return registeredScriptSourceById(sourceId);
  }

  @override
  Future<runtime_models.Book> detail({
    required String sourceId,
    required runtime_models.Book book,
  }) async {
    lastDetailBook = book;
    return detailedBooksBySourceId[sourceId] ?? book;
  }

  @override
  Future<List<runtime_models.Chapter>> chapters({
    required String sourceId,
    required runtime_models.Book book,
  }) async {
    return chaptersBySourceId[sourceId] ?? const <runtime_models.Chapter>[];
  }

  @override
  Future<SourceRuntimeDiagnosticExecutionContainer?>
  createDiagnosticExecutionContainerById(
    String sourceId, {
    SessionCancellationHandle? cancellationHandle,
  }) async {
    final registered = await ensureRegisteredScriptSourceById(sourceId);
    if (registered == null) {
      return null;
    }
    createdDiagnosticContainerCount += 1;
    lastDiagnosticCancellationHandleWasSet = cancellationHandle != null;
    return _FakeDiagnosticExecutionContainer(
      sourceId: sourceId,
      sourceName: registered.runtime.name,
      detailBook: detailedBooksBySourceId[sourceId],
      chapterList:
          chaptersBySourceId[sourceId] ?? const <runtime_models.Chapter>[],
      onDispose: () {
        disposedDiagnosticContainerCount += 1;
      },
    );
  }
}

class _FakeDiagnosticExecutionContainer
    implements SourceRuntimeDiagnosticExecutionContainer {
  const _FakeDiagnosticExecutionContainer({
    required this.sourceId,
    required this.sourceName,
    required this.detailBook,
    required this.chapterList,
    required this.onDispose,
  });

  @override
  final String sourceId;

  @override
  final String sourceName;

  final runtime_models.Book? detailBook;
  final List<runtime_models.Chapter> chapterList;
  final void Function() onDispose;

  @override
  Future<List<runtime_models.Book>> search(String keyword) async {
    return const <runtime_models.Book>[];
  }

  @override
  Future<runtime_models.Book> detail(runtime_models.Book book) async {
    return detailBook ?? book;
  }

  @override
  Future<List<runtime_models.Chapter>> chapters(
    runtime_models.Book book,
  ) async {
    return chapterList;
  }

  @override
  Future<runtime_models.Content> content(
    runtime_models.Book book,
    runtime_models.Chapter chapter,
  ) async {
    return const runtime_models.Content(title: '', content: '');
  }

  @override
  void dispose() {
    onDispose();
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
