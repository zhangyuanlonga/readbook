import 'package:flutter_appread/features/reader/application/content_text_cleaner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContentTextCleaner', () {
    const cleaner = ContentTextCleaner();

    test('removes scripts and common ad lines', () {
      const raw = '''
      <div class="content">
        <script>alert('x')</script>
        <p>第一段内容。</p>
        <p>最新网址：www.example.com</p>
        <p>第二段内容。</p>
      </div>
      ''';

      final cleaned = cleaner.clean(raw);

      expect(cleaned, contains('第一段内容。'));
      expect(cleaned, contains('第二段内容。'));
      expect(cleaned, isNot(contains('alert')));
      expect(cleaned, isNot(contains('最新网址')));
    });

    test('normalizes escaped line breaks from json content', () {
      const raw = '第一段\\r\\n\\r\\n第二段\\n第三段';

      final cleaned = cleaner.clean(raw);

      expect(cleaned, contains('第一段'));
      expect(cleaned, contains('第二段'));
      expect(cleaned, contains('第三段'));
      expect(cleaned, isNot(contains(r'\\r\\n')));
    });

    test('filters zero-width and replacement characters', () {
      const raw = '一\uFEFF二\u200B三\uFFFD四';

      final cleaned = cleaner.clean(raw);

      expect(cleaned, '一二三四');
    });

    test('keeps html paragraph semantics', () {
      const raw = '<p>第一段</p><p>第二段</p>';

      final cleaned = cleaner.clean(raw);

      expect(cleaned, '第一段\n\n第二段');
    });

    test('merges short lines into paragraphs when no explicit breaks', () {
      const raw = '第一句。\n第二句。\n第三句。';

      final cleaned = cleaner.clean(raw);

      expect(cleaned, '第一句。第二句。第三句。');
    });

    test('returns empty when source has no readable text', () {
      const raw = '<div><script>123</script></div>';
      expect(cleaner.clean(raw), isEmpty);
    });
  });
}
