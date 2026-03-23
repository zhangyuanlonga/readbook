import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/reader_toc_snapshot.dart';
import '../../../domain/entities/reader_settings.dart';
import '../../../domain/entities/reading_progress.dart';

class ReaderPreferencesService {
  ReaderPreferencesService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  static const String _fontSizeKey = 'reader.settings.fontSize';
  static const String _lineHeightKey = 'reader.settings.lineHeight';
  static const String _horizontalPaddingKey =
      'reader.settings.horizontalPadding';
  static const String _paragraphSpacingKey = 'reader.settings.paragraphSpacing';
  static const String _paragraphIndentKey = 'reader.settings.paragraphIndent';
  static const String _textFullJustifyEnabledKey =
      'reader.settings.textFullJustifyEnabled';
  static const String _letterSpacingKey = 'reader.settings.letterSpacing';
  static const String _brightnessKey = 'reader.settings.brightness';
  static const String _themeModeKey = 'reader.settings.themeMode';
  static const String _pageTurnModeKey = 'reader.settings.pageTurnMode';
  static const String _volumeKeyPageEnabledKey =
      'reader.settings.volumeKeyPageEnabled';
  static const String _autoReadEnabledKey = 'reader.settings.autoReadEnabled';
  static const String _autoReadSpeedKey = 'reader.settings.autoReadSpeed';
  static const String _backgroundStyleKey = 'reader.settings.backgroundStyle';
  static const String _backgroundToneKey = 'reader.settings.backgroundTone';
  static const String _pageTurnStepRatioKey =
      'reader.settings.pageTurnStepRatio';
  static const String _fontWeightLevelKey = 'reader.settings.fontWeightLevel';
  static const String _fontSourceKey = 'reader.settings.fontSource';
  static const String _fontFamilyKeyKey = 'reader.settings.fontFamilyKey';
  static const String _customFontPathKey = 'reader.settings.customFontPath';
  static const String _pageAnimationStyleKey =
      'reader.settings.pageAnimationStyle';
  static const String _backgroundImageBase64Key =
      'reader.settings.backgroundImageBase64';
  static const String _customBackgroundImagesKey =
      'reader.settings.customBackgroundImages';
  static const String _customBackgroundImageBase64Key =
      'reader.settings.customBackgroundImageBase64';
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

    final backgroundName = prefs.getString(_backgroundStyleKey);
    final backgroundStyle = ReaderBackgroundStyle.values.firstWhere(
      (item) => item.name == backgroundName,
      orElse: () => ReaderBackgroundStyle.plain,
    );

