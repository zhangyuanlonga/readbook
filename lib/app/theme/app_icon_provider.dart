import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/device/app_icon_service.dart';

final appIconServiceProvider = Provider<AppIconService>(
  (ref) => const AppIconService(),
);

final appIconVariantProvider =
    NotifierProvider<AppIconVariantNotifier, AppIconVariant>(
      AppIconVariantNotifier.new,
    );

class AppIconVariantNotifier extends Notifier<AppIconVariant> {
  static const String _appIconKey = 'app.iconVariant';
  static AppIconVariant? _primedVariant;

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  static void prime(SharedPreferences prefs) {
    _primedVariant = AppIconVariant.fromStorage(prefs.getString(_appIconKey));
  }

  @override
  AppIconVariant build() {
    final primedVariant = _primedVariant;
    if (primedVariant != null) {
      return primedVariant;
    }
    if (!_loadTriggered) {
      _loadTriggered = true;
      _load();
    }
    return AppIconVariant.light;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVariant = AppIconVariant.fromStorage(prefs.getString(_appIconKey));
    final platformVariant =
        await ref.read(appIconServiceProvider).getCurrentAppIcon();
    final loadedVariant = platformVariant ?? storedVariant;
    if (_hasExplicitSet) {
      return;
    }
    if (loadedVariant != state) {
      state = loadedVariant;
    }
    if (platformVariant != null &&
        platformVariant.storageValue != prefs.getString(_appIconKey)) {
      await prefs.setString(_appIconKey, platformVariant.storageValue);
      _primedVariant = platformVariant;
    }
  }

  Future<bool> setVariant(AppIconVariant variant) async {
    final didApply = await ref.read(appIconServiceProvider).setAppIcon(variant);
    if (!didApply) {
      return false;
    }

    _hasExplicitSet = true;
    _primedVariant = variant;
    if (state != variant) {
      state = variant;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appIconKey, variant.storageValue);
    return true;
  }
}
