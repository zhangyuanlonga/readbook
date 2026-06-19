import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/book/presentation/book_detail_hero_tags.dart';

void main() {
  const resolver = BookDetailHeroTagResolver();

  test('detail hero tags use explicit route tags when present', () {
    expect(
      resolver.cover(
        explicitHeroTag: ' cover:route ',
        bookId: 'book_1',
        sourceId: 'source_a',
        detailUrl: 'https://example.test/detail/1',
      ),
      'cover:route',
    );
    expect(
      resolver.title(
        explicitHeroTag: ' title:route ',
        bookId: 'book_1',
        sourceId: 'source_a',
        detailUrl: 'https://example.test/detail/1',
      ),
      'title:route',
    );
    expect(
      resolver.meta(
        explicitHeroTag: ' meta:route ',
        bookId: 'book_1',
        sourceId: 'source_a',
        detailUrl: 'https://example.test/detail/1',
      ),
      'meta:route',
    );
  });

  test('detail hero tags fall back to stable source book and url identity', () {
    const bookId = ' book_1 ';
    const sourceId = ' source_a ';
    const detailUrl = 'https://example.test/detail/1';

    expect(
      resolver.cover(
        explicitHeroTag: ' ',
        bookId: bookId,
        sourceId: sourceId,
        detailUrl: detailUrl,
      ),
      'book_cover_source_a_book_1_${detailUrl.hashCode}',
    );
    expect(
      resolver.title(
        explicitHeroTag: null,
        bookId: bookId,
        sourceId: sourceId,
        detailUrl: detailUrl,
      ),
      'book_title_source_a_book_1_${detailUrl.hashCode}',
    );
    expect(
      resolver.meta(
        explicitHeroTag: null,
        bookId: bookId,
        sourceId: sourceId,
        detailUrl: detailUrl,
      ),
      'book_meta_source_a_book_1_${detailUrl.hashCode}',
    );
    expect(
      resolver.readerCover(
        bookId: bookId,
        sourceId: sourceId,
        detailUrl: detailUrl,
      ),
      'reader_cover_source_a_book_1_${detailUrl.hashCode}',
    );
  });

  test('derived cover tags keep loading and editor suffix conventions', () {
    expect(resolver.loadingCover(' book_1 '), 'book_loading_book_1');
    expect(
      resolver.desktopEditorCover(' book_cover_source_a_book_1_123 '),
      'book_cover_source_a_book_1_123_desktop_editor',
    );
  });
}
