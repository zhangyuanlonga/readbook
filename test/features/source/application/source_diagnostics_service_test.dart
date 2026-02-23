import 'dart:io';

import 'package:flutter_appread/core/errors/error_codes.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/domain/repositories/source_repository.dart';
import 'package:flutter_appread/features/search/application/search_service.dart';
import 'package:flutter_appread/features/source/application/source_diagnostics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceDiagnosticsService', () {
    test(
      'short-circuits dynamic js search rule before network in searchOnly mode',
      () async {
        final source = SourceDefinition(
          id: 'dynamic_precheck_1',
          name: '动态预检源',
          baseUrl: 'https://example.com',
          rules: const SourceRuleSet(
            searchRule: '''
@js:
java.put("key",key)
eval(String(source.bookSourceComment))
''',
            searchListRule: '.item@html',
            searchTitleRule: '.name@text',
            searchDetailUrlRule: '.name@href',
          ),
        );

        final repository = _FakeSourceRepository([source]);
        final service = SourceDiagnosticsService(
          sourceRepository: repository,
          searchService: SearchService(sourceRepository: repository),
        );

        final report = await service.diagnoseSource(
          source: source,
          keyword: '凡人修仙传',
          mode: SourceDiagnosticMode.searchOnly,
        );

        expect(report.isSuccess, isFalse);
        expect(report.stages, hasLength(1));
        expect(report.stages.first.stage, SourceDiagnosticStage.search);
        expect(report.stages.first.code, ErrorCode.validation);
        expect(report.stages.first.message, contains('动态 JS 脚本'));
      },
    );

    test(
      'short-circuits missing toc rules before network in fullChain mode',
      () async {
        final source = SourceDefinition(
          id: 'toc_precheck_1',
          name: '目录缺失预检源',
          baseUrl: 'https://example.com',
          rules: const SourceRuleSet(
            searchRule: '/search?key={{key}}',
            searchListRule: '.item@html',
            searchTitleRule: '.name@text',
            searchDetailUrlRule: '.name@href',
          ),
        );

        final repository = _FakeSourceRepository([source]);
        final service = SourceDiagnosticsService(
          sourceRepository: repository,
          searchService: SearchService(sourceRepository: repository),
        );

        final report = await service.diagnoseSource(
          source: source,
          keyword: '凡人修仙传',
          mode: SourceDiagnosticMode.fullChainQuick,
        );

        expect(report.isSuccess, isFalse);
        expect(report.stages, hasLength(1));
        expect(report.stages.first.stage, SourceDiagnosticStage.toc);
        expect(report.stages.first.code, ErrorCode.validation);
        expect(report.stages.first.message, contains('缺少目录规则'));
      },
    );

    test('uses manga content mode when diagnosing manga source', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write('''
            <div class="item">
              <a class="name" href="/book/manga-1">漫画测试书</a>
            </div>
          ''');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final source = SourceDefinition(
        id: 'manga_source_1',
        name: '漫画测试源',
        baseUrl: baseUrl,
        sourceType: 2,
        rules: const SourceRuleSet(
          searchRule: '/search?keyword={{key}}',
          searchListRule: '.item@html',
          searchTitleRule: '.name@text',
          searchDetailUrlRule: '.name@href',
        ),
      );

      final repository = _FakeSourceRepository([source]);
      final service = SourceDiagnosticsService(
        sourceRepository: repository,
        searchService: SearchService(sourceRepository: repository),
      );

      final report = await service.diagnoseSource(
        source: source,
        keyword: '漫画测试书',
        mode: SourceDiagnosticMode.searchOnly,
      );

      expect(report.isSuccess, isTrue);
      expect(report.stages, hasLength(1));
      expect(report.stages.first.success, isTrue);
      expect(report.stages.first.stage, SourceDiagnosticStage.search);
    });
  });
}

class _FakeSourceRepository implements SourceRepository {
  _FakeSourceRepository(this.sources);

  final List<SourceDefinition> sources;

  @override
  Future<void> clear() async {
    sources.clear();
  }

  @override
  Future<void> deleteById(String sourceId) async {
    sources.removeWhere((source) => source.id == sourceId);
  }

  @override
  Future<void> deleteByIds(List<String> sourceIds) async {
    final idSet = sourceIds.toSet();
    sources.removeWhere((source) => idSet.contains(source.id));
  }

  @override
  Future<List<SourceDefinition>> getAll() async {
    return List.unmodifiable(sources);
  }

  @override
  Future<void> setEnabled({
    required String sourceId,
    required bool enabled,
  }) async {
    final index = sources.indexWhere((source) => source.id == sourceId);
    if (index < 0) {
      return;
    }
    final current = sources[index];
    sources[index] = current.copyWith(enabled: enabled);
  }

  @override
  Future<void> upsertAll(List<SourceDefinition> incoming) async {
    for (final source in incoming) {
      final index = sources.indexWhere((item) => item.id == source.id);
      if (index >= 0) {
        sources[index] = source;
      } else {
        sources.add(source);
      }
    }
  }

  @override
  Stream<List<SourceDefinition>> watchAll() {
    return Stream.value(List.unmodifiable(sources));
  }
}
