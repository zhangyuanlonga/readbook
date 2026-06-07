import '../../../domain/entities/app_advanced_theme.dart';
import '../../../domain/entities/bottom_nav_icon_gallery.dart';
import '../../../domain/entities/cover_gallery.dart';
import '../../../domain/entities/launch_image_gallery.dart';
import '../../reader/application/reader_font_registry_service.dart';
import 'advanced_theme_editor_page_state.dart';
import 'advanced_theme_editor_state_service.dart';

/// 高级主题编辑页状态 facade。
///
/// 页面仍负责 TextEditingController、弹层和动画；这里集中处理 draft、模式和资源列表
/// 的状态变更，避免后续拆分 section 时各自直接拼 provider update。
class AdvancedThemeEditorController {
  const AdvancedThemeEditorController();

  AdvancedThemeEditorPageState setDraft(
    AdvancedThemeEditorPageState state,
    AppAdvancedTheme? draft, {
    bool? isLoading,
  }) {
    return state.copyWith(
      draft: draft,
      isLoading: isLoading ?? state.isLoading,
    );
  }

  AdvancedThemeEditorPageState setSelectedMode(
    AdvancedThemeEditorPageState state,
    AppAdvancedThemeMode mode,
  ) {
    return state.copyWith(selectedMode: mode);
  }

  AdvancedThemeEditorPageState setSaving(
    AdvancedThemeEditorPageState state,
    bool isSaving,
  ) {
    return state.copyWith(isSaving: isSaving);
  }

  AdvancedThemeEditorPageState setLoading(
    AdvancedThemeEditorPageState state,
    bool isLoading,
  ) {
    return state.copyWith(isLoading: isLoading);
  }

  AdvancedThemeEditorPageState setEditingName(
    AdvancedThemeEditorPageState state,
    bool isEditingName,
  ) {
    return state.copyWith(isEditingName: isEditingName);
  }

  AdvancedThemeEditorPageState toggleStrengthControls(
    AdvancedThemeEditorPageState state,
  ) {
    return state.copyWith(
      strengthControlsExpanded: !state.strengthControlsExpanded,
    );
  }

  AdvancedThemeEditorPageState setStrengthControlsExpanded(
    AdvancedThemeEditorPageState state,
    bool value,
  ) {
    return state.copyWith(strengthControlsExpanded: value);
  }

  AdvancedThemeEditorPageState toggleComponentControls(
    AdvancedThemeEditorPageState state,
  ) {
    return state.copyWith(
      componentControlsExpanded: !state.componentControlsExpanded,
    );
  }

  AdvancedThemeEditorPageState setComponentControlsExpanded(
    AdvancedThemeEditorPageState state,
    bool value,
  ) {
    return state.copyWith(componentControlsExpanded: value);
  }

  AdvancedThemeEditorPageState applyAppearanceLinks(
    AdvancedThemeEditorPageState state,
    AdvancedThemeEditorAppearanceLinks links,
  ) {
    return state.copyWith(
      backgroundLibraryPaths: links.backgroundLibraryPaths.toList(
        growable: false,
      ),
      readerBackgroundLibraryPaths: links.readerBackgroundLibraryPaths.toList(
        growable: false,
      ),
      bottomNavGalleries: links.bottomNavGalleries.toList(growable: false),
      coverGalleries: links.coverGalleries.toList(growable: false),
      launchImageGalleries: links.launchImageGalleries.toList(growable: false),
      availableFonts: links.availableFonts.toList(growable: false),
      activeBottomNavGalleryName: links.activeBottomNavGalleryName,
    );
  }

  AdvancedThemeEditorPageState setBackgroundLibraryPaths(
    AdvancedThemeEditorPageState state,
    List<String> value,
  ) {
    return state.copyWith(
      backgroundLibraryPaths: value.toList(growable: false),
    );
  }

  AdvancedThemeEditorPageState setReaderBackgroundLibraryPaths(
    AdvancedThemeEditorPageState state,
    List<String> value,
  ) {
    return state.copyWith(
      readerBackgroundLibraryPaths: value.toList(growable: false),
    );
  }

  AdvancedThemeEditorPageState setBottomNavGalleries(
    AdvancedThemeEditorPageState state,
    List<BottomNavIconGallery> value,
  ) {
    return state.copyWith(bottomNavGalleries: value.toList(growable: false));
  }

  AdvancedThemeEditorPageState setCoverGalleries(
    AdvancedThemeEditorPageState state,
    List<CoverGallery> value,
  ) {
    return state.copyWith(coverGalleries: value.toList(growable: false));
  }

  AdvancedThemeEditorPageState setLaunchImageGalleries(
    AdvancedThemeEditorPageState state,
    List<LaunchImageGallery> value,
  ) {
    return state.copyWith(launchImageGalleries: value.toList(growable: false));
  }

  AdvancedThemeEditorPageState setAvailableFonts(
    AdvancedThemeEditorPageState state,
    List<ReaderCustomFontEntry> value,
  ) {
    return state.copyWith(availableFonts: value.toList(growable: false));
  }

  AdvancedThemeEditorPageState setActiveBottomNavGalleryName(
    AdvancedThemeEditorPageState state,
    String? value,
  ) {
    return state.copyWith(activeBottomNavGalleryName: value);
  }
}
