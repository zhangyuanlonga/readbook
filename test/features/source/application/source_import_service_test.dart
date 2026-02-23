import 'dart:convert';
import 'dart:io';

import 'package:charset/charset.dart';
import 'package:flutter_appread/core/result/result.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/features/source/application/source_capability_analyzer.dart';
import 'package:flutter_appread/features/source/application/source_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceImportService', () {
    final service = SourceImportService();

    test('imports single object json', () {
      const jsonText =
          '{"bookSourceName":"源A","bookSourceUrl":"https://a.com","searchUrl":"/search?key={{key}}"}';

      final result = service.importFromText(jsonText);

      expect(result, isA<Success<List<SourceDefinition>>>());
      final data = (result as Success<List<SourceDefinition>>).data;
      expect(data, hasLength(1));
      expect(data.first.name, '源A');
      expect(data.first.baseUrl, 'https://a.com');
    });

    test('imports list json', () {
      const jsonText =
          '[{"bookSourceName":"源A","bookSourceUrl":"https://a.com","searchUrl":"/search?key={{key}}"},'
          '{"bookSourceName":"源B","bookSourceUrl":"https://b.com","searchUrl":"/search?key={{key}}"}]';

      final result = service.importFromText(jsonText);

      expect(result, isA<Success<List<SourceDefinition>>>());
      final data = (result as Success<List<SourceDefinition>>).data;
      expect(data.map((e) => e.name), ['源A', '源B']);
    });

    test('captures sourceType from imported payload', () {
      const jsonText =
          '{"bookSourceName":"漫画源","bookSourceUrl":"https://comic.example.com","bookSourceType":2,"searchUrl":"/search?key={{key}}"}';

      final result = service.importFromText(jsonText);

      expect(result, isA<Success<List<SourceDefinition>>>());
      final data = (result as Success<List<SourceDefinition>>).data;
      expect(data, hasLength(1));
      expect(data.first.sourceType, 2);
      expect(data.first.isMangaSource, isTrue);
    });

    test('does not report compatibility hints for js-free manga source', () {
      const payload = '''
[
  {
    "bookSourceName": "漫画源",
    "bookSourceUrl": "https://comic.example.com",
    "bookSourceType": 2,
    "searchUrl": "/search?key={{key}}",
    "ruleContent": {"content": ".manga img@src", "imageStyle": "FULL"}
  }
]
''';

      final result = service.previewFromText(payload);

      expect(result, isA<Success<SourceImportPreviewReport>>());
      final report = (result as Success<SourceImportPreviewReport>).data;
      expect(report.validCount, 1);
      expect(report.compatibilityHintCount, 0);
    });

    test('reports compatibility hints for js reload manga source', () {
      final file = File('manhua.json');
      final payload =
          file.existsSync()
              ? file.readAsStringSync()
              : jsonEncode([
                {
                  'bookSourceName': '漫画源',
                  'bookSourceUrl': 'https://comic.example.com',
                  'bookSourceType': 2,
                  'searchUrl': '<js>Reload("https://example.com")</js>',
                  'ruleContent': {
                    'content': '<js>result</js>',
                    'imageStyle': 'FULL',
                  },
                },
              ]);

      final result = service.previewFromText(payload);

      expect(result, isA<Success<SourceImportPreviewReport>>());
      final report = (result as Success<SourceImportPreviewReport>).data;
      expect(report.validCount, greaterThanOrEqualTo(1));
      expect(report.compatibilityHintCount, greaterThan(0));
      final hint = report.compatibilityHints.first;
      expect(hint.level, SourceCompatibilityLevel.unsupported);
      expect(
        hint.reasons.any(
          (item) => item.contains('Reload') || item.contains('漫画'),
        ),
        isTrue,
      );
    });

    test('returns failure on invalid json', () {
      final result = service.importFromText('{invalid json}');
      expect(result, isA<Failure<List<SourceDefinition>>>());
    });

    test('preview collects valid and invalid entries', () {
      const jsonText = '''
[
  {"bookSourceName":"源A","bookSourceUrl":"https://a.com","searchUrl":"/search?key={{key}}"},
  {"bookSourceName":"","bookSourceUrl":"https://b.com","searchUrl":"/search?key={{key}}"},
  "bad-entry"
]
''';

      final result = service.previewFromText(jsonText);

      expect(result, isA<Success<SourceImportPreviewReport>>());
      final report = (result as Success<SourceImportPreviewReport>).data;
      expect(report.totalCount, 3);
      expect(report.validCount, 1);
      expect(report.invalidCount, 2);
      expect(report.issues.first.line, isNotNull);
      expect(report.issues.last.message, contains('JSON 对象'));
    });

    test(
      'preview in background isolate returns mixed validation result',
      () async {
        const jsonText = '''
[
  {"bookSourceName":"源A","bookSourceUrl":"https://a.com","searchUrl":"/search?key={{key}}"},
  {"bookSourceName":"","bookSourceUrl":"https://b.com","searchUrl":"/search?key={{key}}"}
]
''';

        final result = await service.previewFromTextInBackground(jsonText);

        expect(result, isA<Success<SourceImportPreviewReport>>());
        final report = (result as Success<SourceImportPreviewReport>).data;
        expect(report.totalCount, 2);
        expect(report.validCount, 1);
        expect(report.invalidCount, 1);
      },
    );

    test('preview keeps validation for incomplete source', () {
      const jsonText =
          '{"bookSourceName":"源A","bookSourceUrl":"https://a.com"}';

      final result = service.previewFromText(jsonText);

      expect(result, isA<Success<SourceImportPreviewReport>>());
      final report = (result as Success<SourceImportPreviewReport>).data;
      expect(report.validCount, 0);
      expect(report.invalidCount, 1);
      expect(report.compatibilityHintCount, 0);
    });

    test('background preview keeps validation for incomplete source', () async {
      const jsonText =
          '{"bookSourceName":"源A","bookSourceUrl":"https://a.com"}';

      final result = await service.previewFromTextInBackground(jsonText);

      expect(result, isA<Success<SourceImportPreviewReport>>());
      final report = (result as Success<SourceImportPreviewReport>).data;
      expect(report.validCount, 0);
      expect(report.invalidCount, 1);
      expect(report.compatibilityHintCount, 0);
    });

    test('decodes gbk source bytes for legacy json files', () {
      final gbk = Charset.getByName('gbk');
      expect(gbk, isNotNull);

      final bytes = gbk!.encode('{"bookSourceName":"晴天小说"}');
      final text = service.decodeSourceBytes(bytes);

      expect(text, contains('晴天小说'));
    });

    test('imports from file path', () async {
      final directory = await Directory.systemTemp.createTemp(
        'appread_import_',
      );
      final file = File('${directory.path}/source.json');
      await file.writeAsString(
        '{"bookSourceName":"文件源","bookSourceUrl":"https://file.com","searchUrl":"/search?key={{key}}"}',
      );

      final result = await service.importFromFilePath(file.path);

      expect(result, isA<Success<List<SourceDefinition>>>());
      final data = (result as Success<List<SourceDefinition>>).data;
      expect(data.first.name, '文件源');

      await directory.delete(recursive: true);
    });
  });
}
