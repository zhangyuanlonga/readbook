import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../../app/theme/app_theme_palette.dart';
import '../../../../../domain/entities/reader_settings.dart';
import '../../reader_page_support_models.dart';
import 'reader_theme_background_settings_section.dart';

class ReaderBackgroundSelectionState {
  const ReaderBackgroundSelectionState({
    required this.activeBackgroundValue,
    required this.hasBackgroundImage,
    required this.isPresetBackground,
  });

  final String? activeBackgroundValue;
  final bool hasBackgroundImage;
  final bool isPresetBackground;
}

class ReaderSettingsBackgroundTilesPresenter {
  const ReaderSettingsBackgroundTilesPresenter();

  ReaderBackgroundSelectionState resolveSelection({
    required String? activeBackgroundValue,
    required Iterable<String> presetValues,
  }) {
    final active = activeBackgroundValue?.trim();
    final hasBackgroundImage = active != null && active.isNotEmpty;
    return ReaderBackgroundSelectionState(
      activeBackgroundValue: active,
      hasBackgroundImage: hasBackgroundImage,
      isPresetBackground: hasBackgroundImage && presetValues.contains(active),
    );
  }

  List<ReaderBackgroundImageTileData> buildPresetTiles({
    required Iterable<ReaderBackgroundPreset> presets,
    required Map<String, Uint8List> presetBytes,
    required Map<String, String> presetBase64,
    required String? activeBackgroundValue,
    required ValueChanged<String> onSelectPreset,
  }) {
    final active = activeBackgroundValue?.trim();
    final tiles = <ReaderBackgroundImageTileData>[];
    for (final preset in presets) {
      final previewBytes = presetBytes[preset.assetPath];
      final presetValue = presetBase64[preset.assetPath];
      if (previewBytes == null) {
        continue;
      }
      tiles.add(
        ReaderBackgroundImageTileData(
          label: preset.label,
          selected:
              active == preset.assetPath ||
              (presetValue != null && active == presetValue),
          previewBytes: previewBytes,
          showLabel: false,
          onTap: () => onSelectPreset(preset.assetPath),
        ),
      );
    }
    return tiles;
  }

  List<ReaderBackgroundImageTileData> buildCustomTiles({
    required Iterable<String> customBackgrounds,
    required Map<String, Uint8List> customPreviewBytes,
    required ReaderBackgroundSelectionState selection,
    required ValueChanged<String> onSelectCustom,
  }) {
    final tiles = <ReaderBackgroundImageTileData>[];
    var index = 0;
    for (final source in customBackgrounds) {
      final previewBytes = customPreviewBytes[source];
      final isSelected =
          selection.hasBackgroundImage &&
          !selection.isPresetBackground &&
          selection.activeBackgroundValue == source;
      tiles.add(
        ReaderBackgroundImageTileData(
          label: '自定义${index + 1}',
          selected: isSelected,
          previewBytes: previewBytes,
          showLabel: true,
          icon: previewBytes == null ? Icons.broken_image_outlined : null,
          onTap: () => onSelectCustom(source),
        ),
      );
      index += 1;
    }
    return tiles;
  }
}

typedef ReaderBackgroundPreviewColorResolver =
    Color Function(ReaderThemeMode mode, ReaderSettings settings);

class ReaderSettingsBackgroundColorOptionsPresenter {
  const ReaderSettingsBackgroundColorOptionsPresenter();

