import 'package:flutter_appread/core/rule_engine/rule_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleEngine', () {
    final engine = RuleEngine();

    test('executes html rule', () {
      const html = '<div class="book">A</div><div class="book">B</div>';
      final values = engine.executeAll(
        content: html,
        expression: 'html:.book@text',
      );

      expect(values, ['A', 'B']);
    });

    test('executes regex rule', () {
      const text = 'id=100\nid=200';
      final values = engine.executeAll(
        content: text,
        expression: r'regex:id=(\d+)::group=1::flags=m',
      );

      expect(values, ['100', '200']);
    });

    test('executes json path rule', () {
      const content = '{"booklist":[{"title":"凡人修仙传"},{"title":"诛仙"}] }';
      final values = engine.executeAll(
        content: content,
        expression: r'json:$.booklist[*].title',
      );

      expect(values, ['凡人修仙传', '诛仙']);
    });

    test('expands json array node into pipeline items', () {
      const content = '{"rows":[{"serialName":"第一章"},{"serialName":"第二章"}]}';
      final listValues = engine.executeAll(
        content: content,
        expression: r'json:$.rows',
      );
      final pipedValues = engine.executeAll(
        content: content,
        expression: 'json:\$.rows\n\$.serialName',
      );

      expect(listValues, ['{"serialName":"第一章"}', '{"serialName":"第二章"}']);
      expect(pipedValues, ['第一章', '第二章']);
    });

    test('executes json pipeline with inline js and template', () {
      const content = '{"bid":"465030"}';
      final values = engine.executeAll(
        content: content,
        expression:
            'json:\$.bid\n<js>1100000000+parseInt(result)</js>\nhttps://example.com/book?bookid={{result}}',
      );

      expect(values, ['https://example.com/book?bookid=1100465030']);
    });

    test('executes json template placeholders with baseUrl match', () {
      const content =
          '{"serialID":7,"baseUrl":"https://example.com/detail?bookId=1100465030"}';
      final values = engine.executeAll(
        content: content,
        expression:
            'json:\$\nhttps://example.com/content?bookId={{baseUrl.match(/bookId=(\\d+)/)[1]}}&chapter={{\$.serialID}}',
      );

      expect(values, [
        'https://example.com/content?bookId=1100465030&chapter=7',
      ]);
    });

    test('executeFirst returns first value', () {
      const text = 'id=100 id=200';
      final value = engine.executeFirst(
        content: text,
        expression: r'regex:id=(\d+)::group=1',
      );

      expect(value, '100');
    });
  });
}
