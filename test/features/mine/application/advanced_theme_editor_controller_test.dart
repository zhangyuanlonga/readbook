import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/domain/entities/bottom_nav_icon_gallery.dart';
import 'package:shuxiang_reading_next/domain/entities/cover_gallery.dart';
import 'package:shuxiang_reading_next/domain/entities/launch_image_gallery.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_editor_controller.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_editor_page_state.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_editor_state_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_font_registry_service.dart';

void main() {
  const controller = AdvancedThemeEditorController();

  group('AdvancedThemeEditorController', () {
    test('sets draft and loading state together', () {
      final draft = _theme();

      final next = controller.setDraft(
        const AdvancedThemeEditorPageState(),
        draft,
        isLoading: false,
      );

      expect(next.draft, same(draft));
      expect(next.isLoading, isFalse);
    });

    test('sets selected mode and simple page flags', () {
      var state = const AdvancedThemeEditorPageState();

      state = controller.setSelectedMode(state, AppAdvancedThemeMode.dark);
      state = controller.setSaving(state, true);
      state = controller.setEditingName(state, true);
      state = controller.setStrengthControlsExpanded(state, false);
      state = controller.setComponentControlsExpanded(state, false);

      expect(state.selectedMode, AppAdvancedThemeMode.dark);
      expect(state.isSaving, isTrue);
      expect(state.isEditingName, isTrue);
      expect(state.strengthControlsExpanded, isFalse);
      expect(state.componentControlsExpanded, isFalse);
    });

    test('applies appearance links as immutable state copies', () {
      final backgroundPaths = ['app-bg'];
      final readerBackgroundPaths = ['reader-bg'];
      final bottomNavGalleries = [_bottomNavGallery()];
      final coverGalleries = [_coverGallery()];
      final launchImageGalleries = [_launchImageGallery()];
      final fonts = [
        const ReaderCustomFontEntry(
          fontFamilyKey: 'font-key',
          displayName: '字体',
          filePath: '/tmp/font.ttf',
          importedAtEpochMs: 1,
        ),
      ];

      final next = controller.applyAppearanceLinks(
        const AdvancedThemeEditorPageState(),
        AdvancedThemeEditorAppearanceLinks(
          backgroundLibraryPaths: backgroundPaths,
          readerBackgroundLibraryPaths: readerBackgroundPaths,
          bottomNavGalleries: bottomNavGalleries,
          coverGalleries: coverGalleries,
          launchImageGalleries: launchImageGalleries,
          availableFonts: fonts,
          activeBottomNavGalleryName: '默认底栏',
        ),
      );
      backgroundPaths.add('changed');
      readerBackgroundPaths.add('changed');
      bottomNavGalleries.add(_bottomNavGallery(id: 'changed'));
      coverGalleries.add(_coverGallery(id: 'changed'));
      launchImageGalleries.add(_launchImageGallery(id: 'changed'));
      fonts.add(
        const ReaderCustomFontEntry(
          fontFamilyKey: 'changed',
          displayName: '变更字体',
          filePath: '/tmp/changed.ttf',
          importedAtEpochMs: 2,
        ),
      );

      expect(next.backgroundLibraryPaths, orderedEquals(['app-bg']));
      expect(next.readerBackgroundLibraryPaths, orderedEquals(['reader-bg']));
      expect(next.bottomNavGalleries.map((item) => item.id), ['bottom']);
      expect(next.coverGalleries.map((item) => item.id), ['cover']);
      expect(next.launchImageGalleries.map((item) => item.id), ['launch']);
      expect(next.availableFonts.map((item) => item.fontFamilyKey), [
        'font-key',
      ]);
      expect(next.activeBottomNavGalleryName, '默认底栏');
    });
  });
}

AppAdvancedTheme _theme() {
  final now = DateTime.utc(2026);
  return AppAdvancedTheme(
    id: 'theme',
    name: '高级主题',
    createdAt: now,
    updatedAt: now,
    lightConfig: AppAdvancedThemeModeConfig(),
    darkConfig: AppAdvancedThemeModeConfig(),
  );
}

BottomNavIconGallery _bottomNavGallery({String id = 'bottom'}) {
  final now = DateTime.utc(2026);
  return BottomNavIconGallery(
    id: id,
    name: '默认底栏',
    createdAt: now,
    updatedAt: now,
    isBuiltIn: true,
    isEditable: false,
    isDeletable: false,
    items: const <BottomNavIconGalleryTab, BottomNavIconSet>{},
  );
}

CoverGallery _coverGallery({String id = 'cover'}) {
  final now = DateTime.utc(2026);
  return CoverGallery(
    id: id,
    name: '封面',
    createdAt: now,
    updatedAt: now,
    imagePaths: const <String>[],
  );
}

LaunchImageGallery _launchImageGallery({String id = 'launch'}) {
  final now = DateTime.utc(2026);
  return LaunchImageGallery(
    id: id,
    name: '启动图',
    createdAt: now,
    updatedAt: now,
    imagePaths: const <String>[],
  );
}
