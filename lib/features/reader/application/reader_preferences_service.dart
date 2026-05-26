import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/managed_asset_store.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/reader_toc_snapshot.dart';
import '../../../domain/entities/reader_settings.dart';
import '../../../domain/entities/reading_progress.dart';

class ReaderPreferencesService {
  ReaderPreferencesService({
    SharedPreferences? preferences,
    ManagedAssetStore? assetStore,
    AppDatabase? database,
  }) : _preferencesFuture =
           preferences == null
               ? SharedPreferences.getInstance()
               : Future.value(preferences),
       _assetStore = assetStore ?? ManagedAssetStore(),
       _database = database ?? AppDatabase.instance;

  final Future<SharedPreferences> _preferencesFuture;
  final ManagedAssetStore _assetStore;
  final AppDatabase _database;

  static const String _fontSizeKey = 'reader.settings.fontSize';
  static const String _lineHeightKey = 'reader.settings.lineHeight';
  static const String _horizontalPaddingKey =
      'reader.settings.horizontalPadding';
  static const String _paragraphSpacingKey = 'reader.settings.paragraphSpacing';
  static const String _paragraphIndentKey = 'reader.settings.paragraphIndent';
  static const String _textFullJustifyEnabledKey =
      'reader.settings.textFullJustifyEnabled';
  static const String _textBottomJustifyEnabledKey =
      'reader.settings.textBottomJustifyEnabled';
  static const String _letterSpacingKey = 'reader.settings.letterSpacing';
  static const String _brightnessKey = 'reader.settings.brightness';
  static const String _followSystemBrightnessKey =
      'reader.settings.followSystemBrightness';
  static const String _themeModeKey = 'reader.settings.themeMode';
  static const String _pageTurnModeKey = 'reader.settings.pageTurnMode';
  static const String _volumeKeyPageEnabledKey =
      'reader.settings.volumeKeyPageEnabled';
  static const String _autoReadEnabledKey = 'reader.settings.autoReadEnabled';
  static const String _autoReadSpeedKey = 'reader.settings.autoReadSpeed';
  static const String _autoReadModeKey = 'reader.settings.autoReadMode';
  static const String _autoReadSpeedLevelKey =
      'reader.settings.autoReadSpeedLevel';
  static const String _autoReadPauseModeKey =
      'reader.settings.autoReadPauseMode';
  static const String _autoReadEndBehaviorKey =
      'reader.settings.autoReadEndBehavior';
  static const String _autoReadConfiguredKey =
      'reader.settings.autoReadConfigured.v1';
  static const String _toolbarHintShownKey =
      'reader.interaction.toolbarHintShown.v1';
  static const String _tapZoneGuideShownKey =
      'reader.interaction.tapZoneGuideShown.v1';
  static const String _backgroundStyleKey = 'reader.settings.backgroundStyle';
  static const String _backgroundToneKey = 'reader.settings.backgroundTone';
  static const String _pageTurnStepRatioKey =
      'reader.settings.pageTurnStepRatio';
  static const String _fontWeightLevelKey = 'reader.settings.fontWeightLevel';
  static const String _fontWeightValueKey = 'reader.settings.fontWeightValue';
  static const String _fontSourceKey = 'reader.settings.fontSource';
  static const String _systemFontPresetKey = 'reader.settings.systemFontPreset';
  static const String _fontFamilyKeyKey = 'reader.settings.fontFamilyKey';
  static const String _customFontPathKey = 'reader.settings.customFontPath';
  static const String _bodyTextItalicEnabledKey =
      'reader.settings.bodyTextItalicEnabled';
  static const String _bodyTextShadowEnabledKey =
      'reader.settings.bodyTextShadowEnabled';
  static const String _bodyTextShadowColorValueKey =
      'reader.settings.bodyTextShadowColorValue';
  static const String _bodyTextShadowBlurRadiusKey =
      'reader.settings.bodyTextShadowBlurRadius';
  static const String _bodyTextShadowOffsetDxKey =
      'reader.settings.bodyTextShadowOffsetDx';
  static const String _bodyTextShadowOffsetDyKey =
      'reader.settings.bodyTextShadowOffsetDy';
  static const String _pageAnimationStyleKey =
      'reader.settings.pageAnimationStyle';
  static const String _backgroundImageBase64Key =
      'reader.settings.backgroundImageBase64';
  static const String _bodyTextColorValueKey =
      'reader.settings.bodyTextColorValue';
  static const String _bodyTextDecorationStyleKey =
      'reader.settings.bodyTextDecorationStyle';
  static const String _bodyTextDecorationColorValueKey =
      'reader.settings.bodyTextDecorationColorValue';
  static const String _bodyTextUnderlineThicknessKey =
      'reader.settings.bodyTextUnderlineThickness';
  static const String _bodyTextUnderlineGapKey =
      'reader.settings.bodyTextUnderlineGap';
  static const String _bodyTextUnderlineDashLengthKey =
      'reader.settings.bodyTextUnderlineDashLength';
  static const String _bodyTextUnderlineDashGapRatioKey =
      'reader.settings.bodyTextUnderlineDashGapRatio';
  static const String _customBackgroundImagesKey =
      'reader.settings.customBackgroundImages';
  static const String _customBackgroundImageBase64Key =
      'reader.settings.customBackgroundImageBase64';
  static const String _recentBodyTextColorsKey =
      'reader.settings.recentBodyTextColors';
  static const String _mangaReadModeKey = 'reader.settings.mangaReadMode';
  static const String _mangaImageSpacingKey =
      'reader.settings.mangaImageSpacing';
  static const String _mangaImagePaddingKey =
      'reader.settings.mangaImagePadding';
  static const String _mangaLoadStrategyKey =
      'reader.settings.mangaLoadStrategy';
  static const String _switchSourceScoreRankingEnabledKey =
      'reader.settings.switchSourceScoreRankingEnabled';
  static const String _infoHeaderEnabledKey =
      'reader.settings.infoHeaderEnabled';
  static const String _infoFooterEnabledKey =
      'reader.settings.infoFooterEnabled';
  static const String _infoShowTimeKey = 'reader.settings.infoShowTime';
  static const String _infoShowBatteryKey = 'reader.settings.infoShowBattery';
  static const String _infoShowChapterKey = 'reader.settings.infoShowChapter';
  static const String _infoShowProgressKey = 'reader.settings.infoShowProgress';
  static const String _infoHeaderPaddingKey =
      'reader.settings.infoHeaderPadding';
  static const String _infoFooterPaddingKey =
      'reader.settings.infoFooterPadding';
  static const String _infoHeaderDividerEnabledKey =
      'reader.settings.infoHeaderDividerEnabled';
  static const String _infoFooterDividerEnabledKey =
      'reader.settings.infoFooterDividerEnabled';
  static const String _infoHeaderMarginTopKey =
      'reader.settings.infoHeaderMarginTop';
  static const String _infoHeaderMarginBottomKey =
      'reader.settings.infoHeaderMarginBottom';
  static const String _infoHeaderMarginLeftKey =
      'reader.settings.infoHeaderMarginLeft';
  static const String _infoHeaderMarginRightKey =
      'reader.settings.infoHeaderMarginRight';
  static const String _bodyMarginModeKey = 'reader.settings.bodyMarginMode';
  static const String _bodyMarginPresetKey = 'reader.settings.bodyMarginPreset';
  static const String _bodyMarginTopKey = 'reader.settings.bodyMarginTop';
  static const String _bodyMarginBottomKey = 'reader.settings.bodyMarginBottom';
  static const String _bodyMarginLeftKey = 'reader.settings.bodyMarginLeft';
  static const String _bodyMarginRightKey = 'reader.settings.bodyMarginRight';
  static const String _infoFooterMarginTopKey =
      'reader.settings.infoFooterMarginTop';
  static const String _infoFooterMarginBottomKey =
      'reader.settings.infoFooterMarginBottom';
  static const String _infoFooterMarginLeftKey =
      'reader.settings.infoFooterMarginLeft';
  static const String _infoFooterMarginRightKey =
      'reader.settings.infoFooterMarginRight';
  static const String _showChapterHeaderKey =
      'reader.settings.showChapterHeader';
  static const String _chapterHeaderHorizontalOffsetKey =
      'reader.settings.chapterHeaderHorizontalOffset';
  static const String _chapterHeaderVerticalOffsetKey =
      'reader.settings.chapterHeaderVerticalOffset';
  static const String _chapterHeaderModeKey =
      'reader.settings.chapterHeaderMode';
  static const String _chapterHeaderTopSpacingKey =
      'reader.settings.chapterHeaderTopSpacing';
  static const String _chapterHeaderBottomSpacingKey =
      'reader.settings.chapterHeaderBottomSpacing';
  static const String _pinnedChapterHeaderOffsetXKey =
      'reader.settings.pinnedChapterHeaderOffsetX';
  static const String _pinnedChapterHeaderOffsetYKey =
      'reader.settings.pinnedChapterHeaderOffsetY';
  static const String _progressPrefix = 'reader.progress.';
  static const String _tocSnapshotPrefix = 'reader.tocSnapshot.';

