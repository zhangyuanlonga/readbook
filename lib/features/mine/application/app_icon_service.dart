import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppIconVariant {
  primary('default', '默认图标'),
  alt('alt', '备选图标');

  const AppIconVariant(this.platformValue, this.label);

  final String platformValue;
  final String label;

  static AppIconVariant fromPlatformValue(String? raw) {
    return AppIconVariant.values.firstWhere(
      (item) => item.platformValue == raw,
      orElse: () => AppIconVariant.primary,
    );
  }
}

class AppIconService {
  AppIconService({MethodChannel? channel})
    : _channel = channel ?? _methodChannel;

  static const String _channelName = 'com.example.flutter_appread/app_icon';
  static const MethodChannel _methodChannel = MethodChannel(_channelName);

  static const String _methodIsSupported = 'isSupported';
  static const String _methodGetCurrentIcon = 'getCurrentIcon';
  static const String _methodSetAppIcon = 'setAppIcon';

  final MethodChannel _channel;

  Future<bool> isSupported() async {
    if (kIsWeb) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(_methodIsSupported) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<AppIconVariant> currentIcon() async {
    if (kIsWeb) {
      return AppIconVariant.primary;
    }
    try {
      final raw = await _channel.invokeMethod<String>(_methodGetCurrentIcon);
      return AppIconVariant.fromPlatformValue(raw);
    } on MissingPluginException {
      return AppIconVariant.primary;
    } on PlatformException {
      return AppIconVariant.primary;
    }
  }

  Future<void> setIcon(AppIconVariant icon) async {
    await _channel.invokeMethod<void>(_methodSetAppIcon, <String, Object?>{
      'icon': icon.platformValue,
    });
  }
}
