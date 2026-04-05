import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_appread/data/repositories/script_source_repository_impl.dart';
import 'package:flutter_appread/domain/entities/source_health.dart';
import 'package:flutter_appread/features/source/application/source_health_service.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SourcePage script tab', () {
    late AppDatabase database;
    late ScriptSourceRepositoryImpl scriptRepository;
    late SourceRuntimeFacade facade;
    late SourceHealthService sourceHealthService;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      database = AppDatabase(executor: NativeDatabase.memory());
      scriptRepository = ScriptSourceRepositoryImpl(database);
      sourceHealthService = SourceHealthService();
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
            sourceHealthService: sourceHealthService,
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

      await sourceHealthService.persistNow();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('shows source health badge and failure hint', (tester) async {
      final source = await facade.saveScriptSource(
        sourceCode: sourceScriptTemplateV1,
      );
      sourceHealthService.upsert(
        SourceHealthSnapshot(
          sourceId: source.id,
          level: SourceHealthLevel.risky,
          enabled: true,
          totalFailures: 2,
          consecutiveFailures: 2,
          browserRiskCount: 2,
          lastFailureReason: 'browser challenge failed',
          cooldownUntil: DateTime.now().add(const Duration(minutes: 3)),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SourcePage(
            sourceRuntimeFacade: facade,
            sourceHealthService: sourceHealthService,
            bootstrapOnInit: false,
            enableRouterNavigation: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('不可用'), findsOneWidget);
      expect(
        find.textContaining('失败: browser challenge failed'),
        findsOneWidget,
      );
      expect(find.textContaining('冷却中'), findsOneWidget);

      await sourceHealthService.persistNow();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('shows suggested actions for risky and unavailable sources', (
      tester,
    ) async {
      final riskySource = await facade.saveScriptSource(
        sourceCode: sourceScriptTemplateV1,
      );
      final unavailableSource = await facade.saveScriptSource(
        sourceCode: sourceScriptTemplateV1,
        id: 'source_unavailable',
      );
      sourceHealthService.upsert(
        SourceHealthSnapshot(
          sourceId: riskySource.id,
          level: SourceHealthLevel.risky,
          enabled: true,
          totalFailures: 1,
          browserRiskCount: 1,
          lastFailureReason: 'browser challenge failed',
        ),
      );
      sourceHealthService.upsert(
        SourceHealthSnapshot(
          sourceId: unavailableSource.id,
          level: SourceHealthLevel.unavailable,
          enabled: true,
          totalFailures: 3,
          consecutiveFailures: 2,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SourcePage(
            sourceRuntimeFacade: facade,
            sourceHealthService: sourceHealthService,
            bootstrapOnInit: false,
            enableRouterNavigation: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('建议检测'), findsWidgets);
      expect(find.text('建议停用'), findsOneWidget);

      await sourceHealthService.persistNow();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('supports selecting source for batch check scope', (
      tester,
    ) async {
      await facade.saveScriptSource(sourceCode: sourceScriptTemplateV1);

      await tester.pumpWidget(
        MaterialApp(
          home: SourcePage(
            sourceRuntimeFacade: facade,
            sourceHealthService: sourceHealthService,
            bootstrapOnInit: false,
            enableRouterNavigation: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.longPress(find.text('临时脚本源'));
      await tester.pumpAndSettle();

      expect(find.text('已选：1'), findsOneWidget);
      expect(find.text('清空选中'), findsOneWidget);

      await sourceHealthService.persistNow();
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
