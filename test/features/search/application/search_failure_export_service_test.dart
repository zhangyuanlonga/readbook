import 'dart:convert';
import 'dart:io';

import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/core/errors/error_codes.dart';
import 'package:flutter_appread/core/errors/error_stage.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/features/search/application/search_failure_export_service.dart';
import 'package:flutter_appread/features/search/application/search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchFailureExportService', () {
    test(
      'exports normalized and raw source payload with error detail',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'search-export-test',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final service = SearchFailureExportService(
          exportDirectoryResolver: () async => tempDir,
          fallbackDirectoryResolver: () async => tempDir,
          now: () => DateTime(2026, 2, 23, 9, 30, 12),
        );

        final source = SourceDefinition(
          id: 'src_1',
          name: '测试源',
          baseUrl: 'https://example.com',
          rules: const SourceRuleSet(
            searchRule: '/search?key={{key}}',
            searchListRule: '.item@html',
            searchTitleRule: '.title@text',
            searchDetailUrlRule: '.title@href',
          ),
          originalSource: const {
            'bookSourceName': '测试源',
            'bookSourceUrl': 'https://example.com',
            'searchUrl': '/search?key={{key}}',
          },
        );

        final report = SearchExecutionReport(
          keyword: '剑来',
          sourceCount: 1,
          successSourceCount: 0,
          books: const [],
          failures: const [
            SourceSearchFailure(
              sourceId: 'src_1',
              sourceName: '测试源',
              message: '搜索阶段：FormatException',
              code: ErrorCode.unknown,
              stage: ErrorStage.search,
              requestUrl: 'https://example.com/search',
              debugMessage: 'FormatException: invalid selector',
            ),
          ],
          sourceNames: const {'src_1': '测试源'},
        );

        final result = await service.exportFailedSources(
          report: report,
          sources: [source],
          contentMode: SearchContentMode.novel,
        );

        expect(result.failureCount, 1);
        expect(result.missingSourceCount, 0);
        expect(result.filePath, contains(tempDir.path));
        expect(File(result.filePath).existsSync(), isTrue);

        final payload = jsonDecode(File(result.filePath).readAsStringSync());
        expect(payload['schema'], 'flutter_appread.search_failures.v2');
        expect(payload['keyword'], '剑来');
        expect(payload['contentMode'], 'novel');
        expect(payload['summary']['failedSourceCount'], 1);
        expect(payload['failures'], isA<List>());

        final item =
            (payload['failures'] as List).first as Map<String, dynamic>;
        expect(item['sourceId'], 'src_1');
        expect(item['sourceFound'], isTrue);
        expect(item['source']['name'], '测试源');
        expect(item['sourceRaw']['bookSourceName'], '测试源');
        expect(item['sourcePayload']['bookSourceUrl'], 'https://example.com');
        expect(item['sourceRawExact'], isTrue);
        expect(
          item['error']['debugMessage'],
          'FormatException: invalid selector',
        );
      },
    );

    test(
      'falls back to app directory when preferred export path is not writable',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'search-export-test',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final blockerFile = File(
          '${tempDir.path}${Platform.pathSeparator}blocked',
        );
        await blockerFile.writeAsString('not a directory');
        final fallbackDir = Directory(
          '${tempDir.path}${Platform.pathSeparator}fallback',
        );

        final service = SearchFailureExportService(
          exportDirectoryResolver: () async => Directory(blockerFile.path),
          fallbackDirectoryResolver: () async => fallbackDir,
        );

        final report = SearchExecutionReport(
          keyword: '凡人',
          sourceCount: 1,
          successSourceCount: 0,
          books: const [],
          failures: const [
            SourceSearchFailure(
              sourceId: 'missing_src',
              sourceName: '失效源',
              message: '搜索阶段：未知错误',
              code: ErrorCode.unknown,
              stage: ErrorStage.search,
            ),
          ],
          sourceNames: const {'missing_src': '失效源'},
        );

        final result = await service.exportFailedSources(
          report: report,
          sources: const [],
          contentMode: SearchContentMode.novel,
        );

        expect(result.filePath, startsWith(fallbackDir.path));
        expect(File(result.filePath).existsSync(), isTrue);
      },
    );

    test(
      'tracks missing source records when source no longer exists',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'search-export-test',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final service = SearchFailureExportService(
          exportDirectoryResolver: () async => tempDir,
          fallbackDirectoryResolver: () async => tempDir,
        );

        final report = SearchExecutionReport(
          keyword: '凡人',
          sourceCount: 1,
          successSourceCount: 0,
          books: const [],
          failures: const [
            SourceSearchFailure(
              sourceId: 'missing_src',
              sourceName: '失效源',
              message: '搜索阶段：未知错误',
              code: ErrorCode.unknown,
              stage: ErrorStage.search,
            ),
          ],
          sourceNames: const {'missing_src': '失效源'},
        );

        final result = await service.exportFailedSources(
          report: report,
          sources: const [],
          contentMode: SearchContentMode.novel,
        );

        expect(result.failureCount, 1);
        expect(result.missingSourceCount, 1);

        final payload = jsonDecode(File(result.filePath).readAsStringSync());
        final item =
            (payload['failures'] as List).first as Map<String, dynamic>;
        expect(item['sourceFound'], isFalse);
        expect(item['source'], isNull);
        expect(item['sourceRaw'], isNull);
        expect(item['sourcePayload'], isNull);
        expect(item['sourceRawExact'], isFalse);
      },
    );

    test('throws validation error when no failures to export', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'search-export-test',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final service = SearchFailureExportService(
        exportDirectoryResolver: () async => tempDir,
        fallbackDirectoryResolver: () async => tempDir,
      );

      final report = SearchExecutionReport(
        keyword: '凡人',
        sourceCount: 1,
        successSourceCount: 1,
        books: const [],
        failures: const [],
        sourceNames: const {'src_1': '成功源'},
      );

      expect(
        () => service.exportFailedSources(
          report: report,
          sources: const [],
          contentMode: SearchContentMode.novel,
        ),
        throwsA(
          isA<AppException>()
              .having((error) => error.code, 'code', ErrorCode.validation)
              .having(
                (error) => error.briefMessage,
                'briefMessage',
                contains('没有失败书源'),
              ),
        ),
      );
    });
  });
}
