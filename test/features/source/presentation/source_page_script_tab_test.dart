import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/mobile_features/mobile_feature_service.dart';
import 'package:shuxiang_reading_next/domain/entities/source_health.dart';
import 'package:shuxiang_reading_next/domain/entities/script_source.dart';
import 'package:shuxiang_reading_next/domain/repositories/script_source_repository.dart';
import 'package:shuxiang_reading_next/features/source/application/source_check_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_page_access_service.dart';
import 'package:shuxiang_reading_next/features/source/application/script_source_runtime_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_facade.dart';
import 'package:shuxiang_reading_next/features/source/presentation/source_page.dart';
import 'package:shuxiang_reading_next/features/source/providers.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_script_template.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_contract.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_manifest.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_registry.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_result_models.dart'
    as runtime_models;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SourcePage script tab', () {
    late _FakeScriptSourceRepository scriptRepository;
    late SourceRuntimeFacade facade;
    late SourceHealthService sourceHealthService;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      scriptRepository = _FakeScriptSourceRepository();
      sourceHealthService = SourceHealthService();
      facade = SourceRuntimeFacade(
        scriptSourceRepository: scriptRepository,
        scriptRuntimeService: _FakeScriptSourceRuntimeService(),
        sourceHealthService: sourceHealthService,
      );
    });

    tearDown(() async {
      await scriptRepository.dispose();
    });

    testWidgets('shows saved script source in script tab', (tester) async {
      await facade.saveScriptSource(sourceCode: sourceScriptTemplateV1);

      await tester.pumpWidget(_buildApp(facade, sourceHealthService));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('还没有书源').evaluate().isNotEmpty ||
            find.text('临时书享源').evaluate().isNotEmpty,
        isTrue,
      );
      expect(find.text('临时书享源'), findsOneWidget);

      final items = await scriptRepository.getAll();
      expect(items, hasLength(1));
      expect(items.first.name, '临时书享源');
      expect(items.first.primaryHost, 'debug.local');
      expect(items.first.registrableDomain, 'debug.local');
      expect(items.first.clusterKey, 'debug.local');
      await tester.pump(const Duration(milliseconds: 350));
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
          lastAutoDisableReason: '连续失败次数过高，已自动停用。',
          cooldownUntil: DateTime.now().add(const Duration(minutes: 3)),
        ),
      );

      await tester.pumpWidget(_buildApp(facade, sourceHealthService));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.textContaining('失败: browser challenge failed'),
        findsOneWidget,
      );
      expect(find.textContaining('自动停用:'), findsOneWidget);
      expect(find.textContaining('冷却中'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 350));
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

      await tester.pumpWidget(_buildApp(facade, sourceHealthService));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('建议检测'), findsWidgets);
      expect(find.text('建议停用'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 350));
    });

    testWidgets('supports selecting source for batch check scope', (
      tester,
    ) async {
      await facade.saveScriptSource(sourceCode: sourceScriptTemplateV1);

      await tester.pumpWidget(_buildApp(facade, sourceHealthService));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.longPress(find.text('临时书享源'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('已选：1'), findsOneWidget);
      expect(find.text('清空选中'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 350));
    });

    testWidgets('shows duplicate website source hints in single list', (
      tester,
    ) async {
      await facade.saveScriptSource(sourceCode: sourceScriptTemplateV1);
      await facade.saveScriptSource(
        sourceCode: sourceScriptTemplateV1,
        id: 'source_duplicate',
      );

      await tester.pumpWidget(_buildApp(facade, sourceHealthService));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('同站 2 个'), findsWidgets);
      await tester.pump(const Duration(milliseconds: 350));
    });

    testWidgets('filters duplicate sources from group menu', (tester) async {
      await facade.saveScriptSource(sourceCode: sourceScriptTemplateV1);
      await facade.saveScriptSource(
        sourceCode: sourceScriptTemplateV1,
        id: 'source_duplicate',
      );
      await facade.saveScriptSource(
        sourceCode: '''
export default {
  meta: {
    name: '单独站点源',
    group: '调试',
    author: 'you',
    description: '',
    homepage: 'https://solo.example.com',
    domains: ['solo.example.com'],
    capabilities: ['search', 'detail', 'chapters', 'content'],
  },
  async search(ctx, keyword) { return []; },
  async detail(ctx, book) { return book; },
  async chapters(ctx, book) { return []; },
  async content(ctx, book, chapter) { return { title: chapter.title || '', content: '' }; },
};
''',
        id: 'source_solo',
      );

      await tester.pumpWidget(_buildApp(facade, sourceHealthService));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byTooltip('分组'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重复源').last);
      await tester.pumpAndSettle();

      expect(find.text('单独站点源'), findsNothing);
      await tester.pump(const Duration(milliseconds: 350));
    });

  });
}

