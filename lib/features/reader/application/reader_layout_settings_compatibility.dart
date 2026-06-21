enum ReaderLayoutSettingCompatibilityStatus {
  trackedInLayoutSignature,
  shellOwned,
  platformOwned,
  visualOnly,
  pageTurnDelegateFallback,
  interactionOwned,
  surfaceOwned,
  dataOwned,
}

class ReaderLayoutSettingCompatibilityItem {
  const ReaderLayoutSettingCompatibilityItem({
    required this.key,
    required this.status,
    required this.reason,
  });

  final String key;
  final ReaderLayoutSettingCompatibilityStatus status;
  final String reason;
}

class ReaderLayoutSettingsCompatibilityMatrix {
  const ReaderLayoutSettingsCompatibilityMatrix._();

  static const List<ReaderLayoutSettingCompatibilityItem>
  items = <ReaderLayoutSettingCompatibilityItem>[
    ReaderLayoutSettingCompatibilityItem(
      key: 'fontSize',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects line breaking and page count',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'lineHeight',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects line metrics',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'paragraphSpacing',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects block vertical layout',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'paragraphIndent',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects first line width',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'letterSpacing',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects glyph measurement and line breaking',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'pagePadding',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects content rect',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'horizontalPadding',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'legacy content rect alias derived from body margins',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'fontIdentity',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'font source, preset, family and weight affect measurement',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'fontSource',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'font source affects glyph metrics',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'systemFontPreset',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'system font preset affects glyph metrics',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'fontFamilyKey',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'managed font identity affects glyph metrics',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'customFontPath',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'custom font identity affects glyph metrics',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'fontWeightLevel',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'font weight affects glyph metrics',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'fontWeightValue',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'custom font weight affects glyph metrics',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyTextItalicEnabled',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'italic text can affect glyph bounds and line fit',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'textFullJustifyEnabled',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects Chinese text distribution',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'textBottomJustifyEnabled',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects paged vertical distribution',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'zhLayoutPolicy',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects punctuation and line breaking policy',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyMarginMode',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'selects how body content rect is resolved',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyMarginPreset',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'preset body margins affect content rect',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyMarginTop',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects content rect',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyMarginBottom',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects content rect',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyMarginLeft',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects content rect',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyMarginRight',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects content rect',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'showChapterHeader',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects chapter header layout and first-page content origin',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'chapterHeaderMode',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects chapter header visibility and placement',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'chapterHeaderTopSpacing',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects chapter header vertical layout',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'chapterHeaderBottomSpacing',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects chapter header vertical layout',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'chapterHeaderHorizontalOffset',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects chapter header placement within content rect',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'chapterHeaderVerticalOffset',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects chapter header placement within content rect',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'backgroundBrightnessInfoBar',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'owned by ReaderPage chrome/frame rather than text layout',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'themeMode',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'owned by reader chrome and visual frame',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'infoHeaderEnabled',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'outer info chrome should not be text measurement owner',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'infoFooterEnabled',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'outer info chrome should not be text measurement owner',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'infoShowTime',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'info visibility is reader chrome state',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'infoShowBattery',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'info visibility is reader chrome state',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'infoShowChapter',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'info visibility is reader chrome state',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'infoShowProgress',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'info visibility is reader chrome state',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'infoHeaderPadding',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'info bar geometry belongs to reader chrome',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'infoFooterPadding',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'info bar geometry belongs to reader chrome',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'infoHeaderDividerEnabled',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'info divider visibility belongs to reader chrome',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'infoFooterDividerEnabled',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'info divider visibility belongs to reader chrome',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'infoHeaderMarginTop',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'info bar margin belongs to reader chrome',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'infoHeaderMarginBottom',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'info bar margin belongs to reader chrome',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'infoHeaderMarginLeft',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'info bar margin belongs to reader chrome',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'infoHeaderMarginRight',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'info bar margin belongs to reader chrome',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'infoFooterMarginTop',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'info bar margin belongs to reader chrome',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'infoFooterMarginBottom',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'info bar margin belongs to reader chrome',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'infoFooterMarginLeft',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'info bar margin belongs to reader chrome',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'infoFooterMarginRight',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'info bar margin belongs to reader chrome',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'pinnedChapterHeaderOffsetX',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'pinned header offset belongs to reader chrome',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'pinnedChapterHeaderOffsetY',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'pinned header offset belongs to reader chrome',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'brightness',
      status: ReaderLayoutSettingCompatibilityStatus.platformOwned,
      reason: 'system brightness bridge should not trigger text layout',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'followSystemBrightness',
      status: ReaderLayoutSettingCompatibilityStatus.platformOwned,
      reason: 'system brightness policy belongs to platform bridge',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'backgroundStyle',
      status: ReaderLayoutSettingCompatibilityStatus.visualOnly,
      reason: 'page frame visual state should repaint without remeasurement',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'backgroundTone',
      status: ReaderLayoutSettingCompatibilityStatus.visualOnly,
      reason: 'page frame visual state should repaint without remeasurement',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'backgroundImageBase64',
      status: ReaderLayoutSettingCompatibilityStatus.visualOnly,
      reason: 'wallpaper affects frame rendering and page-turn snapshots',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyTextColorValue',
      status: ReaderLayoutSettingCompatibilityStatus.visualOnly,
      reason: 'text color should repaint without changing line breaking',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyTextShadowEnabled',
      status: ReaderLayoutSettingCompatibilityStatus.visualOnly,
      reason: 'shadow affects paint and clipping, not line breaking',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyTextShadowColorValue',
      status: ReaderLayoutSettingCompatibilityStatus.visualOnly,
      reason: 'shadow color affects paint only',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyTextShadowBlurRadius',
      status: ReaderLayoutSettingCompatibilityStatus.visualOnly,
      reason: 'shadow blur affects paint and clipping',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyTextShadowOffsetDx',
      status: ReaderLayoutSettingCompatibilityStatus.visualOnly,
      reason: 'shadow offset affects paint and clipping',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyTextShadowOffsetDy',
      status: ReaderLayoutSettingCompatibilityStatus.visualOnly,
      reason: 'shadow offset affects paint and clipping',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyTextDecorationStyle',
      status: ReaderLayoutSettingCompatibilityStatus.visualOnly,
      reason: 'body decoration affects paint and annotation overlap',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyTextDecorationColorValue',
      status: ReaderLayoutSettingCompatibilityStatus.visualOnly,
      reason: 'body decoration color affects paint only',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyTextUnderlineThickness',
      status: ReaderLayoutSettingCompatibilityStatus.visualOnly,
      reason: 'underline metrics affect paint and clipping',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyTextUnderlineGap',
      status: ReaderLayoutSettingCompatibilityStatus.visualOnly,
      reason: 'underline metrics affect paint and clipping',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyTextUnderlineDashLength',
      status: ReaderLayoutSettingCompatibilityStatus.visualOnly,
      reason: 'underline dash metrics affect paint only',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'bodyTextUnderlineDashGapRatio',
      status: ReaderLayoutSettingCompatibilityStatus.visualOnly,
      reason: 'underline dash metrics affect paint only',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'pageTurnMode',
      status: ReaderLayoutSettingCompatibilityStatus.interactionOwned,
      reason: 'selects paged or scroll interaction surface',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'pageAnimationStyle',
      status: ReaderLayoutSettingCompatibilityStatus.pageTurnDelegateFallback,
      reason:
          'unbridged release animations are gated by ReaderPageTurnDelegate',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'pageTurnStepRatio',
      status: ReaderLayoutSettingCompatibilityStatus.interactionOwned,
      reason: 'controls scroll step distance rather than text measurement',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'volumeKeyPageEnabled',
      status: ReaderLayoutSettingCompatibilityStatus.interactionOwned,
      reason: 'platform input toggle belongs to navigation command routing',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'tapZoneActions',
      status: ReaderLayoutSettingCompatibilityStatus.interactionOwned,
      reason: 'tap zones map input to navigation commands',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'autoReadEnabled',
      status: ReaderLayoutSettingCompatibilityStatus.interactionOwned,
      reason: 'auto-read state is runtime interaction state',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'autoReadSpeed',
      status: ReaderLayoutSettingCompatibilityStatus.interactionOwned,
      reason: 'auto-read speed controls runtime advancement',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'autoReadMode',
      status: ReaderLayoutSettingCompatibilityStatus.interactionOwned,
      reason: 'auto-read mode selects page or scroll runtime',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'autoReadSpeedLevel',
      status: ReaderLayoutSettingCompatibilityStatus.interactionOwned,
      reason: 'auto-read speed level controls runtime advancement',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'autoReadPauseMode',
      status: ReaderLayoutSettingCompatibilityStatus.interactionOwned,
      reason: 'auto-read pause policy belongs to runtime advancement',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'autoReadEndBehavior',
      status: ReaderLayoutSettingCompatibilityStatus.interactionOwned,
      reason: 'auto-read end policy belongs to runtime advancement',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'mangaReadMode',
      status: ReaderLayoutSettingCompatibilityStatus.surfaceOwned,
      reason: 'manga mode belongs to image surface',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'mangaImageSpacing',
      status: ReaderLayoutSettingCompatibilityStatus.surfaceOwned,
      reason: 'manga spacing belongs to image surface',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'mangaImagePadding',
      status: ReaderLayoutSettingCompatibilityStatus.surfaceOwned,
      reason: 'manga padding belongs to image surface',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'mangaLoadStrategy',
      status: ReaderLayoutSettingCompatibilityStatus.surfaceOwned,
      reason: 'manga load strategy belongs to image surface',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'audioDefaultSpeed',
      status: ReaderLayoutSettingCompatibilityStatus.surfaceOwned,
      reason: 'audio speed belongs to audio surface',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'audioRememberSpeed',
      status: ReaderLayoutSettingCompatibilityStatus.surfaceOwned,
      reason: 'audio speed persistence belongs to audio surface',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'audioSeekStepSeconds',
      status: ReaderLayoutSettingCompatibilityStatus.surfaceOwned,
      reason: 'audio seek step belongs to audio surface',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'audioAutoPlay',
      status: ReaderLayoutSettingCompatibilityStatus.surfaceOwned,
      reason: 'audio autoplay belongs to audio surface',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'switchSourceScoreRankingEnabled',
      status: ReaderLayoutSettingCompatibilityStatus.dataOwned,
      reason: 'source switching policy belongs to data/source ranking',
    ),
  ];

  static bool isTrackedInLayoutSignature(String key) {
    return items.any(
      (item) =>
          item.key == key &&
          item.status ==
              ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
    );
  }

  static List<ReaderLayoutSettingCompatibilityItem> byStatus(
    ReaderLayoutSettingCompatibilityStatus status,
  ) {
    return items.where((item) => item.status == status).toList(growable: false);
  }

  static ReaderLayoutSettingCompatibilityItem? itemFor(String key) {
    for (final item in items) {
      if (item.key == key) {
        return item;
      }
    }
    return null;
  }

  static bool containsKey(String key) => itemFor(key) != null;
}