  Future<ReaderSettings> loadSettings() async {
    final prefs = await _preferencesFuture;

    final modeName = prefs.getString(_themeModeKey);
    final mode = ReaderThemeMode.values.firstWhere(
      (item) => item.name == modeName,
      orElse: () => ReaderThemeMode.light,
    );

    final pageTurnModeName = prefs.getString(_pageTurnModeKey);
    final pageTurnMode = ReaderPageTurnMode.values.firstWhere(
      (item) => item.name == pageTurnModeName,
      orElse: () => ReaderPageTurnMode.tapAndSwipe,
    );

    final autoReadModeName = prefs.getString(_autoReadModeKey);
    final autoReadMode = ReaderAutoReadMode.values.firstWhere(
      (item) => item.name == autoReadModeName,
      orElse: () => ReaderAutoReadMode.scroll,
    );
    final autoReadPauseModeName = prefs.getString(_autoReadPauseModeKey);
    final autoReadPauseMode = ReaderAutoReadPauseMode.values.firstWhere(
      (item) => item.name == autoReadPauseModeName,
      orElse: () => ReaderAutoReadPauseMode.none,
    );
    final autoReadEndBehaviorName = prefs.getString(_autoReadEndBehaviorKey);
    final autoReadEndBehavior = ReaderAutoReadEndBehavior.values.firstWhere(
      (item) => item.name == autoReadEndBehaviorName,
      orElse: () => ReaderAutoReadEndBehavior.stop,
    );

    final backgroundName = prefs.getString(_backgroundStyleKey);
    final backgroundStyle = ReaderBackgroundStyle.values.firstWhere(
      (item) => item.name == backgroundName,
      orElse: () => ReaderBackgroundStyle.plain,
    );

    final backgroundToneName = prefs.getString(_backgroundToneKey);
    final backgroundTone = normalizeReaderBackgroundTone(
      mode: mode,
      tone: ReaderBackgroundTone.values.firstWhere(
        (item) => item.name == backgroundToneName,
        orElse: () => ReaderBackgroundTone.surface,
      ),
    );

    final fontWeightName = prefs.getString(_fontWeightLevelKey);
    final fontWeightLevel = ReaderFontWeightLevel.values.firstWhere(
      (item) => item.name == fontWeightName,
      orElse: () => ReaderFontWeightLevel.regular,
    );

    final fontSourceName = prefs.getString(_fontSourceKey);
    final fontSource = ReaderFontSource.values.firstWhere(
      (item) => item.name == fontSourceName,
      orElse: () => ReaderFontSource.system,
    );
    final rawFontWeightValue = prefs.getInt(_fontWeightValueKey);
    final systemFontPresetName = prefs.getString(_systemFontPresetKey);
    final systemFontPreset = ReaderSystemFontPreset.values.firstWhere(
      (item) => item.name == systemFontPresetName,
      orElse: () => ReaderSystemFontPreset.defaultSans,
    );

    final animationName = prefs.getString(_pageAnimationStyleKey);
    final pageAnimationStyle = ReaderPageAnimationStyle.values.firstWhere(
      (item) => item.name == animationName,
      orElse: () => ReaderPageAnimationStyle.paperCurl,
    );
    final bodyTextDecorationStyleName = prefs.getString(
      _bodyTextDecorationStyleKey,
    );
    final bodyTextDecorationStyle = ReaderBodyTextDecorationStyle.values
        .firstWhere(
          (item) => item.name == bodyTextDecorationStyleName,
          orElse: () => ReaderBodyTextDecorationStyle.none,
        );

    final mangaReadModeName = prefs.getString(_mangaReadModeKey);
    final mangaReadMode = ReaderMangaReadMode.values.firstWhere(
      (item) => item.name == mangaReadModeName,
      orElse: () => ReaderMangaReadMode.continuous,
    );

    final mangaLoadStrategyName = prefs.getString(_mangaLoadStrategyKey);
    final mangaLoadStrategy = ReaderMangaLoadStrategy.values.firstWhere(
      (item) => item.name == mangaLoadStrategyName,
      orElse: () => ReaderMangaLoadStrategy.balanced,
    );
    final bodyMarginTop = _clampLayoutMargin(
      prefs.getDouble(_bodyMarginTopKey) ??
          const ReaderSettings().bodyMarginTop,
    );
    final bodyMarginBottom = _clampLayoutMargin(
      prefs.getDouble(_bodyMarginBottomKey) ??
          const ReaderSettings().bodyMarginBottom,
    );
    final bodyMarginLeft = _clampLayoutMargin(
      prefs.getDouble(_bodyMarginLeftKey) ??
          const ReaderSettings().bodyMarginLeft,
    );
    final bodyMarginRight = _clampLayoutMargin(
      prefs.getDouble(_bodyMarginRightKey) ??
          const ReaderSettings().bodyMarginRight,
    );

    final persistedCustomFontPath = prefs.getString(_customFontPathKey);
    final autoReadSpeed =
        (prefs.getDouble(_autoReadSpeedKey) ??
                ReaderSettings.defaultAutoReadSpeed)
            .clamp(
              ReaderSettings.minAutoReadSpeed,
              ReaderSettings.maxAutoReadSpeed,
            )
            .toDouble();
    return ReaderSettings(
      fontSize: prefs.getDouble(_fontSizeKey) ?? 18,
      lineHeight: prefs.getDouble(_lineHeightKey) ?? 1.7,
      horizontalPadding: ((bodyMarginLeft + bodyMarginRight) / 2).toDouble(),
      paragraphSpacing: prefs.getDouble(_paragraphSpacingKey) ?? 14,
      paragraphIndent: prefs.getDouble(_paragraphIndentKey) ?? 0,
      textFullJustifyEnabled: prefs.getBool(_textFullJustifyEnabledKey) ?? true,
      textBottomJustifyEnabled:
          prefs.getBool(_textBottomJustifyEnabledKey) ?? true,
      letterSpacing:
          (prefs.getDouble(_letterSpacingKey) ??
                  ReaderSettings.defaultLetterSpacing)
              .clamp(
                ReaderSettings.minLetterSpacing,
                ReaderSettings.maxLetterSpacing,
              )
              .toDouble(),
      brightness: (prefs.getDouble(_brightnessKey) ?? 1).clamp(0.2, 1.0),
      followSystemBrightness: prefs.getBool(_followSystemBrightnessKey) ?? true,
      themeMode: mode,
      pageTurnMode: pageTurnMode,
      volumeKeyPageEnabled: prefs.getBool(_volumeKeyPageEnabledKey) ?? true,
      autoReadEnabled: prefs.getBool(_autoReadEnabledKey) ?? false,
      autoReadSpeed: autoReadSpeed,
      autoReadMode: autoReadMode,
      autoReadSpeedLevel:
          (prefs.getInt(_autoReadSpeedLevelKey) ??
                  ReaderSettings.autoReadSpeedLevelFromSpeed(autoReadSpeed))
              .clamp(
                ReaderSettings.minAutoReadSpeedLevel,
                ReaderSettings.maxAutoReadSpeedLevel,
              )
              .toInt(),
      autoReadPauseMode: autoReadPauseMode,
      autoReadEndBehavior: autoReadEndBehavior,
      backgroundStyle: backgroundStyle,
      backgroundTone: backgroundTone,
      pageTurnStepRatio: (prefs.getDouble(_pageTurnStepRatioKey) ?? 0.88).clamp(
        0.6,
        1.0,
      ),
      fontWeightLevel: fontWeightLevel,
      fontWeightValue:
          rawFontWeightValue
              ?.clamp(
                ReaderSettings.minFontWeightValue,
                ReaderSettings.maxFontWeightValue,
              )
              .toInt(),
      fontSource: fontSource,
      systemFontPreset: systemFontPreset,
      fontFamilyKey: prefs.getString(_fontFamilyKeyKey),
      customFontPath:
          await _assetStore.resolvePersistedPath(persistedCustomFontPath) ??
          persistedCustomFontPath,
      bodyTextItalicEnabled: prefs.getBool(_bodyTextItalicEnabledKey) ?? false,
      bodyTextShadowEnabled: prefs.getBool(_bodyTextShadowEnabledKey) ?? false,
      bodyTextShadowColorValue: prefs.getInt(_bodyTextShadowColorValueKey),
      bodyTextShadowBlurRadius:
          (prefs.getDouble(_bodyTextShadowBlurRadiusKey) ?? 0).clamp(0, 32),
      bodyTextShadowOffsetDx: (prefs.getDouble(_bodyTextShadowOffsetDxKey) ?? 0)
          .clamp(-24, 24),
      bodyTextShadowOffsetDy: (prefs.getDouble(_bodyTextShadowOffsetDyKey) ?? 0)
          .clamp(-24, 24),
      pageAnimationStyle: pageAnimationStyle,
      backgroundImageBase64: prefs.getString(_backgroundImageBase64Key),
      bodyTextColorValue: prefs.getInt(_bodyTextColorValueKey),
      bodyTextDecorationStyle: bodyTextDecorationStyle,
      bodyTextDecorationColorValue: prefs.getInt(
        _bodyTextDecorationColorValueKey,
      ),
      bodyTextUnderlineThickness:
          (prefs.getDouble(_bodyTextUnderlineThicknessKey) ?? 2.2).clamp(1, 10),
      bodyTextUnderlineGap: (prefs.getDouble(_bodyTextUnderlineGapKey) ?? 2)
          .clamp(0, 16),
      bodyTextUnderlineDashLength:
          (prefs.getDouble(_bodyTextUnderlineDashLengthKey) ?? 6).clamp(1, 24),
      bodyTextUnderlineDashGapRatio:
          (prefs.getDouble(_bodyTextUnderlineDashGapRatioKey) ?? 6).clamp(
            1,
            12,
          ),
      mangaReadMode: mangaReadMode,
      mangaImageSpacing: (prefs.getDouble(_mangaImageSpacingKey) ?? 10).clamp(
        0,
        24,
      ),
      mangaImagePadding: (prefs.getDouble(_mangaImagePaddingKey) ?? 8).clamp(
        0,
        24,
      ),
      mangaLoadStrategy: mangaLoadStrategy,
      switchSourceScoreRankingEnabled:
          prefs.getBool(_switchSourceScoreRankingEnabledKey) ?? true,
      infoHeaderEnabled: prefs.getBool(_infoHeaderEnabledKey) ?? false,
      infoFooterEnabled: prefs.getBool(_infoFooterEnabledKey) ?? false,
      infoShowTime: prefs.getBool(_infoShowTimeKey) ?? true,
      infoShowBattery: prefs.getBool(_infoShowBatteryKey) ?? false,
      infoShowChapter: prefs.getBool(_infoShowChapterKey) ?? false,
      infoShowProgress: prefs.getBool(_infoShowProgressKey) ?? true,
      infoHeaderPadding:
          (prefs.getDouble(_infoHeaderPaddingKey) ?? 8)
              .clamp(
                ReaderSettings.minInfoBarPadding,
                ReaderSettings.maxInfoBarPadding,
              )
              .toDouble(),
      infoFooterPadding:
          (prefs.getDouble(_infoFooterPaddingKey) ?? 8)
              .clamp(
                ReaderSettings.minInfoBarPadding,
                ReaderSettings.maxInfoBarPadding,
              )
              .toDouble(),
      infoHeaderDividerEnabled:
          prefs.getBool(_infoHeaderDividerEnabledKey) ?? false,
      infoFooterDividerEnabled:
          prefs.getBool(_infoFooterDividerEnabledKey) ?? false,
      infoHeaderMarginTop:
          (prefs.getDouble(_infoHeaderMarginTopKey) ?? 0)
              .clamp(
                ReaderSettings.minLayoutMargin,
                ReaderSettings.maxLayoutMargin,
              )
              .toDouble(),
      infoHeaderMarginBottom:
          (prefs.getDouble(_infoHeaderMarginBottomKey) ?? 0)
              .clamp(
                ReaderSettings.minLayoutMargin,
                ReaderSettings.maxLayoutMargin,
              )
              .toDouble(),
      infoHeaderMarginLeft:
          (prefs.getDouble(_infoHeaderMarginLeftKey) ??
                  const ReaderSettings().infoHeaderMarginLeft)
              .clamp(
                ReaderSettings.minLayoutMargin,
                ReaderSettings.maxLayoutMargin,
              )
              .toDouble(),
      infoHeaderMarginRight:
          (prefs.getDouble(_infoHeaderMarginRightKey) ??
                  const ReaderSettings().infoHeaderMarginRight)
              .clamp(
                ReaderSettings.minLayoutMargin,
                ReaderSettings.maxLayoutMargin,
              )
              .toDouble(),
      bodyMarginTop: bodyMarginTop,
      bodyMarginBottom: bodyMarginBottom,
      bodyMarginLeft: bodyMarginLeft,
      bodyMarginRight: bodyMarginRight,
      infoFooterMarginTop:
          (prefs.getDouble(_infoFooterMarginTopKey) ?? 0)
              .clamp(
                ReaderSettings.minLayoutMargin,
                ReaderSettings.maxLayoutMargin,
              )
              .toDouble(),
      infoFooterMarginBottom:
          (prefs.getDouble(_infoFooterMarginBottomKey) ?? 0)
              .clamp(
                ReaderSettings.minLayoutMargin,
                ReaderSettings.maxLayoutMargin,
              )
              .toDouble(),
      infoFooterMarginLeft:
          (prefs.getDouble(_infoFooterMarginLeftKey) ??
                  const ReaderSettings().infoFooterMarginLeft)
              .clamp(
                ReaderSettings.minLayoutMargin,
                ReaderSettings.maxInfoFooterHorizontalMargin,
              )
              .toDouble(),
      infoFooterMarginRight:
          (prefs.getDouble(_infoFooterMarginRightKey) ??
                  const ReaderSettings().infoFooterMarginRight)
              .clamp(
                ReaderSettings.minLayoutMargin,
                ReaderSettings.maxInfoFooterHorizontalMargin,
              )
              .toDouble(),
      showChapterHeader:
          prefs.getBool(_showChapterHeaderKey) ??
          const ReaderSettings().showChapterHeader,
      chapterHeaderHorizontalOffset:
          (prefs.getDouble(_chapterHeaderHorizontalOffsetKey) ??
                  const ReaderSettings().chapterHeaderHorizontalOffset)
              .clamp(
                ReaderSettings.minPinnedHeaderOffsetX,
                ReaderSettings.maxPinnedHeaderOffsetX,
              )
              .toDouble(),
      chapterHeaderVerticalOffset:
          (prefs.getDouble(_chapterHeaderVerticalOffsetKey) ??
                  const ReaderSettings().chapterHeaderVerticalOffset)
              .clamp(
                ReaderSettings.minChapterHeaderVerticalOffset,
                ReaderSettings.maxChapterHeaderSpacing,
              )
              .toDouble(),
    );
  }

