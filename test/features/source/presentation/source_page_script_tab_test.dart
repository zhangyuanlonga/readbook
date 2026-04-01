import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_appread/data/repositories/script_source_repository_impl.dart';
import 'package:flutter_appread/features/source/application/script_source_runtime_service.dart';
import 'package:flutter_appread/features/source/application/source_runtime_facade.dart';
import 'package:flutter_appread/features/source/presentation/source_page.dart';
import 'package:flutter_appread/runtime/sources/source_script_template.dart';
import 'package:flutter_appread/runtime/sources/source_contract.dart';
import 'package:flutter_appread/runtime/sources/source_manifest.dart';
import 'package:flutter_appread/runtime/sources/source_registry.dart';
import 'package:flutter_appread/runtime/sources/source_result_models.dart'
    as runtime_models;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourcePage script tab', () {
    late AppDatabase database;
    late ScriptSourceRepositoryImpl scriptRepository;
    late SourceRuntimeFacade facade;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      scriptRepository = ScriptSourceRepositoryImpl(database);
      facade = SourceRuntimeFacade(
        scriptSourceRepository: scriptRepository,
        scriptRuntimeService: _FakeScriptSourceRuntimeService(),
      );
    });

    tearDown(() async {
      await database.close();
    });

    testWidgets('shows saved script source in script tab', (tester) async {
      await facade.saveScriptSource(sourceCode: sourceScriptTemplateV1);

      await tester.pumpWidget(
        MaterialApp(
          home: SourcePage(
            sourceRuntimeFacade: facade,
            bootstrapOnInit: false,
            enableRouterNavigation: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('临时脚本源'), findsOneWidget);

      final items = await scriptRepository.getAll();
      expect(items, hasLength(1));
      expect(items.first.name, '临时脚本源');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
    });
  });
}

class _FakeScriptSourceRuntimeService extends ScriptSourceRuntimeService {
  @override
  Future<RegisteredSource> compileAndRegister({
    required String sourceCode,
    String? runtimeId,
    String revision = 'scratch',
  }) async {
    final definition = RuntimeSourceDefinition(
      manifest: const SourceManifest(
        name: '临时脚本源',
        group: '调试',
        author: 'you',
        description: '直接在调试器里粘贴的书源脚本。',
      ),
      search: _noopRuntimeSearch,
      detail: _noopRuntimeDetail,
      chapters: _noopRuntimeChapters,
      content: _noopRuntimeContent,
    );

    final normalizedRuntimeId = runtimeId?.trim() ?? '';
    if (normalizedRuntimeId.isEmpty) {
      return registry.register(definition, revision: revision);
    }
    return registry.upsert(normalizedRuntimeId, definition, revision: revision);
  }
}

Future<List<runtime_models.Book>> _noopRuntimeSearch(
  SourceRuntimeContext _,
  String __,
) async => const <runtime_models.Book>[];

Future<runtime_models.Book> _noopRuntimeDetail(
  SourceRuntimeContext _,
  runtime_models.Book book,
) async => book;

Future<List<runtime_models.Chapter>> _noopRuntimeChapters(
  SourceRuntimeContext _,
  runtime_models.Book __,
) async => const <runtime_models.Chapter>[];

Future<runtime_models.Content> _noopRuntimeContent(
  SourceRuntimeContext _,
  runtime_models.Book __,
  runtime_models.Chapter chapter,
) async => runtime_models.Content(title: chapter.title, content: '');
