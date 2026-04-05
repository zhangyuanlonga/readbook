import 'dart:convert';
import 'dart:io';

import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/features/search/application/search_failure_export_service.dart';
import 'package:shuxiang_reading_next/features/search/application/search_service.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_contract.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_manifest.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_registry.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_result_models.dart'
    as runtime_models;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchFailureExportService', () {
    test('exports runtime source payload with error detail', () async {
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

      final source = RegisteredSource(
        runtime: const SourceRuntimeInfo(
          id: 'src_1',
          name: '测试源',
          group: '默认分组',
          revision: 'script-1',
        ),
        definition: RuntimeSourceDefinition(
          manifest: const SourceManifest(
            name: '测试源',
            group: '默认分组',
            author: 'tester',
            description: 'desc',
            homepage: 'https://example.com',
            domains: <String>['example.com'],
          ),
          search: (_, __) async => const <runtime_models.Book>[],
          detail: (_, book) async => book,
          chapters: (_, __) async => const <runtime_models.Chapter>[],
          content:
              (_, __, ___) async =>
                  const runtime_models.Content(title: '', content: ''),
        ),
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
        sources: <RegisteredSource>[source],
        contentMode: SearchContentMode.novel,
      );

      expect(result.failureCount, 1);
      expect(result.missingSourceCount, 0);
      expect(result.filePath, contains(tempDir.path));
      expect(File(result.filePath).existsSync(), isTrue);

      final payload = jsonDecode(File(result.filePath).readAsStringSync());
      expect(payload['schema'], 'shuxiang_reading_next.search_failures.v3');
      expect(payload['keyword'], '剑来');
      expect(payload['contentMode'], 'novel');
      expect(payload['summary']['failedSourceCount'], 1);
      expect(payload['failures'], isA<List>());

      final item =
          (payload['failures'] as List).first as Map<String, dynamic>;
      expect(item['sourceId'], 'src_1');
      expect(item['sourceFound'], isTrue);
      expect(item['source']['name'], '测试源');
      expect(item['source']['manifest']['homepage'], 'https://example.com');
      expect(item['source']['manifest']['domains'], contains('example.com'));
      expect(item['error']['debugMessage'], 'FormatException: invalid selector');
    });

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
          sources: const <RegisteredSource>[],
          contentMode: SearchContentMode.novel,
        );

        expect(result.filePath, startsWith(fallbackDir.path));
        expect(File(result.filePath).existsSync(), isTrue);
      },
    );

    test('writes to preferred file path when provided', () async {
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

      final targetFilePath =
          '${tempDir.path}${Platform.pathSeparator}custom_output${Platform.pathSeparator}failed_sources';

      final report = SearchExecutionReport(
        keyword: '凡人',
        sourceCount: 1,
        successSourceCount: 0,
        books: const [],
        failures: const [
          SourceSearchFailure(
            sourceId: 'src_1',
            sourceName: '测试源',
            message: '搜索阶段：未知错误',
            code: ErrorCode.unknown,
            stage: ErrorStage.search,
          ),
        ],
        sourceNames: const {'src_1': '测试源'},
      );

      final result = await service.exportFailedSources(
        report: report,
        sources: const <RegisteredSource>[],
        contentMode: SearchContentMode.novel,
        preferredFilePath: targetFilePath,
      );

      expect(result.filePath, '$targetFilePath.json');
      expect(File(result.filePath).existsSync(), isTrue);
    });

    test('tracks missing source records when source no longer exists', () async {
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
        sources: const <RegisteredSource>[],
        contentMode: SearchContentMode.novel,
      );

      expect(result.failureCount, 1);
      expect(result.missingSourceCount, 1);

      final payload = jsonDecode(File(result.filePath).readAsStringSync());
      final item =
          (payload['failures'] as List).first as Map<String, dynamic>;
      expect(item['sourceFound'], isFalse);
      expect(item['source'], isNull);
    });

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

      await expectLater(
        () => service.exportFailedSources(
          report: report,
          sources: const <RegisteredSource>[],
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
