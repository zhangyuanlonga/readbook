import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/book_identity.dart';

void main() {
  group('BookIdentity', () {
    test('builds legacy logical id for remote books from detail url', () {
      final identity = BookIdentity.remote(
        sourceId: 'source_a',
        detailUrl: 'https://example.com/book/1',
        fallbackTitle: '测试书',
      );

      expect(
        identity.logicalBookId,
        'source_a:${Uri.encodeComponent('https://example.com/book/1')}',
      );
      expect(
        identity.sourceBookKey.storageKey,
        'source_a::detail:${Uri.encodeComponent('https://example.com/book/1')}',
      );
    });

    test('falls back to title when remote detail url is empty', () {
      final identity = BookIdentity.remote(
        sourceId: 'source_a',
        detailUrl: '',
        fallbackTitle: '测试书',
      );

      expect(identity.logicalBookId, 'source_a:${Uri.encodeComponent('测试书')}');
      expect(
        identity.sourceBookKey.storageKey,
        'source_a::title:${Uri.encodeComponent('测试书')}',
      );
    });

    test('builds local identity with stable local detail url', () {
      final identity = BookIdentity.local(logicalBookId: 'local_1');

      expect(identity.logicalBookId, 'local_1');
      expect(
        identity.sourceBookKey.storageKey,
        '${BookIdentityScheme.localSourceId}::detail:${Uri.encodeComponent('local://book/local_1')}',
      );
    });
  });

  group('local book identity helpers', () {
    test('build and parse local urls consistently', () {
      expect(buildLocalBookDetailUrl('book_1'), 'local://book/book_1');
      expect(buildLocalChapterUrl('chapter_1'), 'local://chapter/chapter_1');
      expect(parseLocalBookIdFromDetailUrl('local://book/book_1'), 'book_1');
      expect(
        parseLocalChapterIdFromChapterUrl('local://chapter/chapter_1'),
        'chapter_1',
      );
      expect(isLocalBookSourceId(BookIdentityScheme.localSourceId), isTrue);
      expect(isLocalSchemeUrl('local://book/book_1'), isTrue);
    });
  });
}
