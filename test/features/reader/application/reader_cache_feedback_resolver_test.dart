import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_cache_feedback_resolver.dart';

void main() {
  group('ReaderCacheFeedbackResolver', () {
    const resolver = ReaderCacheFeedbackResolver();

    test('returns local-specific unsupported copy', () {
      expect(
        resolver.unsupportedMessage(isLocalContent: true),
        '本地图书暂不支持章节缓存。',
      );
      expect(
        resolver.unsupportedSubtitle(isLocalContent: true),
        '本地图书不提供章节缓存。',
      );
    });

    test('returns source-specific unsupported copy', () {
      expect(
        resolver.unsupportedMessage(isLocalContent: false),
        '当前内容暂不支持章节缓存。',
      );
      expect(
        resolver.unsupportedSubtitle(isLocalContent: false),
        '当前来源暂不支持章节缓存。',
      );
    });

    test('uses shared missing catalog copy', () {
      expect(resolver.missingCatalogMessage(), '当前目录没有可缓存的正文章节。');
    });
  });
}
