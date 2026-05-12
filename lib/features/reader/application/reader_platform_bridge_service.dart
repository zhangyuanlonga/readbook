import 'dart:async';

import 'package:flutter/foundation.dart';

import 'reader_screen_brightness_bridge.dart';
import 'reader_volume_key_page_bridge.dart';

class ReaderPlatformBridgeService {
  ReaderPlatformBridgeService({
    ReaderScreenBrightnessBridge? screenBrightnessBridge,
    ReaderVolumeKeyPageBridge? volumeKeyPageBridge,
  }) : _screenBrightnessBridge =
           screenBrightnessBridge ?? ReaderScreenBrightnessBridge.instance,
       _volumeKeyPageBridge =
           volumeKeyPageBridge ?? ReaderVolumeKeyPageBridge.instance;

  final ReaderScreenBrightnessBridge _screenBrightnessBridge;
  final ReaderVolumeKeyPageBridge _volumeKeyPageBridge;

  bool get isVolumeKeyPagingSupported => _volumeKeyPageBridge.isSupported;

  String get volumeKeyPagingSupportDescription {
    if (!isVolumeKeyPagingSupported) {
      return '当前平台暂不支持音量键翻页。';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'iOS 真机支持音量键翻页；启用后会拦截按键并维持系统音量。';
    }
    return '仅在阅读态生效，打开菜单或弹层时不会拦截系统音量。';
  }

  Stream<ReaderVolumeKeyEvent> get volumeKeyEvents => _volumeKeyPageBridge.events;

  Future<void> setVolumeKeyPagingEnabled(bool enabled) {
    return _volumeKeyPageBridge.setEnabled(enabled);
  }

  Future<bool> setReaderBrightness(double brightness) {
    return _screenBrightnessBridge.setReaderBrightness(brightness);
  }

  Future<void> resetReaderBrightness() {
    return _screenBrightnessBridge.resetReaderBrightness();
  }
}
