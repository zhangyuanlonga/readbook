import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ReaderScreenBrightnessBridge {
  ReaderScreenBrightnessBridge._();

  static final ReaderScreenBrightnessBridge instance =
      ReaderScreenBrightnessBridge._();

  static const MethodChannel _channel = MethodChannel(
    'com.jiangyan.selune/reader_screen_brightness',
  );
  static const String _methodSetReaderBrightness = 'setReaderBrightness';
  static const String _methodResetReaderBrightness = 'resetReaderBrightness';

  bool get isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<bool> setReaderBrightness(double brightness) async {
    if (!isSupportedPlatform) {
      return false;
    }
    try {
      await _channel.invokeMethod<void>(
        _methodSetReaderBrightness,
        brightness.clamp(0.0, 1.0).toDouble(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> resetReaderBrightness() async {
    if (!isSupportedPlatform) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(_methodResetReaderBrightness);
    } catch (_) {
      // Ignore native restore failures to avoid breaking page teardown.
    }
  }
}