  List<ReaderThemeBackgroundColorOption> build({
    required ReaderBackgroundPreviewColorResolver resolvePreviewColor,
  }) {
    return <ReaderThemeBackgroundColorOption>[
      _createColorOption(
        label: '明亮',
        mode: ReaderThemeMode.light,
        backgroundStyle: ReaderBackgroundStyle.plain,
        backgroundTone: ReaderBackgroundTone.surface,
        resolvePreviewColor: resolvePreviewColor,
      ),
      _createColorOption(
        label: '护眼',
        mode: ReaderThemeMode.sepia,
        backgroundStyle: ReaderBackgroundStyle.warm,
        backgroundTone: ReaderBackgroundTone.container,
        resolvePreviewColor: resolvePreviewColor,
      ),
      _createColorOption(
        label: '浅灰',
        mode: ReaderThemeMode.light,
        backgroundStyle: ReaderBackgroundStyle.paper,
        backgroundTone: ReaderBackgroundTone.containerHigh,
        resolvePreviewColor: resolvePreviewColor,
      ),
      _createThemePaletteOption(
        themeOption: appThemeFlameOrangeOption,
        backgroundTone: ReaderBackgroundTone.flameOrangeTint,
        resolvePreviewColor: resolvePreviewColor,
      ),
      _createThemePaletteOption(
        themeOption: appThemePineGreenOption,
        backgroundTone: ReaderBackgroundTone.pineGreenTint,
        resolvePreviewColor: resolvePreviewColor,
      ),
      _createThemePaletteOption(
        themeOption: appThemeSeaBlueOption,
        backgroundTone: ReaderBackgroundTone.seaBlueTint,
        resolvePreviewColor: resolvePreviewColor,
      ),
      _createThemePaletteOption(
        themeOption: appThemeNightPurpleOption,
        backgroundTone: ReaderBackgroundTone.nightPurpleTint,
        resolvePreviewColor: resolvePreviewColor,
      ),
      _createThemePaletteOption(
        themeOption: appThemeMistTealOption,
        backgroundTone: ReaderBackgroundTone.mistTealTint,
        resolvePreviewColor: resolvePreviewColor,
      ),
      _createThemePaletteOption(
        themeOption: appThemeBerryRoseOption,
        backgroundTone: ReaderBackgroundTone.berryRoseTint,
        resolvePreviewColor: resolvePreviewColor,
      ),
      _createThemePaletteOption(
        themeOption: appThemeAmberGoldOption,
        backgroundTone: ReaderBackgroundTone.amberGoldTint,
        resolvePreviewColor: resolvePreviewColor,
      ),
      _createColorOption(
        label: '夜间',
        mode: ReaderThemeMode.dark,
        backgroundStyle: ReaderBackgroundStyle.plain,
        backgroundTone: ReaderBackgroundTone.pureBlack,
        resolvePreviewColor: resolvePreviewColor,
      ),
    ];
  }

  ReaderThemeBackgroundColorOption _createColorOption({
    required String label,
    required ReaderThemeMode mode,
    required ReaderBackgroundStyle backgroundStyle,
    required ReaderBackgroundTone backgroundTone,
    required ReaderBackgroundPreviewColorResolver resolvePreviewColor,
  }) {
    final previewSettings = ReaderSettings(
      themeMode: mode,
      backgroundStyle: backgroundStyle,
      backgroundTone: backgroundTone,
    );
    return ReaderThemeBackgroundColorOption(
      label: label,
      previewColor: resolvePreviewColor(mode, previewSettings),
      mode: mode,
      backgroundStyle: backgroundStyle,
      backgroundTone: backgroundTone,
    );
  }

  ReaderThemeBackgroundColorOption _createThemePaletteOption({
    required AppThemeSeedOption themeOption,
    required ReaderBackgroundTone backgroundTone,
    required ReaderBackgroundPreviewColorResolver resolvePreviewColor,
  }) {
    return _createColorOption(
      label: themeOption.label,
      mode: ReaderThemeMode.light,
      backgroundStyle: ReaderBackgroundStyle.paper,
      backgroundTone: backgroundTone,
      resolvePreviewColor: resolvePreviewColor,
    );
  }
}

Color? readerPaletteSeedColorForTone(ReaderBackgroundTone tone) {
  return switch (tone) {
    ReaderBackgroundTone.flameOrangeTint => appThemeFlameOrangeOption.color,
    ReaderBackgroundTone.pineGreenTint => appThemePineGreenOption.color,
    ReaderBackgroundTone.seaBlueTint => appThemeSeaBlueOption.color,
    ReaderBackgroundTone.nightPurpleTint => appThemeNightPurpleOption.color,
    ReaderBackgroundTone.mistTealTint => appThemeMistTealOption.color,
    ReaderBackgroundTone.berryRoseTint => appThemeBerryRoseOption.color,
    ReaderBackgroundTone.amberGoldTint => appThemeAmberGoldOption.color,
    _ => null,
  };
}
