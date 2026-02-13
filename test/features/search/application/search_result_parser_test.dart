import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/features/search/application/search_result_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchResultParser', () {
    final parser = SearchResultParser();

    const html = '''
    <div class="result-item">
      <a class="title" href="/book/1001">凡人修仙传</a>
      <span class="author">忘语</span>
      <img class="cover" src="/cover/1001.jpg" />
      <p class="intro">一个凡人的修仙故事。</p>
      <span class="latest">第1200章</span>
    </div>
    <div class="result-item">
      <a class="title" href="https://example.com/book/1002">诛仙</a>
      <span class="author">萧鼎</span>
      <p class="intro">青云之上。</p>
    </div>
    ''';

    const rules = SearchParseRules(
      listRule: 'html:.result-item@html',
      titleRule: 'html:.title@text',
      detailUrlRule: 'html:.title@attr(href)',
      authorRule: 'html:.author@text',
      introRule: 'html:.intro@text',
      coverUrlRule: 'html:.cover@attr(src)',
      latestChapterRule: 'html:.latest@text',
    );

    test('parses and normalizes books from html content', () {
      final books = parser.parse(
        htmlContent: html,
        sourceId: 'source-a',
        baseUrl: 'https://example.com/root/',
        rules: rules,
      );

      expect(books, hasLength(2));

      final first = books.firstWhere((item) => item.title == '凡人修仙传');
      expect(first.sourceId, 'source-a');
      expect(first.detailUrl, 'https://example.com/book/1001');
      expect(first.coverUrl, 'https://example.com/cover/1001.jpg');
      expect(first.author, '忘语');
      expect(first.latestChapter, '第1200章');

      final second = books.firstWhere((item) => item.title == '诛仙');
      expect(second.detailUrl, 'https://example.com/book/1002');
      expect(second.coverUrl, isNull);
    });

    test('deduplicates by sourceId + detailUrl', () {
      const duplicatedHtml = '''
      <div class="result-item"><a class="title" href="/book/1001">凡人修仙传</a></div>
      <div class="result-item"><a class="title" href="/book/1001">凡人修仙传（重复）</a></div>
      ''';

      final books = parser.parse(
        htmlContent: duplicatedHtml,
        sourceId: 'source-a',
        baseUrl: 'https://example.com',
        rules: const SearchParseRules(
          listRule: 'html:.result-item@html',
          titleRule: 'html:.title@text',
          detailUrlRule: 'html:.title@attr(href)',
        ),
      );

      expect(books, hasLength(1));
      expect(books.first.detailUrl, 'https://example.com/book/1001');
    });

    test('falls back between json/html/regex rules when one fails', () {
      const jsonContent = '{"items":[{"title":"凡人修仙传","url":"/book/1001"}]}';

      final books = parser.parse(
        htmlContent: jsonContent,
        sourceId: 'source-a',
        baseUrl: 'https://example.com',
        rules: const SearchParseRules(
          listRule: 'html:.missing@html||json:\$.items[*]',
          titleRule: 'html:.name@text||json:\$.title',
          detailUrlRule: 'regex:("url":"([^"]+)")::group=2||json:\$.url',
        ),
      );

      expect(books, hasLength(1));
      expect(books.first.title, '凡人修仙传');
      expect(books.first.detailUrl, 'https://example.com/book/1001');
    });

    test('throws when no valid search result exists', () {
      expect(
        () => parser.parse(
          htmlContent: '<div class="empty">no data</div>',
          sourceId: 'source-a',
          baseUrl: 'https://example.com',
          rules: rules,
        ),
        throwsA(isA<RuleMatchEmptyException>()),
      );
    });
  });
}
