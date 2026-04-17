import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/app_advanced_theme.dart';
import 'advanced_theme_service.dart';

final advancedThemeServiceProvider = Provider<AdvancedThemeService>((ref) {
  return AdvancedThemeService();
});

final activeAdvancedThemeIdProvider =
    NotifierProvider<ActiveAdvancedThemeIdNotifier, String?>(
      ActiveAdvancedThemeIdNotifier.new,
    );

final activeAdvancedThemeProvider = FutureProvider<AppAdvancedTheme?>((
  ref,
) async {
  final activeId = ref.watch(activeAdvancedThemeIdProvider);
  if (activeId == null || activeId.trim().isEmpty) {
    return null;
  }
  final service = ref.watch(advancedThemeServiceProvider);
  final themes = await service.loadThemes();
  for (final theme in themes) {
    if (theme.id == activeId) {
      return theme;
    }
  }
  return null;
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
    _primedActiveThemeId = nextValue;
    _hasPrimedValue = true;
    if (state != nextValue) {
      state = nextValue;
    }
    final service = ref.read(advancedThemeServiceProvider);
    await service.saveActiveThemeId(nextValue);
  }

  Future<void> disable() => setActiveThemeId(null);
}
