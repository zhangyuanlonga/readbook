import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/navigation/bottom_nav_icon_gallery_service.dart';
import '../../../app/preferences/app_preferences_service.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../../../domain/entities/bottom_nav_icon_gallery.dart';
import '../../reader/application/reader_font_registry_service.dart';
import '../../reader/application/reader_preferences_service.dart';
import 'cover_gallery_service.dart';
import 'launch_image_gallery_service.dart';

enum AdvancedThemeDeleteOptionKind {
  appearanceWallpapers,
  readerWallpapers,
  coverGalleries,
  launchImageGallery,
  bottomNavGallery,
  fonts,
}

class AdvancedThemeDeletePreviewSection {
  const AdvancedThemeDeletePreviewSection({
    required this.kind,
    required this.title,
    required this.items,
    required this.helperText,
    required this.defaultSelected,
  });

  final AdvancedThemeDeleteOptionKind kind;
  final String title;
  final List<String> items;
  final String helperText;
  final bool defaultSelected;
}

class AdvancedThemeDeletePreview {
  const AdvancedThemeDeletePreview({
    required this.themeName,
    required this.sections,
  });

  final String themeName;
  final List<AdvancedThemeDeletePreviewSection> sections;

  bool get hasAssociatedResources => sections.isNotEmpty;
}

class AdvancedThemeResourceReferenceService {
  AdvancedThemeResourceReferenceService({
    SharedPreferences? preferences,
    CoverGalleryService? coverGalleryService,
    LaunchImageGalleryService? launchImageGalleryService,
    BottomNavIconGalleryService? bottomNavIconGalleryService,
    ReaderFontRegistryService? fontRegistryService,
    AppInterfaceTypographyPreferencesService?
    appInterfaceTypographyPreferencesService,
    ReaderPreferencesService? readerPreferencesService,
  }) : _coverGalleryService =
           coverGalleryService ?? CoverGalleryService(preferences: preferences),
       _launchImageGalleryService =
           launchImageGalleryService ??
           LaunchImageGalleryService(preferences: preferences),
       _bottomNavIconGalleryService =
           bottomNavIconGalleryService ??
           BottomNavIconGalleryService(preferences: preferences),
       _fontRegistryService =
           fontRegistryService ?? ReaderFontRegistryService(),
       _appInterfaceTypographyPreferencesService =
           appInterfaceTypographyPreferencesService ??
           AppInterfaceTypographyPreferencesService(preferences: preferences),
       _readerPreferencesService =
           readerPreferencesService ??
           ReaderPreferencesService(preferences: preferences);

  final CoverGalleryService _coverGalleryService;
  final LaunchImageGalleryService _launchImageGalleryService;
  final BottomNavIconGalleryService _bottomNavIconGalleryService;
  final ReaderFontRegistryService _fontRegistryService;
  final AppInterfaceTypographyPreferencesService
  _appInterfaceTypographyPreferencesService;
  final ReaderPreferencesService _readerPreferencesService;

