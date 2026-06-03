import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_editor_page_state.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_list_page_state.dart';

void main() {
  group('AdvancedThemeListPageStateNotifier', () {
    test('stores long-lived list filters and saving state in Riverpod', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        advancedThemeListPageStateProvider.notifier,
      );
      final token = notifier.nextSummaryLoadToken();
      notifier.update(
        (state) => state.copyWith(
          searchQuery: '护眼',
          selectedCategory: '极简',
          selectedThemeIds: <String>{'theme-a', 'theme-b'},
          isSelectionMode: true,
          isSaving: true,
          savingStatusText: '正在导出主题...',
          themeSortMode: AdvancedThemeSortMode.nameAsc,
        ),
      );

      final state = container.read(advancedThemeListPageStateProvider);
      expect(token, 1);
      expect(state.summaryLoadToken, 1);
      expect(state.searchQuery, '护眼');
      expect(state.selectedCategory, '极简');
      expect(state.selectedThemeIds, <String>{'theme-a', 'theme-b'});
      expect(state.isSelectionMode, isTrue);
      expect(state.isSaving, isTrue);
      expect(state.savingStatusText, '正在导出主题...');
      expect(state.themeSortMode, AdvancedThemeSortMode.nameAsc);
    });
  });

  group('AdvancedThemeEditorPageStateNotifier', () {
    test(
      'stores editor draft, mode, resources, and saving state in Riverpod',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final draft = AppAdvancedTheme(
          id: 'theme-editor-state',
          name: '编辑中主题',
          createdAt: DateTime.utc(2026, 6, 3),
          updatedAt: DateTime.utc(2026, 6, 3),
          lightConfig: AppAdvancedThemeModeConfig(),
          darkConfig: AppAdvancedThemeModeConfig(),
        );

        container
            .read(advancedThemeEditorPageStateProvider.notifier)
            .update(
              (state) => state.copyWith(
                draft: draft,
                selectedMode: AppAdvancedThemeMode.dark,
                backgroundLibraryPaths: const <String>['/tmp/bg.png'],
                readerBackgroundLibraryPaths: const <String>['/tmp/reader.png'],
                strengthControlsExpanded: false,
                componentControlsExpanded: false,
                isEditingName: true,
                isLoading: false,
                isSaving: true,
              ),
            );

        final state = container.read(advancedThemeEditorPageStateProvider);
        expect(state.draft, draft);
        expect(state.selectedMode, AppAdvancedThemeMode.dark);
        expect(state.backgroundLibraryPaths, const <String>['/tmp/bg.png']);
        expect(state.readerBackgroundLibraryPaths, const <String>[
          '/tmp/reader.png',
        ]);
        expect(state.strengthControlsExpanded, isFalse);
        expect(state.componentControlsExpanded, isFalse);
        expect(state.isEditingName, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.isSaving, isTrue);
      },
    );
  });
}
