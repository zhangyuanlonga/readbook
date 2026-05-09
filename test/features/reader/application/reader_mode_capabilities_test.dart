import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/content_provider.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_mode_capabilities.dart';

void main() {
  group('ReaderModeCapabilitiesResolver', () {
    const resolver = ReaderModeCapabilitiesResolver();

    test('text mode keeps paged text capability for inline images', () {
      const capabilities = ContentCapabilities(
        canSwitchSource: true,
        canCacheChapter: true,
        canSearchInSource: true,
      );

      final normal = resolver.resolve(
        contentMode: ReaderContentMode.text,
        contentCapabilities: capabilities,
        hasInlineImageParagraphs: false,
      );
      final withInlineImage = resolver.resolve(
        contentMode: ReaderContentMode.text,
        contentCapabilities: capabilities,
        hasInlineImageParagraphs: true,
      );

      expect(normal.canAutoRead, isTrue);
      expect(normal.canUsePagedText, isTrue);
      expect(normal.supportsCatalogContentSearch, isTrue);
      expect(
        normal.primaryBottomAction,
        ReaderPrimaryBottomAction.interfacePanel,
      );
      expect(normal.canSwitchSource, isTrue);
      expect(normal.canCacheChapter, isTrue);

      expect(withInlineImage.canUsePagedText, isTrue);
      expect(withInlineImage.supportsCatalogContentSearch, isTrue);
    });

    test(
      'comic mode disables text-only interactions but keeps provider actions',
      () {
        const capabilities = ContentCapabilities(
          canSwitchSource: true,
          canCacheChapter: true,
        );

        final resolved = resolver.resolve(
          contentMode: ReaderContentMode.comic,
          contentCapabilities: capabilities,
          hasInlineImageParagraphs: false,
        );

        expect(resolved.canAutoRead, isFalse);
        expect(resolved.canUsePagedText, isFalse);
        expect(resolved.supportsCatalogContentSearch, isFalse);
        expect(
          resolved.primaryBottomAction,
          ReaderPrimaryBottomAction.positionPanel,
        );
        expect(resolved.canSwitchSource, isTrue);
        expect(resolved.canCacheChapter, isTrue);
      },
    );
  });
}
