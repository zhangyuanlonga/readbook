import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindowBootstrap {
  const DesktopWindowBootstrap._();

  /// 桌面原生窗口最小宽度必须低于 600dp，确保 macOS / Windows / Linux
  /// 真机调试时也能拖到移动壳层与窄桌面断点，避免响应式分支只在测试里可达。
  static const Size minimumSize = Size(520, 620);
  static const Size initialSize = Size(1280, 820);
  static const String windowTitle = 'Selune';

  static Future<void> configure() async {
    if (kIsWeb || !_isDesktopHost) {
      return;
    }

    await windowManager.ensureInitialized();
    final options = WindowOptions(
      size: initialSize,
      minimumSize: minimumSize,
      center: true,
      title: windowTitle,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: Platform.isMacOS,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  static bool get _isDesktopHost =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}
