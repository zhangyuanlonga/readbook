import 'dart:io';

import 'package:flutter_appread/core/result/result.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/features/source/application/source_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Baseline source fixtures', () {
    final service = SourceImportService();

    test('read.json and test_read.json keep core rule compatibility', () async {
      final fixtureFiles = [File('read.json'), File('test_read.json')];

      final importedSources = <SourceDefinition>[];

      for (final file in fixtureFiles) {
        expect(await file.exists(), isTrue, reason: '${file.path} 不存在');

        final result = await service.previewFromFilePath(file.path);
        expect(result, isA<Success<SourceImportPreviewReport>>());

        final report = (result as Success<SourceImportPreviewReport>).data;
        expect(report.totalCount, greaterThan(0));
        expect(report.validCount, greaterThan(0));

        importedSources.addAll(report.validSources);
      }

      final hasSearch = importedSources.any(
        (source) =>
            _isNotEmpty(source.rules.searchRule) &&
            _isNotEmpty(source.rules.searchListRule) &&
            _isNotEmpty(source.rules.searchTitleRule) &&
            _isNotEmpty(source.rules.searchDetailUrlRule),
      );

      final hasDetail = importedSources.any(
        (source) =>
            _isNotEmpty(source.rules.detailRule) ||
            _isNotEmpty(source.rules.detailTitleRule) ||
            _isNotEmpty(source.rules.detailTocUrlRule),
      );

      final hasToc = importedSources.any(
        (source) =>
            _isNotEmpty(source.rules.tocListRule) &&
            _isNotEmpty(source.rules.tocTitleRule) &&
            _isNotEmpty(source.rules.tocChapterUrlRule),
      );

      final hasContent = importedSources.any(
        (source) => _isNotEmpty(source.rules.contentRule),
      );

      expect(hasSearch, isTrue, reason: '基线未覆盖搜索规则链路');
      expect(hasDetail, isTrue, reason: '基线未覆盖详情规则链路');
      expect(hasToc, isTrue, reason: '基线未覆盖目录规则链路');
      expect(hasContent, isTrue, reason: '基线未覆盖正文规则链路');
    });
  });
}

bool _isNotEmpty(String? value) {
  return value != null && value.trim().isNotEmpty;
}
