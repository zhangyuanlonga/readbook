import 'package:flutter_appread/core/rule_engine/processors/legacy_script_rule_fallback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LegacyScriptRuleFallback', () {
    test('detects script-only rules', () {
      expect(
        LegacyScriptRuleFallback.isScriptOnlyRule('@js:"/book/1"'),
        isTrue,
      );
      expect(
        LegacyScriptRuleFallback.isScriptOnlyRule('<js>[{"name":"A"}]</js>'),
        isTrue,
      );
      expect(LegacyScriptRuleFallback.isScriptOnlyRule('.item@html'), isFalse);
    });

    test('evaluates list chunks from js literal list', () {
      final chunks = LegacyScriptRuleFallback.evaluateListChunks(
        content: 'ignored',
        rawRule: '@js:[{"name":"凡人修仙传","bookId":"123"}]',
      );

      expect(chunks, hasLength(1));
      expect(chunks.first, contains('凡人修仙传'));
      expect(chunks.first, contains('123'));
    });

    test('evaluates field value with json placeholders', () {
      final value = LegacyScriptRuleFallback.evaluateFieldValue(
        content: '{"bookId":"123"}',
        rawRule: '@js:"/book/{{\$.bookId}}"',
      );

      expect(value, '/book/123');
    });

    test('evaluates match and parseInt based url assembly', () {
      final value = LegacyScriptRuleFallback.evaluateFieldValue(
        content: '/book/12345.html',
        rawRule: r'''
@js:
var id = result.match(/(\d+).html\/?$/)[1];
var iid = parseInt(id/1000);
'https://www.00shu.la/'+iid+'/'+id+'/';
''',
      );

      expect(value, 'https://www.00shu.la/12/12345/');
    });

    test('evaluates split and concat expressions', () {
      final value = LegacyScriptRuleFallback.evaluateFieldValue(
        content: '/album/9988/track',
        rawRule:
            '@js:"https://api.example.com/item/" + result.split("/")[2] + "/detail"',
      );

      expect(value, 'https://api.example.com/item/9988/detail');
    });

    test('evaluates JSON.parse(result) field path', () {
      final value = LegacyScriptRuleFallback.evaluateFieldValue(
        content: '{"data":{"url":"/chapter/9"}}',
        rawRule: '@js:JSON.parse(result).data.url',
      );

      expect(value, '/chapter/9');
    });
  });
}
