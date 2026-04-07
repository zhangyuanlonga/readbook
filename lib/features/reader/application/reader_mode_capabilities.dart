import 'content_provider.dart';
import 'reader_content_session.dart';

enum ReaderPrimaryBottomAction { interfacePanel, positionPanel }

class ReaderModeCapabilities {
  const ReaderModeCapabilities({
    required this.canAutoRead,
    required this.canUsePagedText,
    required this.supportsCatalogContentSearch,
    required this.primaryBottomAction,
    required this.canSwitchSource,
    required this.canCacheChapter,
    required this.interfaceSettingsTitle,
    required this.readingSettingsTitle,
  });

  final bool canAutoRead;
  final bool canUsePagedText;
  final bool supportsCatalogContentSearch;
  final ReaderPrimaryBottomAction primaryBottomAction;
  final bool canSwitchSource;
  final bool canCacheChapter;
  final String interfaceSettingsTitle;
  final String readingSettingsTitle;
}

class ReaderModeCapabilitiesResolver {
  const ReaderModeCapabilitiesResolver();

  ReaderModeCapabilities resolve({
    required ReaderContentMode contentMode,
    required ContentCapabilities contentCapabilities,
    required bool hasInlineImageParagraphs,
  }) {
    switch (contentMode) {
      case ReaderContentMode.text:
        return ReaderModeCapabilities(
          canAutoRead: true,
          canUsePagedText: !hasInlineImageParagraphs,
          supportsCatalogContentSearch: true,
          primaryBottomAction: ReaderPrimaryBottomAction.interfacePanel,
          canSwitchSource: contentCapabilities.canSwitchSource,
          canCacheChapter: contentCapabilities.canCacheChapter,
          interfaceSettingsTitle: '界面',
          readingSettingsTitle: '设置',
        );
      case ReaderContentMode.comic:
        return ReaderModeCapabilities(
          canAutoRead: false,
          canUsePagedText: false,
          supportsCatalogContentSearch: false,
          primaryBottomAction: ReaderPrimaryBottomAction.positionPanel,
          canSwitchSource: contentCapabilities.canSwitchSource,
          canCacheChapter: contentCapabilities.canCacheChapter,
          interfaceSettingsTitle: '漫画界面',
          readingSettingsTitle: '漫画设置',
        );
      case ReaderContentMode.audio:
        return ReaderModeCapabilities(
          canAutoRead: false,
          canUsePagedText: false,
          supportsCatalogContentSearch: false,
          primaryBottomAction: ReaderPrimaryBottomAction.interfacePanel,
          canSwitchSource: contentCapabilities.canSwitchSource,
          canCacheChapter: contentCapabilities.canCacheChapter,
          interfaceSettingsTitle: '听书界面',
          readingSettingsTitle: '听书设置',
        );
    }
  }
}
