import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _brightnessKey = 'reader.settings.brightness';
  static const String _themeModeKey = 'reader.settings.themeMode';
  static const String _pageTurnModeKey = 'reader.settings.pageTurnMode';
  static const String _autoReadEnabledKey = 'reader.settings.autoReadEnabled';
  static const String _autoReadSpeedKey = 'reader.settings.autoReadSpeed';
  static const String _backgroundStyleKey = 'reader.settings.backgroundStyle';
  static const String _backgroundToneKey = 'reader.settings.backgroundTone';
  static const String _pageTurnStepRatioKey =
      'reader.settings.pageTurnStepRatio';
  static const String _fontWeightLevelKey = 'reader.settings.fontWeightLevel';
  static const String _pageAnimationStyleKey =
      'reader.settings.pageAnimationStyle';
  static const String _backgroundImageBase64Key =
      'reader.settings.backgroundImageBase64';
  static const String _mangaReadModeKey = 'reader.settings.mangaReadMode';
  static const String _mangaImageSpacingKey =
      'reader.settings.mangaImageSpacing';
  static const String _mangaImagePaddingKey =
      'reader.settings.mangaImagePadding';
  static const String _mangaLoadStrategyKey =
      'reader.settings.mangaLoadStrategy';
  static const String _progressPrefix = 'reader.progress.';

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
      orElse: () => ReaderPageTurnMode.tap,
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

    return ReaderSettings(
      fontSize: prefs.getDouble(_fontSizeKey) ?? 18,
      lineHeight: prefs.getDouble(_lineHeightKey) ?? 1.7,
      horizontalPadding: prefs.getDouble(_horizontalPaddingKey) ?? 18,
      paragraphSpacing: prefs.getDouble(_paragraphSpacingKey) ?? 14,
      paragraphIndent: prefs.getDouble(_paragraphIndentKey) ?? 0,
      brightness: (prefs.getDouble(_brightnessKey) ?? 1).clamp(0.2, 1.0),
      themeMode: mode,
      pageTurnMode: pageTurnMode,
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
    );
  }

  Future<void> saveSettings(ReaderSettings settings) async {
    final prefs = await _preferencesFuture;

    await prefs.setDouble(_fontSizeKey, settings.fontSize);
    await prefs.setDouble(_lineHeightKey, settings.lineHeight);
    await prefs.setDouble(_horizontalPaddingKey, settings.horizontalPadding);
    await prefs.setDouble(_paragraphSpacingKey, settings.paragraphSpacing);
    await prefs.setDouble(_paragraphIndentKey, settings.paragraphIndent);
    await prefs.setDouble(_brightnessKey, settings.brightness);
    await prefs.setString(_themeModeKey, settings.themeMode.name);
    await prefs.setString(_pageTurnModeKey, settings.pageTurnMode.name);
    await prefs.setBool(_autoReadEnabledKey, settings.autoReadEnabled);
    await prefs.setDouble(_autoReadSpeedKey, settings.autoReadSpeed);
    await prefs.setString(_backgroundStyleKey, settings.backgroundStyle.name);
    await prefs.setString(_backgroundToneKey, settings.backgroundTone.name);
    await prefs.setDouble(_pageTurnStepRatioKey, settings.pageTurnStepRatio);
    await prefs.setString(_fontWeightLevelKey, settings.fontWeightLevel.name);
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
    final backgroundImageBase64 = settings.backgroundImageBase64;
    if (backgroundImageBase64 == null || backgroundImageBase64.isEmpty) {
      await prefs.remove(_backgroundImageBase64Key);
    } else {
      await prefs.setString(_backgroundImageBase64Key, backgroundImageBase64);
    }
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
}