    final backgroundToneName = prefs.getString(_backgroundToneKey);
    final backgroundTone = ReaderBackgroundTone.values.firstWhere(
      (item) => item.name == backgroundToneName,
      orElse: () => ReaderBackgroundTone.surface,
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

    final animationName = prefs.getString(_pageAnimationStyleKey);
    final pageAnimationStyle = ReaderPageAnimationStyle.values.firstWhere(
      (item) => item.name == animationName,
      orElse: () => ReaderPageAnimationStyle.curl,
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

    final legacyHorizontalPadding =
        prefs.getDouble(_horizontalPaddingKey) ?? 18;
    final bodyMarginLeft =
        (prefs.getDouble(_bodyMarginLeftKey) ?? legacyHorizontalPadding)
            .clamp(
              ReaderSettings.minLayoutMargin,
              ReaderSettings.maxLayoutMargin,
            )
            .toDouble();
    final bodyMarginRight =
        (prefs.getDouble(_bodyMarginRightKey) ?? legacyHorizontalPadding)
            .clamp(
              ReaderSettings.minLayoutMargin,
              ReaderSettings.maxLayoutMargin,
            )
            .toDouble();

    return ReaderSettings(
      fontSize: prefs.getDouble(_fontSizeKey) ?? 18,
      lineHeight: prefs.getDouble(_lineHeightKey) ?? 1.7,
      horizontalPadding: ((bodyMarginLeft + bodyMarginRight) / 2).toDouble(),
      paragraphSpacing: prefs.getDouble(_paragraphSpacingKey) ?? 14,
      paragraphIndent: prefs.getDouble(_paragraphIndentKey) ?? 0,
      textFullJustifyEnabled:
          prefs.getBool(_textFullJustifyEnabledKey) ?? false,
      letterSpacing:
          (prefs.getDouble(_letterSpacingKey) ??
                  ReaderSettings.defaultLetterSpacing)
              .clamp(
                ReaderSettings.minLetterSpacing,
                ReaderSettings.maxLetterSpacing,
              )
              .toDouble(),
      brightness: (prefs.getDouble(_brightnessKey) ?? 1).clamp(0.2, 1.0),
      themeMode: mode,
      pageTurnMode: pageTurnMode,
      volumeKeyPageEnabled: prefs.getBool(_volumeKeyPageEnabledKey) ?? false,
      autoReadEnabled: prefs.getBool(_autoReadEnabledKey) ?? false,
      autoReadSpeed:
          (prefs.getDouble(_autoReadSpeedKey) ??
                  ReaderSettings.defaultAutoReadSpeed)
              .clamp(
                ReaderSettings.minAutoReadSpeed,
                ReaderSettings.maxAutoReadSpeed,
              )
              .toDouble(),
      backgroundStyle: backgroundStyle,
      backgroundTone: backgroundTone,
      pageTurnStepRatio: (prefs.getDouble(_pageTurnStepRatioKey) ?? 0.88).clamp(
        0.6,
        1.0,
      ),
      fontWeightLevel: fontWeightLevel,
      fontSource: fontSource,
      fontFamilyKey: prefs.getString(_fontFamilyKeyKey),
      customFontPath: prefs.getString(_customFontPathKey),
      pageAnimationStyle: pageAnimationStyle,
      backgroundImageBase64: prefs.getString(_backgroundImageBase64Key),
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
          (prefs.getDouble(_infoHeaderMarginLeftKey) ?? legacyHorizontalPadding)
              .clamp(
                ReaderSettings.minLayoutMargin,
                ReaderSettings.maxLayoutMargin,
              )
              .toDouble(),
      infoHeaderMarginRight:
          (prefs.getDouble(_infoHeaderMarginRightKey) ??
                  legacyHorizontalPadding)
              .clamp(
                ReaderSettings.minLayoutMargin,
                ReaderSettings.maxLayoutMargin,
              )
              .toDouble(),
      bodyMarginTop:
          (prefs.getDouble(_bodyMarginTopKey) ?? 18)
              .clamp(
                ReaderSettings.minLayoutMargin,
                ReaderSettings.maxLayoutMargin,
              )
              .toDouble(),
      bodyMarginBottom:
          (prefs.getDouble(_bodyMarginBottomKey) ?? 18)
              .clamp(
                ReaderSettings.minLayoutMargin,
                ReaderSettings.maxLayoutMargin,
              )
              .toDouble(),
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
          (prefs.getDouble(_infoFooterMarginLeftKey) ?? legacyHorizontalPadding)
              .clamp(
                ReaderSettings.minLayoutMargin,
                ReaderSettings.maxLayoutMargin,
              )
              .toDouble(),
      infoFooterMarginRight:
          (prefs.getDouble(_infoFooterMarginRightKey) ??
                  legacyHorizontalPadding)
              .clamp(
                ReaderSettings.minLayoutMargin,
                ReaderSettings.maxLayoutMargin,
              )
              .toDouble(),
    );
  }

  Future<void> saveSettings(ReaderSettings settings) async {
    final prefs = await _preferencesFuture;

    await prefs.setDouble(_fontSizeKey, settings.fontSize);
    await prefs.setDouble(_lineHeightKey, settings.lineHeight);
    await prefs.setDouble(
      _horizontalPaddingKey,
      ((settings.bodyMarginLeft + settings.bodyMarginRight) / 2).toDouble(),
    );
    await prefs.setDouble(_paragraphSpacingKey, settings.paragraphSpacing);
    await prefs.setDouble(_paragraphIndentKey, settings.paragraphIndent);
    await prefs.setBool(
      _textFullJustifyEnabledKey,
      settings.textFullJustifyEnabled,
    );
    await prefs.setDouble(_letterSpacingKey, settings.letterSpacing);
    await prefs.setDouble(_brightnessKey, settings.brightness);
    await prefs.setString(_themeModeKey, settings.themeMode.name);
    await prefs.setString(_pageTurnModeKey, settings.pageTurnMode.name);
    await prefs.setBool(
      _volumeKeyPageEnabledKey,
      settings.volumeKeyPageEnabled,
    );
    await prefs.setBool(_autoReadEnabledKey, settings.autoReadEnabled);
    await prefs.setDouble(_autoReadSpeedKey, settings.autoReadSpeed);
    await prefs.setString(_backgroundStyleKey, settings.backgroundStyle.name);
    await prefs.setString(_backgroundToneKey, settings.backgroundTone.name);
    await prefs.setDouble(_pageTurnStepRatioKey, settings.pageTurnStepRatio);
    await prefs.setString(_fontWeightLevelKey, settings.fontWeightLevel.name);
    await prefs.setString(_fontSourceKey, settings.fontSource.name);
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
      await prefs.setString(_customFontPathKey, customFontPath);
    }
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
    final backgroundImageBase64 = settings.backgroundImageBase64;
    if (backgroundImageBase64 == null || backgroundImageBase64.isEmpty) {
      await prefs.remove(_backgroundImageBase64Key);
    } else {
      await prefs.setString(_backgroundImageBase64Key, backgroundImageBase64);
    }
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
        // Ignore invalid stored list and fall back to legacy key.
      }
    }

    final legacy = prefs.getString(_customBackgroundImageBase64Key);
    final legacyValue = legacy?.trim();
    if (legacyValue != null &&
        legacyValue.isNotEmpty &&
        !results.contains(legacyValue)) {
      results.add(legacyValue);
    }

    return results;
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
    await prefs.setString(_customBackgroundImageBase64Key, normalized.first);
  }

  Future<ReadingProgress?> loadProgress(String bookId) async {
    if (bookId.trim().isEmpty) {
      return null;
    }

    final prefs = await _preferencesFuture;
    final raw = prefs.getString('$_progressPrefix${bookId.trim()}');
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }

      return ReadingProgress.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> saveProgress(ReadingProgress progress) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(
      '$_progressPrefix${progress.bookId}',
      jsonEncode(progress.toJson()),
    );
  }

  Future<ReaderTocSnapshot?> loadTocSnapshot({
    required String sourceId,
    required String detailUrl,
  }) async {
    final key = _buildTocSnapshotKey(sourceId: sourceId, detailUrl: detailUrl);
    if (key == null) {
      return null;
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

      return ReaderTocSnapshot.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
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

    final prefs = await _preferencesFuture;
    await prefs.setString(key, jsonEncode(snapshot.toJson()));
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
}
