import 'package:shuxiang_reading_next/domain/entities/search_request_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchRequestContext', () {
    test('uses defaults and trims keyword', () {
      final context = SearchRequestContext(keyword: '  三国演义  ');

      expect(context.keyword, '三国演义');
      expect(context.page, 1);
      expect(context.pageSize, 20);
      expect(context.sourceId, isNull);
      expect(context.extraParams, isEmpty);
    });

    test('maps variables for template replacement', () {
      final context = SearchRequestContext(
        keyword: '凡人修仙传',
        page: 3,
        pageSize: 50,
        sourceId: 'source-a',
        extraParams: const {'author': '忘语'},
      );

      expect(context.toVariables(), {
        'key': '凡人修仙传',
        'keyword': '凡人修仙传',
        'page': '3',
        'pageSize': '50',
        'author': '忘语',
        'sourceId': 'source-a',
      });
    });

    test('supports toJson and fromJson roundtrip', () {
      final context = SearchRequestContext(
        keyword: '诛仙',
        page: 2,
        pageSize: 30,
        sourceId: 'source-b',
        extraParams: const {'cat': 'xuanhuan'},
      );

      final restored = SearchRequestContext.fromJson(context.toJson());

      expect(restored.keyword, context.keyword);
      expect(restored.page, context.page);
      expect(restored.pageSize, context.pageSize);
      expect(restored.sourceId, context.sourceId);
      expect(restored.extraParams, context.extraParams);
    });

    test('validates invalid keyword and page values', () {
      expect(
        () => SearchRequestContext(keyword: '   '),
        throwsFormatException,
      );

      expect(
        () => SearchRequestContext(keyword: 'abc', page: 0),
        throwsFormatException,
      );

      expect(
        () => SearchRequestContext(keyword: 'abc', pageSize: 0),
        throwsFormatException,
      );
    });
  });
}