  Future<AdvancedThemeDeletePreview> buildDeletePreview({
    required AppAdvancedTheme theme,
    required List<AppAdvancedTheme> remainingThemes,
  }) async {
    final sections = <AdvancedThemeDeletePreviewSection>[];

    final appearanceItems = _wallpaperItems(
      lightPath: theme.lightConfig.wallpaperPath,
      darkPath: theme.darkConfig.wallpaperPath,
      singleLabel: '壁纸',
      lightLabel: '浅色壁纸',
      darkLabel: '深色壁纸',
    );
    if (appearanceItems.isNotEmpty) {
      sections.add(
        const AdvancedThemeDeletePreviewSection(
          kind: AdvancedThemeDeleteOptionKind.appearanceWallpapers,
          title: '页面壁纸',
          helperText: '主题私有资源，默认建议删除；若路径仍被其他主题引用，删除时会自动保留。',
          defaultSelected: true,
          items: <String>[],
        ).copyWith(items: appearanceItems),
      );
    }

    final readerItems = _wallpaperItems(
      lightPath: theme.lightConfig.readerWallpaperPath,
      darkPath: theme.darkConfig.readerWallpaperPath,
      singleLabel: '阅读器背景',
      lightLabel: '浅色阅读器背景',
      darkLabel: '深色阅读器背景',
    );
    if (readerItems.isNotEmpty) {
      sections.add(
        const AdvancedThemeDeletePreviewSection(
          kind: AdvancedThemeDeleteOptionKind.readerWallpapers,
          title: '阅读器背景',
          helperText: '主题私有资源，默认建议删除；若路径仍被其他主题引用，删除时会自动保留。',
          defaultSelected: true,
          items: <String>[],
        ).copyWith(items: readerItems),
      );
    }

    final coverItems = await _coverGalleryItems(theme);
    if (coverItems.isNotEmpty) {
      sections.add(
        const AdvancedThemeDeletePreviewSection(
          kind: AdvancedThemeDeleteOptionKind.coverGalleries,
          title: '封面图集',
          helperText: '共享资源，默认不删除；即使勾选，也只有在没有其他主题引用时才会真正删除。',
          defaultSelected: false,
          items: <String>[],
        ).copyWith(items: coverItems),
      );
    }

    final launchGalleryId = theme.launchImageGalleryId?.trim() ?? '';
    if (launchGalleryId.isNotEmpty) {
      final gallery = await _launchImageGalleryService.loadGallery(
        launchGalleryId,
      );
      sections.add(
        AdvancedThemeDeletePreviewSection(
          kind: AdvancedThemeDeleteOptionKind.launchImageGallery,
          title: '启动图集',
          items: <String>[
            gallery == null ? '启动图集：$launchGalleryId' : '启动图集：${gallery.name}',
          ],
          helperText: '共享资源，默认不删除；即使勾选，也只有在没有其他主题引用时才会真正删除。',
          defaultSelected: false,
        ),
      );
    }

    final bottomNavGalleryId = theme.bottomNavGalleryId?.trim() ?? '';
    if (bottomNavGalleryId.isNotEmpty) {
      final galleries = await _bottomNavIconGalleryService.loadGalleries();
      BottomNavIconGallery? gallery;
      for (final item in galleries) {
        if (item.id == bottomNavGalleryId) {
          gallery = item;
          break;
        }
      }
      sections.add(
        AdvancedThemeDeletePreviewSection(
          kind: AdvancedThemeDeleteOptionKind.bottomNavGallery,
          title: '底栏图集',
          items: <String>[
            gallery == null
                ? '底栏图集：$bottomNavGalleryId'
                : '底栏图集：${gallery.name}',
          ],
          helperText: '共享资源，默认不删除；即使勾选，也只有在没有其他主题引用时才会真正删除。',
          defaultSelected: false,
        ),
      );
    }

    final fontItems = await _fontItems(theme, remainingThemes: remainingThemes);
    if (fontItems.items.isNotEmpty) {
      sections.add(
        AdvancedThemeDeletePreviewSection(
          kind: AdvancedThemeDeleteOptionKind.fonts,
          title: '主题字体',
          items: fontItems.items,
          helperText: fontItems.helperText,
          defaultSelected: false,
        ),
      );
    }

    return AdvancedThemeDeletePreview(
      themeName: theme.name,
      sections: List<AdvancedThemeDeletePreviewSection>.unmodifiable(sections),
    );
  }

  Future<List<String>> filterRemovableFontFamilyKeys({
    required Iterable<String> fontFamilyKeys,
    required List<AppAdvancedTheme> remainingThemes,
  }) async {
    final appFontSettings =
        await _appInterfaceTypographyPreferencesService.loadFontSettings();
    final readerSettings = await _readerPreferencesService.loadSettings();
    final removable = <String>[];

    for (final rawKey in fontFamilyKeys) {
      final familyKey = rawKey.trim();
      if (familyKey.isEmpty) {
        continue;
      }
      final referencedByTheme = remainingThemes.any(
        (theme) =>
            (theme.appInterfaceFontFamilyKey?.trim() ?? '') == familyKey ||
            (theme.readerFontFamilyKey?.trim() ?? '') == familyKey,
      );
      if (referencedByTheme) {
        continue;
      }
      if ((appFontSettings.fontFamilyKey?.trim() ?? '') == familyKey) {
        continue;
      }
      if ((readerSettings.fontFamilyKey?.trim() ?? '') == familyKey) {
        continue;
      }
      removable.add(familyKey);
    }

    return removable;
  }

  List<String> _wallpaperItems({
    required String? lightPath,
    required String? darkPath,
    required String singleLabel,
    required String lightLabel,
    required String darkLabel,
  }) {
    final normalizedLight = lightPath?.trim() ?? '';
    final normalizedDark = darkPath?.trim() ?? '';
    if (normalizedLight.isEmpty && normalizedDark.isEmpty) {
      return const <String>[];
    }
    if (normalizedLight.isNotEmpty &&
        normalizedDark.isNotEmpty &&
        normalizedLight == normalizedDark) {
      return <String>['$singleLabel：${p.basename(normalizedLight)}'];
    }
    return <String>[
      if (normalizedLight.isNotEmpty)
        '$lightLabel：${p.basename(normalizedLight)}',
      if (normalizedDark.isNotEmpty) '$darkLabel：${p.basename(normalizedDark)}',
    ];
  }

