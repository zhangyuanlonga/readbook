import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_list_page_state.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_list_query_controller.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_service.dart';

void main() {
  const controller = AdvancedThemeListQueryController();

  group('AdvancedThemeListQueryController', () {
    test('sorts active theme first then applies selected sort mode', () {
      final themes = [
        _summary(id: 'b', name: 'Beta', updatedAt: DateTime.utc(2026, 1, 2)),
        _summary(id: 'a', name: 'Alpha', updatedAt: DateTime.utc(2026, 1, 3)),
        _summary(id: 'c', name: 'Gamma', updatedAt: DateTime.utc(2026, 1, 1)),
      ];

      final sorted = controller.sortThemeSummaries(
        themes: themes,
        activeThemeId: 'c',
        sortMode: AdvancedThemeSortMode.nameAsc,
      );

      expect(sorted.map((theme) => theme.id), orderedEquals(['c', 'a', 'b']));
    });

    test('filters by category and keyword', () {
      final themes = [
        _summary(id: 'warm', name: 'Warm Paper', category: '阅读'),
        _summary(id: 'cold', name: 'Cold Night', category: '夜间'),
      ];

      final visible = controller.visibleThemes(
        summaries: themes,
        searchQuery: 'paper',
        selectedCategory: '阅读',
      );

      expect(visible.map((theme) => theme.id), orderedEquals(['warm']));
    });

    test('builds sorted category list without blanks', () {
      final themes = [
        _summary(id: 'a', name: 'A', category: '夜间'),
        _summary(id: 'b', name: 'B', category: ''),
        _summary(id: 'c', name: 'C', category: '阅读'),
        _summary(id: 'd', name: 'D', category: '夜间'),
      ];

      expect(
        controller.availableCategories(themes),
        orderedEquals(['夜间', '阅读']),
      );
    });

    test('detects preview content changes', () {
      final previous = [
        _summary(id: 'a', name: 'A', lightWallpaperPath: 'light-a'),
      ];
      final next = [
        _summary(id: 'a', name: 'A', lightWallpaperPath: 'light-b'),
      ];

      expect(
        controller.hasSamePreviewContent(previous: previous, next: next),
        isFalse,
      );
    });

    test('prunes selected ids outside visible themes', () {
      final visible = [
        _summary(id: 'a', name: 'A'),
        _summary(id: 'b', name: 'B'),
      ];

      expect(
        controller.pruneSelectedThemeIds(
          visibleThemes: visible,
          selectedThemeIds: {'a', 'z'},
        ),
        {'a'},
      );
      expect(
        controller.areAllVisibleThemesSelected(
          visibleThemes: visible,
          selectedThemeIds: {'a', 'b'},
        ),
        isTrue,
      );
    });
  });
}

AdvancedThemeSummary _summary({
  required String id,
  required String name,
  DateTime? updatedAt,
  String? category,
  String? lightWallpaperPath,
}) {
  return AdvancedThemeSummary(
    id: id,
    name: name,
    category: category,
    updatedAt: updatedAt ?? DateTime.utc(2026),
    lightMode: _modeSummary(wallpaperPath: lightWallpaperPath),
    darkMode: _modeSummary(),
  );
}

AdvancedThemeModeSummary _modeSummary({String? wallpaperPath}) {
  return AdvancedThemeModeSummary(
    primaryColorValue: 0xFF123456,
    backgroundColorValue: 0xFFFFFFFF,
    surfaceColorValue: 0xFFF5F5F5,
    cardColorValue: 0xFFFFFFFF,
    cardTextColorValue: 0xFF111111,
    textSecondaryColorValue: 0xFF666666,
    componentStyle: const AppAdvancedThemeComponentStyle(),
    wallpaperPath: wallpaperPath,
    hasWallpaper: wallpaperPath != null,
    hasReaderWallpaper: false,
    configuredColorCount: 6,
  );
}
