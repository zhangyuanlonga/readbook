import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_catalog_entry_controller.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_mode_capabilities.dart';

void main() {
  group('ReaderCatalogEntryController', () {
    const controller = ReaderCatalogEntryController();
    const capabilities = ReaderModeCapabilities(
      canAutoRead: true,
      canUsePagedText: true,
      supportsCatalogContentSearch: true,
      supportsCatalogNavigation: true,
      primaryBottomAction: ReaderPrimaryBottomAction.interfacePanel,
      canSwitchSource: true,
      canCacheChapter: true,
      interfaceSettingsTitle: '界面',
      readingSettingsTitle: '设置',
    );

    test('blocks unsupported catalog navigation', () {
      final decision = controller.resolveOpenDecision(
        capabilities: const ReaderModeCapabilities(
          canAutoRead: false,
          canUsePagedText: false,
          supportsCatalogContentSearch: false,
          supportsCatalogNavigation: false,
          primaryBottomAction: ReaderPrimaryBottomAction.positionPanel,
          canSwitchSource: false,
          canCacheChapter: false,
          interfaceSettingsTitle: '界面',
          readingSettingsTitle: '设置',
        ),
        hasCatalog: true,
        catalogComplete: true,
      );

      expect(decision.canOpen, isFalse);
      expect(decision.message, '当前内容暂不支持目录操作。');
    });

    test('allows lazy catalog hydration before catalog is complete', () {
      final decision = controller.resolveOpenDecision(
        capabilities: capabilities,
        hasCatalog: false,
        catalogComplete: false,
      );

      expect(decision.canOpen, isTrue);
      expect(decision.message, isNull);
    });

    test('blocks completed empty catalog', () {
      final decision = controller.resolveOpenDecision(
        capabilities: capabilities,
        hasCatalog: false,
        catalogComplete: true,
      );

      expect(decision.canOpen, isFalse);
      expect(decision.message, '当前书籍暂无目录。');
    });
  });
}
