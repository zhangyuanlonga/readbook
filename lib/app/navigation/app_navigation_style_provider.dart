import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppNavigationStylePreference { followSystem, standard, cupertinoDock }

enum AppNavigationStyle { standard, cupertinoDock }

final appNavigationStylePreferenceProvider = NotifierProvider<
  AppNavigationStylePreferenceNotifier,
  AppNavigationStylePreference
>(AppNavigationStylePreferenceNotifier.new);

final appNavigationLabelVisibilityProvider =
    NotifierProvider<AppNavigationLabelVisibilityNotifier, bool>(
      AppNavigationLabelVisibilityNotifier.new,
    );

class AppNavigationStylePreferenceNotifier
    extends Notifier<AppNavigationStylePreference> {
  static const String _navigationStyleKey = 'app.navigationStyle';
  static AppNavigationStylePreference? _primedPreference;

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  static void prime(SharedPreferences prefs) {
    _primedPreference = _preferenceFromRaw(
      prefs.getString(_navigationStyleKey),
    );
  }

  @override
  AppNavigationStylePreference build() {
    final primedPreference = _primedPreference;
    if (primedPreference != null) {
      return primedPreference;
    }
    if (!_loadTriggered) {
      _loadTriggered = true;
      _load();
    }
    return AppNavigationStylePreference.standard;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = _preferenceFromRaw(prefs.getString(_navigationStyleKey));
    if (_hasExplicitSet) {
      return;
    }
    if (loaded != state) {
      state = loaded;
    }
  }

  Future<void> setPreference(AppNavigationStylePreference preference) async {
    _hasExplicitSet = true;
    _primedPreference = preference;
    if (preference != state) {
      state = preference;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_navigationStyleKey, _rawFromPreference(preference));
  }

  static AppNavigationStylePreference _preferenceFromRaw(String? raw) {
    return switch (raw) {
      'standard' => AppNavigationStylePreference.standard,
      'cupertinoDock' => AppNavigationStylePreference.cupertinoDock,
      _ => AppNavigationStylePreference.standard,
    };
  }

  static String _rawFromPreference(AppNavigationStylePreference preference) {
    return switch (preference) {
      AppNavigationStylePreference.followSystem => 'followSystem',
      AppNavigationStylePreference.standard => 'standard',
      AppNavigationStylePreference.cupertinoDock => 'cupertinoDock',
    };
  }
}

class AppNavigationLabelVisibilityNotifier extends Notifier<bool> {
  static const String _navigationLabelVisibilityKey =
      'app.navigation.showLabels';
  static bool? _primedVisibility;

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  static void prime(SharedPreferences prefs) {
    _primedVisibility = prefs.getBool(_navigationLabelVisibilityKey);
  }

  @override
  bool build() {
    final primedVisibility = _primedVisibility;
    if (primedVisibility != null) {
      return primedVisibility;
    }
    if (!_loadTriggered) {
      _loadTriggered = true;
      _load();
    }
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = prefs.getBool(_navigationLabelVisibilityKey) ?? true;
    if (_hasExplicitSet) {
      return;
    }
    if (loaded != state) {
      state = loaded;
    }
  }

  Future<void> setVisible(bool visible) async {
    _hasExplicitSet = true;
    _primedVisibility = visible;
    if (visible != state) {
      state = visible;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_navigationLabelVisibilityKey, visible);
  }
}

bool supportsMobileNavigationStyle({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (isWeb) {
    return false;
  }

  return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
}

AppNavigationStyle resolveAppNavigationStyle(
  AppNavigationStylePreference preference, {
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (!supportsMobileNavigationStyle(isWeb: isWeb, platform: platform)) {
    return AppNavigationStyle.standard;
  }

  return switch (preference) {
    AppNavigationStylePreference.followSystem =>
      AppNavigationStyle.standard,
    AppNavigationStylePreference.standard => AppNavigationStyle.standard,
    AppNavigationStylePreference.cupertinoDock =>
      AppNavigationStyle.cupertinoDock,
  };
}

String appNavigationStylePreferenceLabel(
  AppNavigationStylePreference preference,
) {
  return switch (preference) {
    AppNavigationStylePreference.followSystem => '标准',
    AppNavigationStylePreference.standard => '标准',
    AppNavigationStylePreference.cupertinoDock => '苹果风格',
  };
}

String appNavigationLabelVisibilityLabel(bool visible) {
  return visible ? '显示文字' : '仅图标';
}

bool isPlatformNavigationStyleSupported() {
  return supportsMobileNavigationStyle(
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  );
}
