import 'package:flutter_appread/features/reader/application/reader_chapter_cache_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderChapterCacheDecoder', () {
    const decoder = ReaderChapterCacheDecoder();

    test('returns plain text payload when no image prefix', () {
      final decoded = decoder.decode('  正文内容  ');

      expect(decoded.content, '正文内容');
      expect(decoded.imageUrls, isEmpty);
      expect(decoded.imageHeaders, isEmpty);
    });

    test('decodes image url list payload', () {
      final payload =
          '${ReaderChapterCacheDecoder.defaultImagePayloadPrefix}'
          '[" https://a.com/1.jpg ", "", "https://a.com/2.jpg"]';
      final decoded = decoder.decode(payload);

      expect(decoded.content, isEmpty);
      expect(
        decoded.imageUrls,
        equals(<String>['https://a.com/1.jpg', 'https://a.com/2.jpg']),
      );
    });

    test('decodes image payload map and trims headers', () {
      final payload =
          '${ReaderChapterCacheDecoder.defaultImagePayloadPrefix}'
          '{"imageUrls":["https://a.com/1.jpg"],'
          '"imageHeaders":{" Referer ":" https://ref.example ","Empty":" "}}';
      final decoded = decoder.decode(payload);

      expect(decoded.content, isEmpty);
      expect(decoded.imageUrls, equals(<String>['https://a.com/1.jpg']));
      expect(
        decoded.imageHeaders,
        equals(<String, String>{'Referer': 'https://ref.example'}),
      );
    });

    test('falls back to raw payload for malformed prefixed payload', () {
      final payload =
          '${ReaderChapterCacheDecoder.defaultImagePayloadPrefix}{bad json';
      final decoded = decoder.decode(payload);

      expect(decoded.content, payload);
      expect(decoded.imageUrls, isEmpty);
    });
  });
}