  Future<List<String>> _coverGalleryItems(AppAdvancedTheme theme) async {
    final items = <String>[];
    final fallbackId = theme.coverGalleryId?.trim() ?? '';
    if (fallbackId.isNotEmpty) {
      final gallery = await _coverGalleryService.loadGallery(fallbackId);
      items.add(gallery == null ? '封面图集：$fallbackId' : '封面图集：${gallery.name}');
      return items;
    }

    final lightId = theme.lightCoverGalleryId?.trim() ?? '';
    final darkId = theme.darkCoverGalleryId?.trim() ?? '';
    if (lightId.isNotEmpty && darkId.isNotEmpty && lightId == darkId) {
      final gallery = await _coverGalleryService.loadGallery(lightId);
      items.add(
        gallery == null ? '浅色/深色封面图集：$lightId' : '浅色/深色封面图集：${gallery.name}',
      );
      return items;
    }
    if (lightId.isNotEmpty) {
      final gallery = await _coverGalleryService.loadGallery(lightId);
      items.add(gallery == null ? '浅色封面图集：$lightId' : '浅色封面图集：${gallery.name}');
    }
    if (darkId.isNotEmpty) {
      final gallery = await _coverGalleryService.loadGallery(darkId);
      items.add(gallery == null ? '深色封面图集：$darkId' : '深色封面图集：${gallery.name}');
    }
    return items;
  }

  Future<_FontDeletePreviewData> _fontItems(
    AppAdvancedTheme theme, {
    required List<AppAdvancedTheme> remainingThemes,
  }) async {
    final registry = await _fontRegistryService.listRegisteredFonts();
    final displayNames = <String, String>{
      for (final entry in registry) entry.fontFamilyKey: entry.displayName,
    };
    final appFontSettings =
        await _appInterfaceTypographyPreferencesService.loadFontSettings();
    final readerSettings = await _readerPreferencesService.loadSettings();
    final items = <String>[];
    final notes = <String>[];

    void addFontItem(String role, String? rawKey) {
      final familyKey = rawKey?.trim() ?? '';
      if (familyKey.isEmpty) {
        return;
      }
      final label = displayNames[familyKey] ?? familyKey;
      final tags = <String>[];
      final referencedByTheme = remainingThemes.any(
        (theme) =>
            (theme.appInterfaceFontFamilyKey?.trim() ?? '') == familyKey ||
            (theme.readerFontFamilyKey?.trim() ?? '') == familyKey,
      );
      if (referencedByTheme) {
        tags.add('其他主题仍在使用');
      }
      if ((appFontSettings.fontFamilyKey?.trim() ?? '') == familyKey) {
        tags.add('当前界面字体设置正在使用');
      }
      if ((readerSettings.fontFamilyKey?.trim() ?? '') == familyKey) {
        tags.add('当前阅读器手动设置正在使用');
      }
      if (tags.isNotEmpty) {
        notes.addAll(tags);
      }
      items.add(
        tags.isEmpty ? '$role：$label' : '$role：$label（${tags.join('，')}）',
      );
    }

    addFontItem('界面字体', theme.appInterfaceFontFamilyKey);
    addFontItem('阅读字体', theme.readerFontFamilyKey);

    final uniqueNotes = notes.toSet().toList(growable: false);
    final helperText =
        uniqueNotes.isEmpty
            ? '共享资源，默认不删除；仅当无其他主题引用，且未被当前界面字体或阅读器手动设置使用时才会真正删除。'
            : '共享资源，默认不删除；当前检查结果：${uniqueNotes.join('、')}。';
    return _FontDeletePreviewData(items: items, helperText: helperText);
  }
}

class _FontDeletePreviewData {
  const _FontDeletePreviewData({required this.items, required this.helperText});

  final List<String> items;
  final String helperText;
}

extension on AdvancedThemeDeletePreviewSection {
  AdvancedThemeDeletePreviewSection copyWith({List<String>? items}) {
    return AdvancedThemeDeletePreviewSection(
      kind: kind,
      title: title,
      items: items ?? this.items,
      helperText: helperText,
      defaultSelected: defaultSelected,
    );
  }
}