  Future<void> saveSettings(ReaderSettings settings) async {
    final prefs = await _preferencesFuture;

    await prefs.setDouble(_fontSizeKey, settings.fontSize);
    await prefs.setDouble(_lineHeightKey, settings.lineHeight);
    await prefs.setDouble(_paragraphSpacingKey, settings.paragraphSpacing);
    await prefs.setDouble(_paragraphIndentKey, settings.paragraphIndent);
    await prefs.setBool(
      _textFullJustifyEnabledKey,
      settings.textFullJustifyEnabled,
    );
    await prefs.setBool(
      _textBottomJustifyEnabledKey,
      settings.textBottomJustifyEnabled,
    );
    await prefs.setDouble(_letterSpacingKey, settings.letterSpacing);
    await prefs.setDouble(_brightnessKey, settings.brightness);
    await prefs.setBool(
      _followSystemBrightnessKey,
      settings.followSystemBrightness,
    );
    await prefs.setString(_themeModeKey, settings.themeMode.name);
    await prefs.setString(_pageTurnModeKey, settings.pageTurnMode.name);
    await prefs.setBool(
      _volumeKeyPageEnabledKey,
      settings.volumeKeyPageEnabled,
    );
    await prefs.setBool(_autoReadEnabledKey, settings.autoReadEnabled);
    await prefs.setDouble(_autoReadSpeedKey, settings.autoReadSpeed);
    await prefs.setString(_autoReadModeKey, settings.autoReadMode.name);
    await prefs.setInt(_autoReadSpeedLevelKey, settings.autoReadSpeedLevel);
    await prefs.setString(
      _autoReadPauseModeKey,
      settings.autoReadPauseMode.name,
    );
    await prefs.setString(
      _autoReadEndBehaviorKey,
      settings.autoReadEndBehavior.name,
    );
    await prefs.setString(_backgroundStyleKey, settings.backgroundStyle.name);
    await prefs.setString(_backgroundToneKey, settings.backgroundTone.name);
    await prefs.setDouble(_pageTurnStepRatioKey, settings.pageTurnStepRatio);
    await prefs.setString(_fontWeightLevelKey, settings.fontWeightLevel.name);
    final fontWeightValue = settings.fontWeightValue;
    if (fontWeightValue == null) {
      await prefs.remove(_fontWeightValueKey);
    } else {
      await prefs.setInt(_fontWeightValueKey, fontWeightValue);
    }
    await prefs.setString(_fontSourceKey, settings.fontSource.name);
    await prefs.setString(_systemFontPresetKey, settings.systemFontPreset.name);
    final fontFamilyKey = settings.fontFamilyKey;
    if (fontFamilyKey == null || fontFamilyKey.isEmpty) {
      await prefs.remove(_fontFamilyKeyKey);
    } else {
      await prefs.setString(_fontFamilyKeyKey, fontFamilyKey);
    }
    final customFontPath = settings.customFontPath;
    if (customFontPath == null || customFontPath.isEmpty) {
      await prefs.remove(_customFontPathKey);
    } else {
      await prefs.setString(
        _customFontPathKey,
        await _assetStore.relativizePersistedPath(customFontPath) ??
            customFontPath,
      );
    }
    await prefs.setBool(
      _bodyTextItalicEnabledKey,
      settings.bodyTextItalicEnabled,
    );
    await prefs.setBool(
      _bodyTextShadowEnabledKey,
      settings.bodyTextShadowEnabled,
    );
    final bodyTextShadowColorValue = settings.bodyTextShadowColorValue;
    if (bodyTextShadowColorValue == null) {
      await prefs.remove(_bodyTextShadowColorValueKey);
    } else {
      await prefs.setInt(
        _bodyTextShadowColorValueKey,
        bodyTextShadowColorValue,
      );
    }
    await prefs.setDouble(
      _bodyTextShadowBlurRadiusKey,
      settings.bodyTextShadowBlurRadius,
    );
    await prefs.setDouble(
      _bodyTextShadowOffsetDxKey,
      settings.bodyTextShadowOffsetDx,
    );
    await prefs.setDouble(
      _bodyTextShadowOffsetDyKey,
      settings.bodyTextShadowOffsetDy,
    );
    await prefs.setDouble(
      _bodyTextUnderlineThicknessKey,
      settings.bodyTextUnderlineThickness,
    );
    await prefs.setDouble(
      _bodyTextUnderlineGapKey,
      settings.bodyTextUnderlineGap,
    );
    await prefs.setDouble(
      _bodyTextUnderlineDashLengthKey,
      settings.bodyTextUnderlineDashLength,
    );
    await prefs.setDouble(
      _bodyTextUnderlineDashGapRatioKey,
      settings.bodyTextUnderlineDashGapRatio,
    );
    await prefs.setString(
      _pageAnimationStyleKey,
      settings.pageAnimationStyle.name,
    );
    await prefs.setString(_mangaReadModeKey, settings.mangaReadMode.name);
    await prefs.setDouble(_mangaImageSpacingKey, settings.mangaImageSpacing);
    await prefs.setDouble(_mangaImagePaddingKey, settings.mangaImagePadding);
    await prefs.setString(
      _mangaLoadStrategyKey,
      settings.mangaLoadStrategy.name,
    );
    await prefs.setBool(
      _switchSourceScoreRankingEnabledKey,
      settings.switchSourceScoreRankingEnabled,
    );
    await prefs.setBool(_infoHeaderEnabledKey, settings.infoHeaderEnabled);
    await prefs.setBool(_infoFooterEnabledKey, settings.infoFooterEnabled);
    await prefs.setBool(_infoShowTimeKey, settings.infoShowTime);
    await prefs.setBool(_infoShowBatteryKey, settings.infoShowBattery);
    await prefs.setBool(_infoShowChapterKey, settings.infoShowChapter);
    await prefs.setBool(_infoShowProgressKey, settings.infoShowProgress);
    await prefs.setDouble(_infoHeaderPaddingKey, settings.infoHeaderPadding);
    await prefs.setDouble(_infoFooterPaddingKey, settings.infoFooterPadding);
    await prefs.setBool(
      _infoHeaderDividerEnabledKey,
      settings.infoHeaderDividerEnabled,
    );
    await prefs.setBool(
      _infoFooterDividerEnabledKey,
      settings.infoFooterDividerEnabled,
    );
    await prefs.setDouble(
      _infoHeaderMarginTopKey,
      settings.infoHeaderMarginTop,
    );
    await prefs.setDouble(
      _infoHeaderMarginBottomKey,
      settings.infoHeaderMarginBottom,
    );
    await prefs.setDouble(
      _infoHeaderMarginLeftKey,
      settings.infoHeaderMarginLeft,
    );
    await prefs.setDouble(
      _infoHeaderMarginRightKey,
      settings.infoHeaderMarginRight,
    );
    await prefs.setDouble(_bodyMarginTopKey, settings.bodyMarginTop);
    await prefs.setDouble(_bodyMarginBottomKey, settings.bodyMarginBottom);
    await prefs.setDouble(_bodyMarginLeftKey, settings.bodyMarginLeft);
    await prefs.setDouble(_bodyMarginRightKey, settings.bodyMarginRight);
    await prefs.remove(_horizontalPaddingKey);
    await prefs.remove(_bodyMarginModeKey);
    await prefs.remove(_bodyMarginPresetKey);
    await prefs.setDouble(
      _infoFooterMarginTopKey,
      settings.infoFooterMarginTop,
    );
    await prefs.setDouble(
      _infoFooterMarginBottomKey,
      settings.infoFooterMarginBottom,
    );
    await prefs.setDouble(
      _infoFooterMarginLeftKey,
      settings.infoFooterMarginLeft,
    );
    await prefs.setDouble(
      _infoFooterMarginRightKey,
      settings.infoFooterMarginRight,
    );
    await prefs.setBool(_showChapterHeaderKey, settings.showChapterHeader);
    await prefs.setDouble(
      _chapterHeaderHorizontalOffsetKey,
      settings.chapterHeaderHorizontalOffset,
    );
    await prefs.setDouble(
      _chapterHeaderVerticalOffsetKey,
      settings.chapterHeaderVerticalOffset,
    );
    await prefs.remove(_chapterHeaderModeKey);
    await prefs.remove(_chapterHeaderTopSpacingKey);
    await prefs.remove(_chapterHeaderBottomSpacingKey);
    await prefs.remove(_pinnedChapterHeaderOffsetXKey);
    await prefs.remove(_pinnedChapterHeaderOffsetYKey);
    final backgroundImageBase64 = settings.backgroundImageBase64;
    if (backgroundImageBase64 == null || backgroundImageBase64.isEmpty) {
      await prefs.remove(_backgroundImageBase64Key);
    } else {
      await prefs.setString(_backgroundImageBase64Key, backgroundImageBase64);
    }
    final bodyTextColorValue = settings.bodyTextColorValue;
    if (bodyTextColorValue == null) {
      await prefs.remove(_bodyTextColorValueKey);
    } else {
      await prefs.setInt(_bodyTextColorValueKey, bodyTextColorValue);
    }
    await prefs.setString(
      _bodyTextDecorationStyleKey,
      settings.bodyTextDecorationStyle.name,
    );
    final bodyTextDecorationColorValue = settings.bodyTextDecorationColorValue;
    if (bodyTextDecorationColorValue == null) {
      await prefs.remove(_bodyTextDecorationColorValueKey);
    } else {
      await prefs.setInt(
        _bodyTextDecorationColorValueKey,
        bodyTextDecorationColorValue,
      );
    }
  }

