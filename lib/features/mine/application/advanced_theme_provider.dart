import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'active_theme_appearance_snapshot.dart';
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
  final service = ref.watch(advancedThemeServiceProvider);
  return service.loadThemeById(activeId);
});

class ActiveAdvancedThemeIdNotifier extends Notifier<String?> {
  static String? _primedActiveThemeId;
  static bool _hasPrimedValue = false;

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  static void prime(SharedPreferences prefs) {
    _primedActiveThemeId = AdvancedThemeService.readActiveThemeId(prefs);
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
    return null;
  }

  Future<void> _load() async {
    final service = ref.read(advancedThemeServiceProvider);
    final activeId = await service.loadActiveThemeId();
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
        normalized == null || normalized.isEmpty ? null : normalized;
    final service = ref.read(advancedThemeServiceProvider);
    await service.saveActiveThemeId(nextValue);
    await ref
        .read(activeThemeAppearanceSnapshotProvider.notifier)
        .reloadFromStorage();
    _primedActiveThemeId = nextValue;
    _hasPrimedValue = true;
    if (state != nextValue) {
      state = nextValue;
    }
  }

  Future<void> disable() => setActiveThemeId(null);
}

class ActiveThemeAppearanceSnapshotNotifier
    extends Notifier<ActiveThemeAppearanceSnapshot?> {
  static ActiveThemeAppearanceSnapshot? _primedSnapshot;
  static bool _hasPrimedValue = false;

  bool _loadTriggered = false;

  static void prime(SharedPreferences prefs) {
    _primedSnapshot = AdvancedThemeService.readActiveThemeAppearanceSnapshot(
      prefs,
    );
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
      unawaited(_load());
    }
    return null;
  }

  Future<void> _load() async {
    final snapshot =
        await ref
            .read(advancedThemeServiceProvider)
            .loadActiveThemeAppearanceSnapshot();
    if (snapshot == state) {
      return;
    }
    state = snapshot;
  }

  Future<void> reloadFromStorage() => _load();
}

class AdvancedThemeRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void markChanged() {
    state += 1;
  }
}
