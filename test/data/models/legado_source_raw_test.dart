import 'package:flutter_appread/data/models/legado_source_raw.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LegadoSourceRaw', () {
    test('parses key fields and keeps defaults', () {
      final source = LegadoSourceRaw.fromJson({
        'bookSourceName': '测试书源',
        'bookSourceUrl': 'https://example.com',
        'bookSourceGroup': '默认分组',
        'enabled': '1',
        'searchUrl': '/search?key={{key}}',
      });

      expect(source.sourceName, '测试书源');
      expect(source.sourceUrl, 'https://example.com');
      expect(source.sourceGroup, '默认分组');
      expect(source.searchUrl, '/search?key={{key}}');
      expect(source.enabled, isTrue);
    });

    test('preserves unknown and nested raw fields', () {
      final source = LegadoSourceRaw.fromJson({
        'bookSourceName': '测试源',
        'custom': {
          'headers': {'User-Agent': 'appread'},
        },
        'weightList': [1, 2, 3],
      });

      final raw = source.toJson();
      expect(raw['custom'], isA<Map<String, dynamic>>());
      expect((raw['custom'] as Map<String, dynamic>)['headers'],
          isA<Map<String, dynamic>>());
      expect(raw['weightList'], [1, 2, 3]);
    });

    test('toJson returns a deep copy', () {
      final source = LegadoSourceRaw.fromJson({
        'bookSourceName': '测试源',
        'nested': {
          'flag': true,
        },
      });

      final exported = source.toJson();
      (exported['nested'] as Map<String, dynamic>)['flag'] = false;

      expect((source.rawData['nested'] as Map<String, dynamic>)['flag'], isTrue);
    });
  });
}
