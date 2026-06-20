enum ReaderLayoutSettingCompatibilityStatus {
  trackedInLayoutSignature,
  shellOwned,
  pageTurnDelegateFallback,
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
      key: 'pagePadding',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects content rect',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'fontIdentity',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'font source, preset, family and weight affect measurement',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'textFullJustifyEnabled',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects Chinese text distribution',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'zhLayoutPolicy',
      status: ReaderLayoutSettingCompatibilityStatus.trackedInLayoutSignature,
      reason: 'affects punctuation and line breaking policy',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'backgroundBrightnessInfoBar',
      status: ReaderLayoutSettingCompatibilityStatus.shellOwned,
      reason: 'owned by ReaderPage chrome/frame rather than text layout',
    ),
    ReaderLayoutSettingCompatibilityItem(
      key: 'pageAnimationStyle',
      status: ReaderLayoutSettingCompatibilityStatus.pageTurnDelegateFallback,
      reason:
          'unbridged release animations are gated by ReaderPageTurnDelegate',
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
}
