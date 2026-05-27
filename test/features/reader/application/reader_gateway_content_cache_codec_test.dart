import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_gateway_content_cache_codec.dart';

void main() {
  group('ReaderGatewayContentCacheCodec', () {
    test('keeps plain text cache compact', () {
      final encoded = ReaderGatewayContentCacheCodec.encode(
        content: '  第一章正文  ',
      );

      expect(encoded, '第一章正文');
      expect(ReaderGatewayContentCacheCodec.decode(encoded).content, '第一章正文');
    });

    test('persists audio manifest metadata without正文', () {
      final encoded = ReaderGatewayContentCacheCodec.encode(
        content: '',
        contentType: 'audio',
        audioManifestUrl: ' https://cdn.example/chapter.m3u8 ',
        audioHeaders: const <String, String>{'Referer': ' https://a.example '},
      );

      final decoded = ReaderGatewayContentCacheCodec.decode(encoded);

      expect(encoded, startsWith(ReaderGatewayContentCacheCodec.payloadPrefix));
      expect(decoded.content, isEmpty);
      expect(decoded.contentType, 'audio');
      expect(decoded.audioManifestUrl, 'https://cdn.example/chapter.m3u8');
      expect(decoded.audioHeaders, const <String, String>{
        'Referer': 'https://a.example',
      });
      expect(decoded.hasAudioContent, isTrue);
    });

    test('reads legacy image payloads', () {
      final decoded = ReaderGatewayContentCacheCodec.decode(
        '${ReaderGatewayContentCacheCodec.legacyImagePrefix}'
        '{"imageUrls":[" https://img.example/1.jpg "],"imageHeaders":{"A":" b "}}',
      );

      expect(decoded.imageUrls, const <String>['https://img.example/1.jpg']);
      expect(decoded.imageHeaders, const <String, String>{'A': 'b'});
    });
  });
}
