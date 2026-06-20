import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/app_advanced_theme.dart';
import '../../../domain/entities/bottom_nav_icon_gallery.dart';
import '../../../domain/entities/cover_gallery.dart';
import '../../../domain/entities/launch_image_gallery.dart';
import '../../reader/application/reader_font_registry_service.dart';

part 'advanced_theme_editor_page_state.freezed.dart';

@freezed
abstract class AdvancedThemeEditorPageState
    with _$AdvancedThemeEditorPageState {
  const factory AdvancedThemeEditorPageState({
    AppAdvancedTheme? draft,
    @Default(AppAdvancedThemeMode.light) AppAdvancedThemeMode selectedMode,
    @Default(<String>[]) List<String> backgroundLibraryPaths,
    @Default(<String>[]) List<String> readerBackgroundLibraryPaths,
    @Default(<BottomNavIconGallery>[])
    List<BottomNavIconGallery> bottomNavGalleries,
    @Default(<CoverGallery>[]) List<CoverGallery> coverGalleries,
    @Default(<LaunchImageGallery>[])
    List<LaunchImageGallery> launchImageGalleries,
    @Default(<ReaderCustomFontEntry>[])
    List<ReaderCustomFontEntry> availableFonts,
    String? activeBottomNavGalleryName,
    @Default(true) bool strengthControlsExpanded,
    @Default(false) bool componentControlsExpanded,
    @Default(false) bool isEditingName,
    @Default(true) bool isLoading,
    @Default(false) bool isSaving,
  }) = _AdvancedThemeEditorPageState;
}

final advancedThemeEditorPageStateProvider = NotifierProvider.autoDispose<
  AdvancedThemeEditorPageStateNotifier,
  AdvancedThemeEditorPageState
>(AdvancedThemeEditorPageStateNotifier.new);

class AdvancedThemeEditorPageStateNotifier
    extends AutoDisposeNotifier<AdvancedThemeEditorPageState> {
  @override
  AdvancedThemeEditorPageState build() => const AdvancedThemeEditorPageState();

  void update(
    AdvancedThemeEditorPageState Function(AdvancedThemeEditorPageState) fn,
  ) {
    final next = fn(state);
    if (next != state) {
      state = next;
    }
  }
}
