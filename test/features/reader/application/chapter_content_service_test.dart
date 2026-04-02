import 'package:drift/native.dart';
import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/core/errors/error_codes.dart';
import 'package:flutter_appread/core/errors/error_stage.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_appread/domain/entities/script_source.dart';
import 'package:flutter_appread/domain/repositories/script_source_repository.dart';
import 'package:flutter_appread/features/reader/application/chapter_content_service.dart';
import 'package:flutter_appread/features/source/application/source_runtime_facade.dart';
import 'package:flutter_appread/runtime/sources/source_contract.dart';
import 'package:flutter_appread/runtime/sources/source_manifest.dart';
import 'package:flutter_appread/runtime/sources/source_registry.dart';
import 'package:flutter_appread/runtime/sources/source_result_models.dart'
    as runtime_models;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChapterContentService', () {
    test('loads text content from runtime and caches it', () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      final service = ChapterContentService(
        database: database,
        sourceRuntimeFacade: _FakeRuntimeFacade(
          sources: <RegisteredSource>[
            _buildRegisteredSource(id: 'source_1', name: '脚本源'),
          ],
          contentsBySourceId: <String, runtime_models.Content>{
            'source_1': const runtime_models.Content(
              title: '章节标题',
              content: ' 正文内容 ',
            ),
          },
        ),
      );

      final first = await service.load(
        sourceId: 'source_1',
        chapterUrl: 'https://example.com/ch1',
        bookId: 'book_1',
        chapterIndex: 0,
        chapterTitle: '第一章',
      );
      expect(first.content, '正文内容');
      expect(first.fromCache, isFalse);
      expect(first.displayChapterTitle, '章节标题');
      expect(first.document.isPureImageDocument, isFalse);
      expect(first.document.paragraphs, <String>['正文内容']);

      final second = await service.load(
        sourceId: 'source_1',
        chapterUrl: 'https://example.com/ch1',
        bookId: 'book_1',
        chapterIndex: 0,
        chapterTitle: '第一章',
      );
      expect(second.content, '正文内容');
      expect(second.fromCache, isTrue);
    });

    test(
      'loads image content from runtime and restores it from cache',
      () async {
        final database = AppDatabase(executor: NativeDatabase.memory());
        addTearDown(database.close);

        final service = ChapterContentService(
          database: database,
          sourceRuntimeFacade: _FakeRuntimeFacade(
            sources: <RegisteredSource>[
              _buildRegisteredSource(id: 'source_2', name: '脚本源B'),
            ],
            contentsBySourceId: <String, runtime_models.Content>{
              'source_2': const runtime_models.Content(
                title: '图片章节',
                content: '',
                images: <String>[
                  'https://example.com/1.jpg',
                  'https://example.com/2.jpg',
                ],
              ),
            },
          ),
        );

        final first = await service.load(
          sourceId: 'source_2',
          chapterUrl: 'https://example.com/ch2',
          bookId: 'book_2',
          chapterIndex: 1,
          chapterTitle: '第二章',
        );
        expect(first.isImageContent, isTrue);
        expect(first.imageUrls, hasLength(2));
        expect(first.fromCache, isFalse);
        expect(first.content, isEmpty);
        expect(first.document.isPureImageDocument, isTrue);

        final second = await service.load(
          sourceId: 'source_2',
          chapterUrl: 'https://example.com/ch2',
          bookId: 'book_2',
          chapterIndex: 1,
          chapterTitle: '第二章',
        );
        expect(second.isImageContent, isTrue);
        expect(second.imageUrls, hasLength(2));
        expect(second.fromCache, isTrue);
        expect(second.document.isPureImageDocument, isTrue);
      },
    );

    test('throws unknown source when runtime source is missing', () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);

      final service = ChapterContentService(
        database: database,
        sourceRuntimeFacade: _FakeRuntimeFacade(
          sources: const <RegisteredSource>[],
        ),
      );

      await expectLater(
        service.load(sourceId: 'missing', chapterUrl: 'https://example.com/ch'),
        throwsA(
          isA<AppException>()
              .having((error) => error.code, 'code', ErrorCode.unknownSource)
              .having((error) => error.stage, 'stage', ErrorStage.content),
        ),
      );
    });
  });
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
    this.contentsBySourceId = const <String, runtime_models.Content>{},
  }) : super(scriptSourceRepository: _FakeScriptSourceRepository());

  final List<RegisteredSource> sources;
  final Map<String, runtime_models.Content> contentsBySourceId;

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
  Future<runtime_models.Content> content({
    required String sourceId,
    required runtime_models.Book book,
    required runtime_models.Chapter chapter,
  }) async {
    return contentsBySourceId[sourceId] ??
        const runtime_models.Content(title: '', content: '');
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
