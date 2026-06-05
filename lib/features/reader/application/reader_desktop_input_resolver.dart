import 'package:flutter/services.dart';

/// 阅读器桌面 / Web 输入层返回的语义动作。
///
/// 枚举值只表达阅读器能执行的动作，不绑定具体按键或指针事件，
/// 方便后续在不同平台调整输入映射时保持页面执行层稳定。
enum ReaderDesktopInputAction {
  none,
  toggleOverlay,
  pauseAutoRead,
  previousPage,
  nextPage,
  chapterStart,
  chapterEnd,
}

/// 阅读器桌面 / Web 输入策略解析器。
///
/// 页面层传入当前 reader 状态，由这里统一决定是否响应快捷键或滚轮；
/// 不在 widget 内散落平台判断，可以降低 Web 与桌面行为漂移的风险。
class ReaderDesktopInputResolver {
  const ReaderDesktopInputResolver();

  /// 统一解析 Web / Desktop 阅读态键盘动作。
  ///
  /// 页面层只执行这里返回的语义动作，不能再散落一套按键映射；这样后续新增
  /// 快捷键、禁用条件或自动阅读协作时，不会让 Web 和桌面端行为分叉。
  ReaderDesktopInputAction resolveKeyAction(
    LogicalKeyboardKey key, {
    bool textSelectionActive = false,
    bool editingText = false,
    bool readerBusy = false,
    bool overlayVisible = false,
    bool autoReadSessionEnabled = false,
  }) {
    if (textSelectionActive || editingText || readerBusy) {
      return ReaderDesktopInputAction.none;
    }
    final shortcutAction = _resolveShortcutAction(key);
    if (shortcutAction == ReaderDesktopInputAction.toggleOverlay) {
      return shortcutAction;
    }
    if (overlayVisible) {
      return ReaderDesktopInputAction.none;
    }
    if (autoReadSessionEnabled) {
      return ReaderDesktopInputAction.pauseAutoRead;
    }
    return shortcutAction;
  }

  ReaderDesktopInputAction _resolveShortcutAction(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.escape) {
      return ReaderDesktopInputAction.toggleOverlay;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp) {
      return ReaderDesktopInputAction.previousPage;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.pageDown) {
      return ReaderDesktopInputAction.nextPage;
    }
    if (key == LogicalKeyboardKey.home) {
      return ReaderDesktopInputAction.chapterStart;
    }
    if (key == LogicalKeyboardKey.end) {
      return ReaderDesktopInputAction.chapterEnd;
    }
    return ReaderDesktopInputAction.none;
  }

  ReaderDesktopInputAction resolvePointerScrollAction({
    required double deltaY,
    required bool isPagedViewport,
    required bool overlayVisible,
    required bool textSelectionActive,
    DateTime? lastPageTurnAt,
    required DateTime now,
    double threshold = 8,
    Duration throttle = const Duration(milliseconds: 180),
  }) {
    if (!isPagedViewport || overlayVisible || textSelectionActive) {
      return ReaderDesktopInputAction.none;
    }
    if (deltaY.abs() < threshold) {
      return ReaderDesktopInputAction.none;
    }
    if (lastPageTurnAt != null && now.difference(lastPageTurnAt) < throttle) {
      return ReaderDesktopInputAction.none;
    }
    return deltaY > 0
        ? ReaderDesktopInputAction.nextPage
        : ReaderDesktopInputAction.previousPage;
  }
}
