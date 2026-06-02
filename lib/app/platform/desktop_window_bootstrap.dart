import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindowBootstrap {
  const DesktopWindowBootstrap._();

  static const Size minimumSize = Size(1024, 680);
  static const Size initialSize = Size(1280, 820);
  static const String windowTitle = 'Selune';

  static Future<void> configure() async {
    if (kIsWeb || !_isDesktopHost) {
      return;
    }

    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: initialSize,
      minimumSize: minimumSize,
      center: true,
      title: windowTitle,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  static bool get _isDesktopHost =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}
