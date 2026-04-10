import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppIconVariant {
  light,
  dark;

  String get storageValue => name;

  String get label => switch (this) {
    AppIconVariant.light => '浅色',
    AppIconVariant.dark => '深色',
  };

  String get subtitle => switch (this) {
    AppIconVariant.light => '启动页场景缩放版',
    AppIconVariant.dark => '深色枝花图标',
  };

  String get previewAssetPath => switch (this) {
    AppIconVariant.light => 'assets/branding/selune_app_icon_light.png',
    AppIconVariant.dark => 'assets/branding/selune_app_icon_dark.png',
  };

  static AppIconVariant fromStorage(String? raw) {
    return switch (raw?.trim()) {
      'dark' => AppIconVariant.dark,
      _ => AppIconVariant.light,
    };
  }
}

class AppIconService {
  const AppIconService();

  static const MethodChannel _channel = MethodChannel(
    'com.jiangyan.selune/app_icon',
  );

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<AppIconVariant?> getCurrentAppIcon() async {
    if (!isSupported) {
      return null;
    }

    try {
      final raw = await _channel.invokeMethod<String>('getCurrentAppIcon');
      return AppIconVariant.fromStorage(raw);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<bool> setAppIcon(AppIconVariant variant) async {
    if (!isSupported) {
      return false;
    }

    try {
      await _channel.invokeMethod<void>('setAppIcon', <String, dynamic>{
        'variant': variant.storageValue,
      });
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
