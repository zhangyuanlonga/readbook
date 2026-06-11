import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/mine/application/book_source_import_payload.dart';

void main() {
  group('BookSourceImportPayload', () {
    test('parses metadata and preview from source JSON', () {
      final payload = BookSourceImportPayload.fromJsonText('''
{
  "bookSourceName": "测试书源",
  "bookSourceComment": "用于导入验证",
  "bookSourceGroup": "私有,备用",
  "bookSourceUrl": "https://example.com"
}
''');

      expect(payload.suggestedName, '测试书源');
      expect(payload.suggestedDescription, '用于导入验证');
      expect(payload.suggestedGroupName, '私有');
      expect(payload.previewText, contains('"bookSourceName"'));
      expect(payload.lineCount, 6);
      expect(payload.sizeBytes, greaterThan(0));
    });

    test('uses the first map item when source JSON is a list', () {
      final payload = BookSourceImportPayload.fromJsonText('''
[
  {
    "name": "列表书源",
    "group": ["列表分组"]
  }
]
''');

      expect(payload.suggestedName, '列表书源');
      expect(payload.suggestedGroupName, '列表分组');
    });

    test('limits preview lines for large JSON text', () {
      final lines = <String>[
        '{',
        ...List<String>.generate(120, (index) => '"k$index": $index,'),
        '"last": true',
        '}',
      ].join('\n');

      final preview = buildBookSourcePreview(lines, lineLimit: 10);

      expect(preview.split('\n'), hasLength(11));
      expect(preview, contains('已省略'));
    });

    test('throws format exception for invalid JSON', () {
      expect(
        () => BookSourceImportPayload.fromJsonText('{ broken'),
        throwsA(isA<FormatException>()),
      );
    });

    test('formats byte sizes for UI status', () {
      expect(formatBookSourceSize(512), '512 B');
      expect(formatBookSourceSize(1536), '1.5 KB');
      expect(formatBookSourceSize(2 * 1024 * 1024), '2.0 MB');
    });
  });
}
