import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'active_theme_appearance_snapshot.dart';
import '../../../app/theme/app_official_theme_presets.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import 'advanced_theme_service.dart';

final advancedThemeServiceProvider = Provider<AdvancedThemeService>((ref) {
  return AdvancedThemeService();
});

final activeAdvancedThemeIdProvider =
    NotifierProvider<ActiveAdvancedThemeIdNotifier, String?>(
      ActiveAdvancedThemeIdNotifier.new,
    );

final advancedThemeRevisionProvider =
    NotifierProvider<AdvancedThemeRevisionNotifier, int>(
      AdvancedThemeRevisionNotifier.new,
    );

final activeThemeAppearanceSnapshotProvider = NotifierProvider<
  ActiveThemeAppearanceSnapshotNotifier,
  ActiveThemeAppearanceSnapshot?
>(ActiveThemeAppearanceSnapshotNotifier.new);

final activeAdvancedThemeProvider = FutureProvider<AppAdvancedTheme?>((
  ref,
) async {
  ref.watch(advancedThemeRevisionProvider);
  final activeId = ref.watch(activeAdvancedThemeIdProvider);
  if (activeId == null || activeId.trim().isEmpty) {
    return null;
  }
  if (isOfficialThemeId(activeId)) {
    return null;
  }
  final service = ref.watch(advancedThemeServiceProvider);
  return service.loadThemeById(activeId);
});

class ActiveAdvancedThemeIdNotifier extends Notifier<String?> {
  static String? _primedActiveThemeId;
  static bool _hasPrimedValue = false;

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  static void prime(SharedPreferences prefs) {
    _primedActiveThemeId =
        AdvancedThemeService.readActiveThemeId(prefs) ??
        appDefaultOfficialThemeId;
    _hasPrimedValue = true;
  }

  @override
  String? build() {
    if (_hasPrimedValue) {
      return _primedActiveThemeId;
    }
    if (!_loadTriggered) {
      _loadTriggered = true;
      _load();
    }
    return appDefaultOfficialThemeId;
  }

  Future<void> _load() async {
    final service = ref.read(advancedThemeServiceProvider);
    final activeId =
        await service.loadActiveThemeId() ?? appDefaultOfficialThemeId;
    if (_hasExplicitSet) {
      return;
    }
    if (activeId != state) {
      state = activeId;
    }
  }

  Future<void> setActiveThemeId(String? themeId) async {
    _hasExplicitSet = true;
    final normalized = themeId?.trim();
    final nextValue =
        normalized == null || normalized.isEmpty
            ? appDefaultOfficialThemeId
            : normalized;
    final service = ref.read(advancedThemeServiceProvider);
    await service.saveActiveThemeId(nextValue);
    _primedActiveThemeId = nextValue;
    _hasPrimedValue = true;
    if (state != nextValue) {
      state = nextValue;
    }
    await ref
        .read(activeThemeAppearanceSnapshotProvider.notifier)
        .reloadForThemeId(nextValue);
  }

  Future<void> disable() => setActiveThemeId(null);
}

class ActiveThemeAppearanceSnapshotNotifier
    extends Notifier<ActiveThemeAppearanceSnapshot?> {
  static ActiveThemeAppearanceSnapshot? _primedSnapshot;
  static bool _hasPrimedValue = false;

  bool _loadTriggered = false;

  static void prime(SharedPreferences prefs) {
    final activeThemeId =
        AdvancedThemeService.readActiveThemeId(prefs) ??
        appDefaultOfficialThemeId;
    if (isOfficialThemeId(activeThemeId)) {
      _primedSnapshot =
          appOfficialThemePresetByThemeId(activeThemeId).toAppearanceSnapshot();
    } else {
      _primedSnapshot = AdvancedThemeService.readActiveThemeAppearanceSnapshot(
        prefs,
      );
    }
    _hasPrimedValue = true;
  }

  @override
  ActiveThemeAppearanceSnapshot? build() {
    ref.listen<int>(advancedThemeRevisionProvider, (_, __) {
      unawaited(_load());
    });
    ref.listen<String?>(activeAdvancedThemeIdProvider, (_, __) {
      unawaited(_load());
    });
    if (_hasPrimedValue) {
      return _primedSnapshot;
    }
    if (!_loadTriggered) {
      _loadTriggered = true;
      final activeThemeId =
          ref.read(activeAdvancedThemeIdProvider) ?? appDefaultOfficialThemeId;
      if (isOfficialThemeId(activeThemeId)) {
        return appOfficialThemePresetByThemeId(
          activeThemeId,
        ).toAppearanceSnapshot();
      }
      unawaited(_load());
    }
    return null;
  }

  Future<void> _load() async {
    final activeThemeId =
        ref.read(activeAdvancedThemeIdProvider) ?? appDefaultOfficialThemeId;
    await _loadForThemeId(activeThemeId);
  }

  Future<void> _loadForThemeId(String activeThemeId) async {
    final snapshot =
        isOfficialThemeId(activeThemeId)
            ? appOfficialThemePresetByThemeId(
              activeThemeId,
            ).toAppearanceSnapshot()
            : await ref
                .read(advancedThemeServiceProvider)
                .loadActiveThemeAppearanceSnapshot();
    if (snapshot == state) {
      return;
    }
    state = snapshot;
  }

  Future<void> reloadFromStorage() => _load();

  Future<void> reloadForThemeId(String? themeId) {
    return _loadForThemeId(
      themeId?.trim().isNotEmpty == true
          ? themeId!.trim()
          : appDefaultOfficialThemeId,
    );
  }
}

class AdvancedThemeRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void markChanged() {
    state += 1;
  }
}
