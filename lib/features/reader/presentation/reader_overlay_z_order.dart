enum ReaderShellLayerSlot {
  background,
  backgroundOverlay,
  content,
  center,
  top,
  bottom,
  leading,
  trailing,
  foregroundOverlay,
}

const readerShellLayerOrder = <ReaderShellLayerSlot>[
  ReaderShellLayerSlot.background,
  ReaderShellLayerSlot.backgroundOverlay,
  ReaderShellLayerSlot.content,
  ReaderShellLayerSlot.center,
  ReaderShellLayerSlot.top,
  ReaderShellLayerSlot.bottom,
  ReaderShellLayerSlot.leading,
  ReaderShellLayerSlot.trailing,
  ReaderShellLayerSlot.foregroundOverlay,
];

enum ReaderForegroundOverlaySlot {
  chapterLoading,
  autoReadStatus,
  overlayScrim,
  topChrome,
  bottomChrome,
}

const readerForegroundOverlayOrder = <ReaderForegroundOverlaySlot>[
  ReaderForegroundOverlaySlot.chapterLoading,
  ReaderForegroundOverlaySlot.autoReadStatus,
  ReaderForegroundOverlaySlot.overlayScrim,
  ReaderForegroundOverlaySlot.topChrome,
  ReaderForegroundOverlaySlot.bottomChrome,
];