  Future<bool> loadAutoReadConfigured() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_autoReadConfiguredKey) ?? false;
  }

  Future<void> saveAutoReadConfigured(bool configured) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_autoReadConfiguredKey, configured);
  }

  Future<bool> loadToolbarHintShown() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_toolbarHintShownKey) ?? false;
  }

  Future<void> saveToolbarHintShown(bool shown) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_toolbarHintShownKey, shown);
  }

  Future<bool> loadTapZoneGuideShown() async {
    final prefs = await _preferencesFuture;
    return prefs.getBool(_tapZoneGuideShownKey) ?? false;
  }

  Future<void> saveTapZoneGuideShown(bool shown) async {
    final prefs = await _preferencesFuture;
    await prefs.setBool(_tapZoneGuideShownKey, shown);
  }

  Future<List<String>> loadCustomBackgroundImages() async {
    final prefs = await _preferencesFuture;
    final rawList = prefs.getString(_customBackgroundImagesKey);
    final results = <String>[];

    if (rawList != null && rawList.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawList);
        if (decoded is List) {
          for (final entry in decoded) {
            final value = entry?.toString().trim();
            if (value == null || value.isEmpty) {
              continue;
            }
            if (!results.contains(value)) {
              results.add(value);
            }
          }
        }
      } catch (_) {
        return const <String>[];
      }
    }

    return results;
  }

  Future<void> migrateProgress({
    required String previousBookId,
    required ReadingProgress nextProgress,
    bool removePrevious = true,
  }) async {
    final normalizedPreviousBookId = previousBookId.trim();
    if (normalizedPreviousBookId.isEmpty) {
      await saveProgress(nextProgress);
      return;
    }

    await _database.upsertReadingProgress(nextProgress);
    final prefs = await _preferencesFuture;
    await prefs.remove('$_progressPrefix${nextProgress.bookId}');
    if (removePrevious && normalizedPreviousBookId != nextProgress.bookId) {
      await _database.deleteReadingProgress(normalizedPreviousBookId);
      await prefs.remove('$_progressPrefix$normalizedPreviousBookId');
    }
  }

  Future<void> saveCustomBackgroundImages(List<String> images) async {
    final prefs = await _preferencesFuture;
    final normalized = <String>[];

    for (final entry in images) {
      final value = entry.trim();
      if (value.isEmpty) {
        continue;
      }
      if (!normalized.contains(value)) {
        normalized.add(value);
      }
    }

    if (normalized.isEmpty) {
      await prefs.remove(_customBackgroundImagesKey);
      await prefs.remove(_customBackgroundImageBase64Key);
      return;
    }

    await prefs.setString(_customBackgroundImagesKey, jsonEncode(normalized));
    await prefs.remove(_customBackgroundImageBase64Key);
  }

  Future<List<int>> loadRecentBodyTextColors() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_recentBodyTextColorsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <int>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <int>[];
      }
      final results = <int>[];
      for (final entry in decoded) {
        int? value;
        if (entry is int) {
          value = entry;
        } else if (entry is num) {
          value = entry.toInt();
        } else if (entry is String) {
          value = int.tryParse(entry.trim());
        }
        if (value == null || results.contains(value)) {
          continue;
        }
        results.add(value);
      }
      return results;
    } catch (_) {
      return const <int>[];
    }
  }

  Future<void> saveRecentBodyTextColors(List<int> colors) async {
    final prefs = await _preferencesFuture;
    final normalized = <int>[];
    for (final color in colors) {
      if (!normalized.contains(color)) {
        normalized.add(color);
      }
    }
    if (normalized.isEmpty) {
      await prefs.remove(_recentBodyTextColorsKey);
      return;
    }
    await prefs.setString(_recentBodyTextColorsKey, jsonEncode(normalized));
  }

  Future<ReadingProgress?> loadProgress(String bookId) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return null;
    }

    final stored = await _database.getReadingProgressByBookId(normalizedBookId);
    if (stored != null) {
      return stored;
    }

    final prefs = await _preferencesFuture;
    final raw = prefs.getString('$_progressPrefix$normalizedBookId');
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }

      final progress = ReadingProgress.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      await _database.upsertReadingProgress(progress);
      await prefs.remove('$_progressPrefix$normalizedBookId');
      return progress;
    } on FormatException {
      return null;
    }
  }

  Future<void> saveProgress(ReadingProgress progress) async {
    await _database.upsertReadingProgress(progress);
    final prefs = await _preferencesFuture;
    await prefs.remove('$_progressPrefix${progress.bookId}');
  }

  Future<void> deleteProgress(String bookId) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return;
    }

    await _database.deleteReadingProgress(normalizedBookId);
    final prefs = await _preferencesFuture;
    await prefs.remove('$_progressPrefix$normalizedBookId');
  }

  Future<List<ReadingProgress>> loadAllProgresses() async {
    final databaseItems = await _database.listReadingProgresses();
    final prefs = await _preferencesFuture;
    final results = <String, ReadingProgress>{
      for (final item in databaseItems) item.bookId.trim(): item,
    };
    final migratedLegacyKeys = <String>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_progressPrefix)) {
        continue;
      }
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          continue;
        }
        final progress = ReadingProgress.fromJson(
          decoded.map(
            (nestedKey, value) => MapEntry(nestedKey.toString(), value),
          ),
        );
        results[progress.bookId.trim()] = progress;
        migratedLegacyKeys.add(key);
        await _database.upsertReadingProgress(progress);
      } on FormatException {
        continue;
      }
    }
    for (final key in migratedLegacyKeys) {
      await prefs.remove(key);
    }
    final sorted = results.values.toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<ReadingProgress>.unmodifiable(sorted);
  }

  Future<ReaderTocSnapshot?> loadTocSnapshot({
    required String sourceId,
    required String detailUrl,
  }) async {
    final key = _buildTocSnapshotKey(sourceId: sourceId, detailUrl: detailUrl);
    if (key == null) {
      return null;
    }

    final databaseSnapshot = await _database.getTocSnapshot(
      '${sourceId.trim()}|${detailUrl.trim()}',
    );
    if (databaseSnapshot != null) {
      return databaseSnapshot;
    }

    final prefs = await _preferencesFuture;
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }

      final snapshot = ReaderTocSnapshot.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      await _database.upsertTocSnapshot(snapshot);
      await prefs.remove(key);
      return snapshot;
    } on FormatException {
      return null;
    }
  }

  Future<void> saveTocSnapshot(ReaderTocSnapshot snapshot) async {
    if (snapshot.chapters.isEmpty) {
      return;
    }

    final key = _buildTocSnapshotKey(
      sourceId: snapshot.sourceId,
      detailUrl: snapshot.detailUrl,
    );
    if (key == null) {
      return;
    }

    await _database.upsertTocSnapshot(snapshot);
    final prefs = await _preferencesFuture;
    await prefs.remove(key);
  }

  String? _buildTocSnapshotKey({
    required String sourceId,
    required String detailUrl,
  }) {
    final normalizedSourceId = sourceId.trim();
    final normalizedDetailUrl = detailUrl.trim();
    if (normalizedSourceId.isEmpty || normalizedDetailUrl.isEmpty) {
      return null;
    }
    return '$_tocSnapshotPrefix$normalizedSourceId|$normalizedDetailUrl';
  }

  double _clampLayoutMargin(double value) {
    return value
        .clamp(ReaderSettings.minLayoutMargin, ReaderSettings.maxLayoutMargin)
        .toDouble();
  }
}