Widget _buildApp(
  SourceRuntimeFacade facade,
  SourceHealthService sourceHealthService,
) {
  return ProviderScope(
    overrides: [
      sourcePageAccessServiceProvider.overrideWithValue(
        _FakeSourcePageAccessService(),
      ),
    ],
    child: MaterialApp(
      home: SourcePage(
        sourceRuntimeFacade: facade,
        sourceCheckService: SourceCheckService(
          sourceRuntimeFacade: facade,
          sourceHealthService: sourceHealthService,
        ),
        sourceHealthService: sourceHealthService,
        bootstrapOnInit: true,
        enableRouterNavigation: false,
      ),
    ),
  );
}

class _FakeSourcePageAccessService extends SourcePageAccessService {
  _FakeSourcePageAccessService()
    : super(
        authSessionStore: AuthSessionStore(),
        mobileFeatureService: MobileFeatureService(baseUrl: 'https://example.com'),
      );

  @override
  Future<SourcePageFeatureAccess> loadFeatureAccess({
    bool refreshRemote = true,
  }) async {
    return const SourcePageFeatureAccess(
      canAccessSourcePage: true,
      sourceImportLimit: 10,
    );
  }
}

class _FakeScriptSourceRuntimeService extends ScriptSourceRuntimeService {
  @override
  Future<RegisteredSource> compileAndRegister({
    required String sourceCode,
    String? runtimeId,
    String revision = 'scratch',
  }) async {
    String extractField(String field) {
      final pattern = RegExp("$field\\s*:\\s*['\\\"]([^'\\\"]+)['\\\"]");
      return pattern.firstMatch(sourceCode)?.group(1)?.trim() ?? '';
    }

    List<String> extractDomains() {
      final match = RegExp(r"domains\s*:\s*\[([^\]]*)\]").firstMatch(sourceCode);
      final block = match?.group(1) ?? '';
      return RegExp("['\"]([^'\"]+)['\"]")
          .allMatches(block)
          .map((item) => item.group(1)!.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    final name = extractField('name');
    final group = extractField('group');
    final author = extractField('author');
    final description = extractField('description');
    final homepage = extractField('homepage');
    final checkKeyword = extractField('checkKeyword');
    final domains = extractDomains();

    final definition = RuntimeSourceDefinition(
      manifest: SourceManifest(
        name: name.isEmpty ? '临时脚本源' : name,
        group: group.isEmpty ? '调试' : group,
        author: author.isEmpty ? 'you' : author,
        description: description.isEmpty ? '直接在调试器里粘贴的书源脚本。' : description,
        checkKeyword: checkKeyword.isEmpty ? null : checkKeyword,
        domains: domains.isEmpty ? const <String>['debug.local'] : domains,
        homepage: homepage.isEmpty ? 'https://debug.local' : homepage,
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

class _FakeScriptSourceRepository implements ScriptSourceRepository {
  final List<ScriptSource> _sources = <ScriptSource>[];
  final StreamController<List<ScriptSource>> _controller =
      StreamController<List<ScriptSource>>.broadcast();

  Future<void> dispose() async {
    await _controller.close();
  }

  @override
  Future<void> clear() async {
    _sources.clear();
    _emit();
  }

  @override
  Future<void> deleteById(String id) async {
    _sources.removeWhere((item) => item.id == id);
    _emit();
  }

  @override
  Future<List<ScriptSource>> getAll() async =>
      List<ScriptSource>.unmodifiable(_sources);

  @override
  Future<ScriptSource?> getById(String id) async {
    for (final source in _sources) {
      if (source.id == id) {
        return source;
      }
    }
    return null;
  }

  @override
  Future<void> setEnabled({required String id, required bool enabled}) async {
    final index = _sources.indexWhere((item) => item.id == id);
    if (index < 0) {
      return;
    }
    _sources[index] = _sources[index].copyWith(
      enabled: enabled,
      updatedAt: DateTime.now(),
    );
    _emit();
  }

  @override
  Future<void> upsert(ScriptSource source) async {
    final index = _sources.indexWhere((item) => item.id == source.id);
    if (index >= 0) {
      _sources[index] = source;
    } else {
      _sources.add(source);
    }
    _emit();
  }

  @override
  Stream<List<ScriptSource>> watchAll() async* {
    yield List<ScriptSource>.unmodifiable(_sources);
    yield* _controller.stream;
  }

  void _emit() {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(List<ScriptSource>.unmodifiable(_sources));
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
