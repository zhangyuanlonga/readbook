import 'package:flutter_appread/core/rule_engine/executors/js_executor.dart';
import 'package:flutter_appread/core/rule_engine/rule_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleEngine', () {
    final engine = RuleEngine();

    test('executes html rule', () async {
      const html = '<div class="book">A</div><div class="book">B</div>';
      final values = await engine.executeAll(
        content: html,
        expression: 'html:.book@text',
      );

      expect(values, ['A', 'B']);
    });

    test('executes native xpath rule with axis and function', () async {
      const html = '''
        <ul>
          <li class="chapter">第一章</li>
          <li class="chapter vip">第二章</li>
          <li class="chapter">第三章</li>
        </ul>
      ''';
      final values = await engine.executeAll(
        content: html,
        expression:
            'xpath://li[contains(@class,"vip")]/following-sibling::li[1]@text',
      );

      expect(values, ['第三章']);
    });

    test(
      'falls back to legacy xpath compatibility when native result is empty',
      () async {
        const html = '<div class="item"><span>命中内容</span></div>';
        final values = await engine.executeAll(
          content: html,
          expression: 'xpath://div[@class="item"]/text()',
        );

        expect(values, ['命中内容']);
      },
    );

    test('executes regex rule', () async {
      const text = 'id=100\nid=200';
      final values = await engine.executeAll(
        content: text,
        expression: r'regex:id=(\d+)::group=1::flags=m',
      );

      expect(values, ['100', '200']);
    });

    test('executes json path rule', () async {
      const content = '{"booklist":[{"title":"凡人修仙传"},{"title":"诛仙"}] }';
      final values = await engine.executeAll(
        content: content,
        expression: r'json:$.booklist[*].title',
      );

      expect(values, ['凡人修仙传', '诛仙']);
    });

    test('expands json array node into pipeline items', () async {
      const content = '{"rows":[{"serialName":"第一章"},{"serialName":"第二章"}]}';
      final listValues = await engine.executeAll(
        content: content,
        expression: r'json:$.rows',
      );
      final pipedValues = await engine.executeAll(
        content: content,
        expression: 'json:\$.rows\n\$.serialName',
      );

      expect(listValues, ['{"serialName":"第一章"}', '{"serialName":"第二章"}']);
      expect(pipedValues, ['第一章', '第二章']);
    });

    test('executes json pipeline with inline js and template', () async {
      const content = '{"bid":"465030"}';
      final values = await engine.executeAll(
        content: content,
        expression:
            'json:\$.bid\n<js>1100000000+parseInt(result)</js>\nhttps://example.com/book?bookid={{result}}',
      );

      expect(values, ['https://example.com/book?bookid=1100465030']);
    });

    test('executes json template placeholders with baseUrl match', () async {
      const content =
          '{"serialID":7,"baseUrl":"https://example.com/detail?bookId=1100465030"}';
      final values = await engine.executeAll(
        content: content,
        expression:
            'json:\$\nhttps://example.com/content?bookId={{baseUrl.match(/bookId=(\\d+)/)[1]}}&chapter={{\$.serialID}}',
      );

      expect(values, [
        'https://example.com/content?bookId=1100465030&chapter=7',
      ]);
    });

    test('executeFirst returns first value', () async {
      const text = 'id=100 id=200';
      final value = await engine.executeFirst(
        content: text,
        expression: r'regex:id=(\d+)::group=1',
      );

      expect(value, '100');
    });

    test('executes standalone js rule', () async {
      const text = 'abc';
      final value = await engine.executeFirst(
        content: text,
        expression: "@js:result.replace('a','b')",
      );

      expect(value, 'bbc');
    });

    test('executes preceding rule then js marker', () async {
      const html = '<div class="name">  Hello  </div>';
      final value = await engine.executeFirst(
        content: html,
        expression: 'html:.name@text@js:result.trim()',
      );

      expect(value, 'Hello');
    });

    test('executes inline <js> pipeline for non-json expression', () async {
      const html = '<div class="name">hello</div>';
      final values = await engine.executeAll(
        content: html,
        expression:
            "html:.name@text<js>result.replace('h','H')</js>regex:(Hello)::group=1",
      );

      expect(values, ['Hello']);
    });

    test('supports %% interleave operator for multi-list output', () async {
      const html = '''
        <ul class="a"><li>A1</li><li>A2</li><li>A3</li></ul>
        <ul class="b"><li>B1</li><li>B2</li></ul>
      ''';
      final values = await engine.executeAll(
        content: html,
        expression: 'html:.a li@text%%html:.b li@text',
      );

      expect(values, ['A1', 'B1', 'A2', 'B2', 'A3']);
    });

    test('supports && merge and || fallback precedence', () async {
      const html = '<div class="a">A</div><div class="b">B</div>';

      final merged = await engine.executeAll(
        content: html,
        expression: 'html:.a@text&&html:.b@text||html:.c@text',
      );
      final fallback = await engine.executeAll(
        content: html,
        expression: 'html:.x@text&&html:.y@text||html:.b@text',
      );

      expect(merged, ['A', 'B']);
      expect(fallback, ['B']);
    });

    test(r'supports all-in-one regex and $n group reference', () async {
      const text = 'title=凡人;url=/book/1;';
      final chunks = await engine.executeAll(
        content: text,
        expression: r':title=(.*?);url=(.*?);',
      );
      final title = await engine.executeFirst(
        content: chunks.first,
        expression: r'$1',
      );
      final url = await engine.executeFirst(
        content: chunks.first,
        expression: r'$2',
      );

      expect(chunks, hasLength(1));
      expect(title, '凡人');
      expect(url, '/book/1');
    });

    test('supports + all-in-one regex prefix', () async {
      const text = 'item=1 item=2';
      final chunks = await engine.executeAll(
        content: text,
        expression: r'+item=(\d+)',
      );
      final value = await engine.executeFirst(
        content: chunks.first,
        expression: r'$1',
      );

      expect(chunks, hasLength(2));
      expect(value, '1');
    });

    test('resolves nested {{@@}} template rules', () async {
      const html = '''
        <div class="title">凡人修仙传</div>
        <div class="author">忘语</div>
      ''';
      final value = await engine.executeFirst(
        content: html,
        expression: '书名:{{@@.title@text}} 作者:{{@@.author@text}}',
      );

      expect(value, '书名:凡人修仙传 作者:忘语');
    });

    test('resolves nested {{@json:}} template rules', () async {
      const json = '{"book":{"id":"1001","name":"凡人修仙传"}}';
      final value = await engine.executeFirst(
        content: json,
        expression: r'book={{@json:$.book.id}}',
      );

      expect(value, 'book=1001');
    });

    test('injects book/chapter/source into js context', () async {
      final value = await engine.executeFirst(
        content: 'ignored',
        expression:
            "@js:[book.name, chapter.url, source.bookSourceUrl].join('|')",
        jsContext: const JsExecutionContext(
          bookJson: {'name': '凡人修仙传'},
          chapterJson: {'url': 'https://example.com/chapter/1'},
          sourceJson: {'bookSourceUrl': 'https://example.com'},
        ),
      );

      expect(value, '凡人修仙传|https://example.com/chapter/1|https://example.com');
    });
  });
}
