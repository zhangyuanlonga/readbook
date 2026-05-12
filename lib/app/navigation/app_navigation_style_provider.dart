import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../preferences/app_preferences_service.dart';

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

final appStandardNavigationBarAppearanceProvider = NotifierProvider<
  AppStandardNavigationBarAppearanceNotifier,
  AppStandardNavigationBarAppearance
>(AppStandardNavigationBarAppearanceNotifier.new);

final appCupertinoDockAppearanceProvider = NotifierProvider<
  AppCupertinoDockAppearanceNotifier,
  AppCupertinoDockAppearance
>(AppCupertinoDockAppearanceNotifier.new);

class AppStandardNavigationBarAppearance {
  const AppStandardNavigationBarAppearance({
    this.floatingBar = false,
    this.frostedEffect = false,
  });

  final bool floatingBar;
  final bool frostedEffect;

  AppStandardNavigationBarAppearance copyWith({
    bool? floatingBar,
    bool? frostedEffect,
  }) {
    return AppStandardNavigationBarAppearance(
      floatingBar: floatingBar ?? this.floatingBar,
      frostedEffect: frostedEffect ?? this.frostedEffect,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppStandardNavigationBarAppearance &&
        other.floatingBar == floatingBar &&
        other.frostedEffect == frostedEffect;
  }

  @override
  int get hashCode => Object.hash(floatingBar, frostedEffect);
}

class AppCupertinoDockAppearance {
  const AppCupertinoDockAppearance({this.frostedEffect = false});

  final bool frostedEffect;

  AppCupertinoDockAppearance copyWith({bool? frostedEffect}) {
    return AppCupertinoDockAppearance(
      frostedEffect: frostedEffect ?? this.frostedEffect,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppCupertinoDockAppearance &&
        other.frostedEffect == frostedEffect;
  }

  @override
  int get hashCode => frostedEffect.hashCode;
}

class AppNavigationStylePreferenceNotifier
    extends Notifier<AppNavigationStylePreference> {
  static AppNavigationStylePreference? _primedPreference;

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  static void prime(SharedPreferences prefs) {
    _primedPreference = _preferenceFromRaw(
      prefs.getString(appNavigationStylePreferenceKey),
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
    final loaded = _preferenceFromRaw(
      await ref
          .read(appNavigationPreferencesServiceProvider)
          .loadNavigationStyleRaw(),
    );
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

    await ref
        .read(appNavigationPreferencesServiceProvider)
        .saveNavigationStyleRaw(_rawFromPreference(preference));
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
  static bool? _primedVisibility;

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  static void prime(SharedPreferences prefs) {
    _primedVisibility = prefs.getBool(
      appNavigationLabelVisibilityPreferenceKey,
    );
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
    final loaded =
        await ref
            .read(appNavigationPreferencesServiceProvider)
            .loadLabelVisibility() ??
        true;
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

    await ref
        .read(appNavigationPreferencesServiceProvider)
        .saveLabelVisibility(visible);
  }
}

class AppStandardNavigationBarAppearanceNotifier
    extends Notifier<AppStandardNavigationBarAppearance> {
  static AppStandardNavigationBarAppearance? _primedAppearance;

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  static void prime(SharedPreferences prefs) {
    _primedAppearance = _readAppearance(prefs);
  }

  @override
  AppStandardNavigationBarAppearance build() {
    final primedAppearance = _primedAppearance;
    if (primedAppearance != null) {
      return primedAppearance;
    }
    if (!_loadTriggered) {
      _loadTriggered = true;
      _load();
    }
    return const AppStandardNavigationBarAppearance();
  }

  Future<void> _load() async {
    final loaded = await _loadAppearance();
    if (_hasExplicitSet) {
      return;
    }
    if (loaded != state) {
      state = loaded;
    }
  }

  Future<void> setFloatingBar(bool enabled) async {
    await _setAppearance(state.copyWith(floatingBar: enabled));
  }

  Future<void> setFrostedEffect(bool enabled) async {
    await _setAppearance(state.copyWith(frostedEffect: enabled));
  }

  Future<void> _setAppearance(AppStandardNavigationBarAppearance next) async {
    if (next == state) {
      return;
    }

    _hasExplicitSet = true;
    _primedAppearance = next;
    state = next;

    await ref
        .read(appNavigationPreferencesServiceProvider)
        .saveStandardNavigationBarAppearance(
          AppStandardNavigationBarAppearanceSnapshot(
            floatingBar: next.floatingBar,
            frostedEffect: next.frostedEffect,
          ),
        );
  }

  static AppStandardNavigationBarAppearance _readAppearance(
    SharedPreferences prefs,
  ) {
    return AppStandardNavigationBarAppearance(
      floatingBar:
          prefs.getBool(appNavigationStandardFloatingBarPreferenceKey) ?? false,
      frostedEffect:
          prefs.getBool(appNavigationStandardFrostedEffectPreferenceKey) ??
          false,
    );
  }

  Future<AppStandardNavigationBarAppearance> _loadAppearance() async {
    final snapshot =
        await ref
            .read(appNavigationPreferencesServiceProvider)
            .loadStandardNavigationBarAppearance();
    return AppStandardNavigationBarAppearance(
      floatingBar: snapshot.floatingBar,
      frostedEffect: snapshot.frostedEffect,
    );
  }
}

class AppCupertinoDockAppearanceNotifier
    extends Notifier<AppCupertinoDockAppearance> {
  static AppCupertinoDockAppearance? _primedAppearance;

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  static void prime(SharedPreferences prefs) {
    _primedAppearance = AppCupertinoDockAppearance(
      frostedEffect:
          prefs.getBool(appNavigationCupertinoDockFrostedEffectPreferenceKey) ??
          false,
    );
  }

  @override
  AppCupertinoDockAppearance build() {
    final primedAppearance = _primedAppearance;
    if (primedAppearance != null) {
      return primedAppearance;
    }
    if (!_loadTriggered) {
      _loadTriggered = true;
      _load();
    }
    return const AppCupertinoDockAppearance();
  }

  Future<void> _load() async {
    final snapshot =
        await ref
            .read(appNavigationPreferencesServiceProvider)
            .loadCupertinoDockAppearance();
    final loaded = AppCupertinoDockAppearance(
      frostedEffect: snapshot.frostedEffect,
    );
    if (_hasExplicitSet) {
      return;
    }
    if (loaded != state) {
      state = loaded;
    }
  }

  Future<void> setFrostedEffect(bool enabled) async {
    final next = state.copyWith(frostedEffect: enabled);
    if (next == state) {
      return;
    }
    _hasExplicitSet = true;
    _primedAppearance = next;
    state = next;

    await ref
        .read(appNavigationPreferencesServiceProvider)
        .saveCupertinoDockAppearance(
          AppCupertinoDockAppearanceSnapshot(frostedEffect: enabled),
        );
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
    AppNavigationStylePreference.followSystem => AppNavigationStyle.standard,
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
