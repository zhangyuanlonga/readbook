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

    test('parses and normalizes books from html content', () async {
      final books = await parser.parse(
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

    test('deduplicates by sourceId + detailUrl', () async {
      const duplicatedHtml = '''
      <div class="result-item"><a class="title" href="/book/1001">凡人修仙传</a></div>
      <div class="result-item"><a class="title" href="/book/1001">凡人修仙传（重复）</a></div>
      ''';

      final books = await parser.parse(
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

    test('supports reversed list chunks from parse rules', () async {
      final books = await parser.parse(
        htmlContent: html,
        sourceId: 'source-a',
        baseUrl: 'https://example.com/root/',
        rules: const SearchParseRules(
          listRule: 'html:.result-item@html',
          listReversed: true,
          titleRule: 'html:.title@text',
          detailUrlRule: 'html:.title@attr(href)',
        ),
      );

      expect(books, hasLength(2));
      expect(books.first.title, '诛仙');
      expect(books.last.title, '凡人修仙传');
    });

    test('allows invalid baseUrl when result links are absolute', () async {
      const absoluteHtml = '''
      <div class="result-item">
        <a class="title" href="https://book.example.com/book/1">剑来</a>
        <img class="cover" src="https://img.example.com/1.jpg" />
      </div>
      <div class="result-item">
        <a class="title" href="/book/2">相对地址应跳过</a>
      </div>
      ''';

      final books = await parser.parse(
        htmlContent: absoluteHtml,
        sourceId: 'source-a',
        baseUrl: 'bbnnfgh',
        rules: const SearchParseRules(
          listRule: 'html:.result-item@html',
          titleRule: 'html:.title@text',
          detailUrlRule: 'html:.title@attr(href)',
          coverUrlRule: 'html:.cover@attr(src)',
        ),
      );

      expect(books, hasLength(1));
      expect(books.first.title, '剑来');
      expect(books.first.detailUrl, 'https://book.example.com/book/1');
      expect(books.first.coverUrl, 'https://img.example.com/1.jpg');
    });

    test('falls back between json/html/regex rules when one fails', () async {
      const jsonContent = '{"items":[{"title":"凡人修仙传","url":"/book/1001"}]}';

      final books = await parser.parse(
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

    test(r'supports all-in-one regex list with $n group fields', () async {
      const content = 'title=凡人修仙传,url=/book/1;title=诛仙,url=/book/2;';

      final books = await parser.parse(
        htmlContent: content,
        sourceId: 'source-a',
        baseUrl: 'https://example.com',
        rules: const SearchParseRules(
          listRule: r':title=(.*?),url=(.*?);',
          titleRule: r'$1',
          detailUrlRule: r'$2',
        ),
      );

      expect(books, hasLength(2));
      expect(books.first.title, '凡人修仙传');
      expect(books.first.detailUrl, 'https://example.com/book/1');
      expect(books.last.title, '诛仙');
      expect(books.last.detailUrl, 'https://example.com/book/2');
    });

    test('throws when no valid search result exists', () async {
      await expectLater(
        parser.parse(
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
