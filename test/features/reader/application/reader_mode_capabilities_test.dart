import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/content_provider.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_mode_capabilities.dart';

void main() {
  group('ReaderModeCapabilitiesResolver', () {
    const resolver = ReaderModeCapabilitiesResolver();
    const capabilities = ContentCapabilities(
      canSwitchSource: true,
      canCacheChapter: true,
    );

    test('keeps text auto read and search enabled', () {
      final resolved = resolver.resolve(
        contentMode: ReaderContentMode.text,
        contentCapabilities: capabilities,
        hasInlineImageParagraphs: true,
      );

      expect(resolved.canAutoRead, isTrue);
      expect(resolved.supportsCatalogContentSearch, isTrue);
      expect(
        resolved.primaryBottomAction,
        ReaderPrimaryBottomAction.interfacePanel,
      );
    });

    test('disables auto read and search for hybrid mode', () {
      final resolved = resolver.resolve(
        contentMode: ReaderContentMode.hybrid,
        contentCapabilities: capabilities,
        hasInlineImageParagraphs: false,
      );

      expect(resolved.canAutoRead, isFalse);
      expect(resolved.supportsCatalogContentSearch, isFalse);
      expect(
        resolved.primaryBottomAction,
        ReaderPrimaryBottomAction.positionPanel,
      );
      expect(resolved.interfaceSettingsTitle, '版式界面');
    });
  });
}
