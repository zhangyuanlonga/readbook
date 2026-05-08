import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/navigation/bottom_nav_icon_gallery_service.dart';
import 'package:shuxiang_reading_next/core/storage/managed_asset_store.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/domain/entities/bottom_nav_icon_gallery.dart';
import 'package:shuxiang_reading_next/features/mine/application/cover_gallery_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  setUp(() async {
    final documentsDir = await Directory.systemTemp.createTemp(
      'theme_test_docs_',
    );
    final supportDir = await Directory.systemTemp.createTemp(
      'theme_test_support_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return documentsDir.path;
          }
          if (call.method == 'getApplicationSupportDirectory') {
            return supportDir.path;
          }
          return null;
        });
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
      if (documentsDir.existsSync()) {
        await documentsDir.delete(recursive: true);
      }
      if (supportDir.existsSync()) {
        await supportDir.delete(recursive: true);
      }
    });
  });

  test('encodes theme colors as portable json payload', () {
    final service = AdvancedThemeService();
    final theme = AppAdvancedTheme(
      id: 'theme_a',
      name: '护眼绿',
      createdAt: DateTime.parse('2026-04-18T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-04-18T00:00:00.000Z'),
      lightConfig: AppAdvancedThemeModeConfig(
        colors: AppAdvancedThemeColors(
          primaryColorValue: 0xFF336699,
          backgroundColorValue: 0xFFF5F8F2,
        ),
        readerWallpaperPath: '/tmp/reader_light.jpg',
      ),
      darkConfig: AppAdvancedThemeModeConfig(
        colors: AppAdvancedThemeColors(
          primaryColorValue: 0xFF88CCAA,
          backgroundColorValue: 0xFF101512,
        ),
        readerWallpaperPath: '/tmp/reader_dark.jpg',
      ),
      coverGalleryId: 'cover_gallery_1',
      launchImageGalleryId: 'launch_gallery_1',
      bottomNavGalleryId: 'bottom_gallery_1',
    );

    final rawJson = service.encodeThemeColorJson(theme);
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;

    expect(decoded['type'], 'advanced_theme_colors');
    expect(decoded['version'], 2);
    expect(decoded['name'], '护眼绿');
    expect(decoded['lightConfig'], isA<Map>());
    expect(decoded['darkConfig'], isA<Map>());
    expect(
      ((decoded['lightConfig'] as Map)['colors'] as Map).containsKey(
        AppAdvancedThemeColors.semanticColorGroupsKey,
      ),
      isTrue,
    );
    expect(decoded.containsKey('coverGalleryId'), isFalse);
    expect(decoded.containsKey('launchImageGalleryId'), isFalse);
    expect(decoded.containsKey('bottomNavGalleryId'), isFalse);
    expect(decoded.containsKey('wallpaperPath'), isFalse);
  });

  test('imports theme colors into a new saved theme', () async {
    final service = AdvancedThemeService(assetStore: await _createAssetStore());

    final imported = await service.importThemeColorJson(
      jsonEncode(<String, dynamic>{
        'type': 'advanced_theme_colors',
        'version': 1,
        'name': '薄雾灰',
        'lightColors': <String, dynamic>{
          'primaryColorValue': 0xFF556677,
          'surfaceColorValue': 0xFFF6F6F4,
        },
        'darkColors': <String, dynamic>{
          'primaryColorValue': 0xFF99AABB,
          'surfaceColorValue': 0xFF17191A,
        },
      }),
    );

    expect(imported.id, startsWith('advanced_theme_'));
    expect(imported.name, '薄雾灰');
    expect(imported.lightConfig.colors.primaryColorValue, 0xFF556677);
    expect(imported.darkConfig.colors.primaryColorValue, 0xFF99AABB);
    expect(imported.coverGalleryId, isNull);
    expect(imported.launchImageGalleryId, isNull);
    expect(imported.bottomNavGalleryId, isNull);
    expect(imported.lightConfig.wallpaperPath, isNull);
    expect(imported.darkConfig.wallpaperPath, isNull);
    expect(imported.lightConfig.readerWallpaperPath, isNull);
    expect(imported.darkConfig.readerWallpaperPath, isNull);

    final themes = await service.loadThemes();
    expect(themes, hasLength(1));
    expect(themes.first.name, '薄雾灰');
  });

  test('imports semantic-group color payload into a new saved theme', () async {
    final service = AdvancedThemeService(assetStore: await _createAssetStore());

    final imported = await service.importThemeColorJson(
      jsonEncode(<String, dynamic>{
        'type': 'advanced_theme_colors',
        'version': 2,
        'name': '语义分组主题',
        'lightConfig': <String, dynamic>{
          'colors': <String, dynamic>{
            AppAdvancedThemeColors.semanticColorGroupsKey: <String, dynamic>{
              'core': <String, dynamic>{
                'primary': 0xFF556677,
                'background': 0xFFF6F6F4,
              },
              'component': <String, dynamic>{'card': 0xFFFFFFFF},
            },
          },
        },
        'darkConfig': <String, dynamic>{
          'colors': <String, dynamic>{
            AppAdvancedThemeColors.semanticColorGroupsKey: <String, dynamic>{
              'core': <String, dynamic>{
                'primary': 0xFF99AABB,
                'background': 0xFF17191A,
              },
              'component': <String, dynamic>{'card': 0xFF202326},
            },
          },
        },
      }),
    );

    expect(imported.name, '语义分组主题');
    expect(imported.lightConfig.colors.primaryColorValue, 0xFF556677);
    expect(imported.darkConfig.colors.primaryColorValue, 0xFF99AABB);
    expect(imported.lightConfig.colors.cardColorValue, 0xFFFFFFFF);
    expect(imported.darkConfig.colors.cardColorValue, 0xFF202326);
  });

  test('persists reader wallpaper path inside theme mode config', () async {
    final service = AdvancedThemeService(assetStore: await _createAssetStore());
    final theme = AppAdvancedTheme(
      id: 'theme_reader_wallpaper',
      name: '阅读器联动',
      createdAt: DateTime.parse('2026-04-21T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-04-21T00:00:00.000Z'),
      lightConfig: AppAdvancedThemeModeConfig(
        readerWallpaperPath: '/tmp/reader_light.jpg',
      ),
      darkConfig: AppAdvancedThemeModeConfig(
        readerWallpaperPath: '/tmp/reader_dark.jpg',
      ),
    );

    await service.saveTheme(theme);
    final themes = await service.loadThemes();

    expect(themes, hasLength(1));
    expect(
      themes.first.lightConfig.readerWallpaperPath,
      '/tmp/reader_light.jpg',
    );
    expect(themes.first.darkConfig.readerWallpaperPath, '/tmp/reader_dark.jpg');
  });

  test('persists launch image gallery binding in theme payload', () async {
    final service = AdvancedThemeService(assetStore: await _createAssetStore());
    final theme = AppAdvancedTheme(
      id: 'theme_launch_gallery',
      name: '启动联动',
      createdAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
      lightConfig: AppAdvancedThemeModeConfig(),
      darkConfig: AppAdvancedThemeModeConfig(),
      launchImageGalleryId: 'launch_gallery_a',
    );

    await service.saveTheme(theme);
    final themes = await service.loadThemes();

    expect(themes, hasLength(1));
    expect(themes.first.launchImageGalleryId, 'launch_gallery_a');
  });

  test(
    'loads theme by id without requiring full theme scan by caller',
    () async {
      final service = AdvancedThemeService(
        assetStore: await _createAssetStore(),
      );
      final lightTheme = AppAdvancedTheme(
        id: 'theme_light',
        name: '浅色主题',
        createdAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
        lightConfig: AppAdvancedThemeModeConfig(),
        darkConfig: AppAdvancedThemeModeConfig(),
      );
      final darkTheme = AppAdvancedTheme(
        id: 'theme_dark',
        name: '深色主题',
        createdAt: DateTime.parse('2026-04-23T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-04-23T00:00:00.000Z'),
        lightConfig: AppAdvancedThemeModeConfig(),
        darkConfig: AppAdvancedThemeModeConfig(),
      );

      await service.saveTheme(lightTheme);
      await service.saveTheme(darkTheme);

      final loaded = await service.loadThemeById('theme_dark');

      expect(loaded, isNotNull);
      expect(loaded!.id, 'theme_dark');
      expect(loaded.name, '深色主题');
    },
  );

  test('loads lightweight summaries for theme list rendering', () async {
    final service = AdvancedThemeService(assetStore: await _createAssetStore());
    final theme = AppAdvancedTheme(
      id: 'theme_summary',
      name: '摘要主题',
      createdAt: DateTime.parse('2026-04-23T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-04-23T00:00:00.000Z'),
      lightConfig: AppAdvancedThemeModeConfig(
        colors: AppAdvancedThemeColors(
          primaryColorValue: 0xFF112233,
          backgroundColorValue: 0xFFF4F1EA,
        ),
        wallpaperPath: '/tmp/light_wallpaper.png',
      ),
      darkConfig: AppAdvancedThemeModeConfig(
        colors: AppAdvancedThemeColors(
          primaryColorValue: 0xFFCCDDEE,
          backgroundColorValue: 0xFF101820,
        ),
      ),
      category: '护眼',
      launchImageGalleryId: 'launch_gallery_1',
      appInterfaceFontFamilyKey: 'font_ui_1',
    );

    await service.saveTheme(theme);
    final summaries = await service.loadThemeSummaries();

    expect(summaries, hasLength(1));
    expect(summaries.first.id, 'theme_summary');
    expect(summaries.first.name, '摘要主题');
    expect(summaries.first.category, '护眼');
    expect(summaries.first.lightMode.hasWallpaper, isTrue);
    expect(summaries.first.darkMode.hasWallpaper, isFalse);
    expect(summaries.first.hasLaunchImageGallery, isTrue);
    expect(summaries.first.hasAppInterfaceFont, isTrue);
  });

  test(
    'persists theme category and mode-specific cover gallery bindings',
    () async {
      final service = AdvancedThemeService(
        assetStore: await _createAssetStore(),
      );
      final theme = AppAdvancedTheme(
        id: 'theme_cover_modes',
        name: '双封面主题',
        createdAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
        lightConfig: AppAdvancedThemeModeConfig(),
        darkConfig: AppAdvancedThemeModeConfig(),
        category: '护眼',
        lightCoverGalleryId: 'cover_gallery_light',
        darkCoverGalleryId: 'cover_gallery_dark',
      );

      await service.saveTheme(theme);
      final themes = await service.loadThemes();

      expect(themes, hasLength(1));
      expect(themes.first.category, '护眼');
      expect(
        themes.first.coverGalleryIdFor(AppAdvancedThemeMode.light),
        'cover_gallery_light',
      );
      expect(
        themes.first.coverGalleryIdFor(AppAdvancedThemeMode.dark),
        'cover_gallery_dark',
      );
    },
  );

  test(
    'round-trips bottom nav gallery binding through theme bundle import',
    () async {
      final assetStore = await _createAssetStore();
      final prefs = await SharedPreferences.getInstance();
      final service = AdvancedThemeService(
        preferences: prefs,
        assetStore: assetStore,
      );
      final bottomNavService = BottomNavIconGalleryService(
        preferences: prefs,
        assetStore: assetStore,
      );
      final gallery = BottomNavIconGallery(
        id: 'gallery_theme_bundle',
        name: '主题底栏',
        createdAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
        isBuiltIn: false,
        isEditable: true,
        isDeletable: true,
        items: const <BottomNavIconGalleryTab, BottomNavIconSet>{
          BottomNavIconGalleryTab.home: BottomNavIconSet(
            lightUnselected: BottomNavIconAssetRef(
              path: 'assets/test_icons/home_light.png',
              format: BottomNavIconAssetFormat.png,
              isAsset: true,
            ),
            darkSelected: BottomNavIconAssetRef(
              path: 'assets/test_icons/home_dark.png',
              format: BottomNavIconAssetFormat.png,
              isAsset: true,
            ),
          ),
        },
      );
      await bottomNavService.saveGalleries(<BottomNavIconGallery>[gallery]);
      final theme = AppAdvancedTheme(
        id: 'theme_bundle_bottom_nav',
        name: '底栏主题',
        createdAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
        lightConfig: AppAdvancedThemeModeConfig(),
        darkConfig: AppAdvancedThemeModeConfig(),
        bottomNavGalleryId: gallery.id,
      );

      final bundleBytes = await service.encodeThemeBundleZip(theme);
      final imported = await service.importThemeBundleZipBytes(bundleBytes);
      BottomNavIconGallery? importedGallery;
      for (final gallery in await bottomNavService.loadGalleries()) {
        if (gallery.id == imported.bottomNavGalleryId) {
          importedGallery = gallery;
          break;
        }
      }

      expect(imported.bottomNavGalleryId, isNotNull);
      expect(imported.bottomNavGalleryId, isNot(gallery.id));
      expect(importedGallery, isNotNull);
      expect(importedGallery!.name, gallery.name);
      expect(
        importedGallery
            .items[BottomNavIconGalleryTab.home]
            ?.lightUnselected
            ?.path,
        'assets/test_icons/home_light.png',
      );
      expect(
        importedGallery.items[BottomNavIconGalleryTab.home]?.darkSelected?.path,
        'assets/test_icons/home_dark.png',
      );
    },
  );

  test('imports Red bottom nav gif pack and maps legacy notes tab', () async {
    final assetStore = await _createAssetStore();
    final prefs = await SharedPreferences.getInstance();
    final service = AdvancedThemeService(
      preferences: prefs,
      assetStore: assetStore,
    );
    final bytes = _buildRedThemePackageBytes(
      themeJson: <String, dynamic>{
        'name': '夜昧·这个夏天',
        'light': <String, dynamic>{'navbarPackId': 'pack_1'},
        'dark': <String, dynamic>{'navbarPackId': 'pack_1'},
      },
      files: <String, List<int>>{
        'navbar_pack/pack_1/meta.json': utf8.encode(
          jsonEncode(<String, dynamic>{'name': '这个夏天底栏'}),
        ),
        'navbar_pack/pack_1/home_normal.gif': const <int>[
          0x47,
          0x49,
          0x46,
          0x38,
          0x39,
          0x61,
        ],
        'navbar_pack/pack_1/bookshelf_normal.gif': const <int>[
          0x47,
          0x49,
          0x46,
          0x38,
          0x39,
          0x61,
          0x01,
        ],
        'navbar_pack/pack_1/statistics_normal.gif': const <int>[
          0x47,
          0x49,
          0x46,
          0x38,
          0x39,
          0x61,
          0x02,
        ],
        'navbar_pack/pack_1/notes_normal.gif': const <int>[
          0x47,
          0x49,
          0x46,
          0x38,
          0x39,
          0x61,
          0x03,
        ],
        'navbar_pack/pack_1/settings_normal.gif': const <int>[
          0x47,
          0x49,
          0x46,
          0x38,
          0x39,
          0x61,
          0x04,
        ],
      },
    );

    final imported = await service.importRedThemePackageBytes(bytes);
    BottomNavIconGallery? importedGallery;
    final galleryService = BottomNavIconGalleryService(
      preferences: prefs,
      assetStore: assetStore,
    );
    for (final gallery in await galleryService.loadGalleries()) {
      if (gallery.id == imported.bottomNavGalleryId) {
        importedGallery = gallery;
        break;
      }
    }

    expect(imported.bottomNavGalleryId, isNotNull);
    expect(importedGallery, isNotNull);
    expect(
      importedGallery!
          .items[BottomNavIconGalleryTab.home]
          ?.lightUnselected
          ?.format,
      BottomNavIconAssetFormat.gif,
    );
    expect(
      importedGallery
          .items[BottomNavIconGalleryTab.discover]
          ?.lightUnselected
          ?.format,
      BottomNavIconAssetFormat.gif,
    );
    expect(
      importedGallery
          .items[BottomNavIconGalleryTab.mine]
          ?.lightUnselected
          ?.format,
      BottomNavIconAssetFormat.gif,
    );
  });

  test(
    'imports RGShare cover gallery, bottom nav profile and reader background',
    () async {
      final assetStore = await _createAssetStore();
      final prefs = await SharedPreferences.getInstance();
      final service = AdvancedThemeService(
        preferences: prefs,
        assetStore: assetStore,
      );
      final bytes = _buildZipPackageBytes(<String, List<int>>{
        'theme.json': utf8.encode(
          jsonEncode(<String, dynamic>{
            '1': 'Www.荔枝春',
            '2': <String, dynamic>{'5': '#8C4141FF'},
            '4': <String, dynamic>{'45': 'custom_light.jpg'},
          }),
        ),
        'meta.json': utf8.encode(
          jsonEncode(<String, dynamic>{
            'cover': <String, dynamic>{
              'name': 'Www.荔枝春',
              'files': <String>[
                'resources/cover/a.png',
                'resources/cover/b.png',
              ],
            },
            'readerTheme': <String, dynamic>{
              'filePath': 'resources/reader_theme/theme.json',
              'backgroundImagePath': 'resources/reader_theme/bg.jpg',
            },
            'tabBarProfile': <String, dynamic>{
              'name': 'Www.荔枝春',
              'filePath': 'resources/tabbar/profile.json',
            },
          }),
        ),
        'images/custom_light.jpg': const <int>[0xFF, 0xD8, 0xFF, 0x00],
        'resources/cover/a.png': const <int>[0x89, 0x50, 0x4E, 0x47, 0x01],
        'resources/cover/b.png': const <int>[0x89, 0x50, 0x4E, 0x47, 0x02],
        'resources/reader_theme/theme.json': utf8.encode(
          jsonEncode(<String, dynamic>{'bodyFont': 'MissingFont'}),
        ),
        'resources/reader_theme/bg.jpg': const <int>[0xFF, 0xD8, 0xFF, 0x01],
        'resources/tabbar/profile.json': utf8.encode(
          jsonEncode(<String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'tab': 'shelf',
                'iconSource': <String, dynamic>{
                  'type': 'customImage',
                  'value': 'shelf.png',
                },
              },
              <String, dynamic>{
                'tab': 'library',
                'iconSource': <String, dynamic>{
                  'type': 'customImage',
                  'value': 'library.png',
                },
              },
              <String, dynamic>{
                'tab': 'statistic',
                'iconSource': <String, dynamic>{
                  'type': 'customImage',
                  'value': 'statistic.png',
                },
              },
              <String, dynamic>{
                'tab': 'mine',
                'iconSource': <String, dynamic>{
                  'type': 'customImage',
                  'value': 'mine.png',
                },
              },
            ],
          }),
        ),
        'resources/tabbar/shelf.png': const <int>[0x89, 0x50, 0x4E, 0x47, 0x11],
        'resources/tabbar/library.png': const <int>[
          0x89,
          0x50,
          0x4E,
          0x47,
          0x12,
        ],
        'resources/tabbar/statistic.png': const <int>[
          0x89,
          0x50,
          0x4E,
          0x47,
          0x13,
        ],
        'resources/tabbar/mine.png': const <int>[0x89, 0x50, 0x4E, 0x47, 0x14],
      });

      final imported = await service.importRgShareThemePackageBytes(bytes);

      expect(imported.coverGalleryId, isNotNull);
      expect(imported.bottomNavGalleryId, isNotNull);
      expect(imported.lightConfig.readerWallpaperPath, isNotNull);
      expect(imported.darkConfig.readerWallpaperPath, isNotNull);

      final coverService = CoverGalleryService(preferences: prefs);
      final coverGallery = await coverService.loadGallery(
        imported.coverGalleryId!,
      );
      expect(coverGallery, isNotNull);
      expect(coverGallery!.imagePaths, hasLength(2));

      final bottomNavService = BottomNavIconGalleryService(
        preferences: prefs,
        assetStore: assetStore,
      );
      BottomNavIconGallery? navGallery;
      for (final gallery in await bottomNavService.loadGalleries()) {
        if (gallery.id == imported.bottomNavGalleryId) {
          navGallery = gallery;
          break;
        }
      }
      expect(navGallery, isNotNull);
      expect(
        navGallery!
            .items[BottomNavIconGalleryTab.bookshelf]
            ?.lightUnselected
            ?.format,
        BottomNavIconAssetFormat.png,
      );
      expect(
        navGallery.items[BottomNavIconGalleryTab.home]?.lightUnselected?.format,
        BottomNavIconAssetFormat.png,
      );
      expect(
        navGallery
            .items[BottomNavIconGalleryTab.discover]
            ?.lightUnselected
            ?.format,
        BottomNavIconAssetFormat.png,
      );
    },
  );

  test('rejects importing duplicate theme payload by fingerprint', () async {
    final service = AdvancedThemeService(assetStore: await _createAssetStore());
    final payload = jsonEncode(<String, dynamic>{
      'type': 'advanced_theme_colors',
      'version': 2,
      'name': '薄雾灰',
      'lightConfig': <String, dynamic>{
        'colors': <String, dynamic>{'primaryColorValue': 0xFF556677},
      },
      'darkConfig': <String, dynamic>{
        'colors': <String, dynamic>{'primaryColorValue': 0xFF99AABB},
      },
    });

    await service.importThemeColorJson(payload);

    await expectLater(
      () => service.importThemeColorJson(payload),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('已导入重复主题'),
        ),
      ),
    );
  });

  test('deletes only selected theme resources', () async {
    final service = AdvancedThemeService(assetStore: await _createAssetStore());
    final wallpaperFile = await _createTempFile(
      prefix: 'theme_wallpaper_',
      fileName: 'light.png',
    );
    final readerWallpaperFile = await _createTempFile(
      prefix: 'theme_reader_wallpaper_',
      fileName: 'reader.png',
    );
    final theme = AppAdvancedTheme(
      id: 'theme_delete_options',
      name: '删除选项',
      createdAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-05-06T00:00:00.000Z'),
      lightConfig: AppAdvancedThemeModeConfig(
        wallpaperPath: wallpaperFile.path,
        readerWallpaperPath: readerWallpaperFile.path,
      ),
      darkConfig: AppAdvancedThemeModeConfig(),
    );

    await service.saveTheme(theme);
    await service.deleteTheme(
      theme.id,
      deleteOptions: const AdvancedThemeDeleteOptions(
        deleteAppearanceWallpapers: false,
        deleteReaderWallpapers: true,
        deleteCoverGalleries: false,
        deleteLaunchImageGallery: false,
        deleteBottomNavGallery: false,
        deleteFonts: false,
      ),
    );

    expect(await wallpaperFile.exists(), isTrue);
    expect(await readerWallpaperFile.exists(), isFalse);
    expect(await service.loadThemes(), isEmpty);
  });

  test('imports reader wallpaper into theme-owned collection', () async {
    final assetStore = await _createAssetStore();
    final service = AdvancedThemeService(assetStore: assetStore);
    final path = await service.saveReaderWallpaper(
      themeId: 'theme_reader_private',
      mode: AppAdvancedThemeMode.dark,
      bytes: const <int>[0x89, 0x50, 0x4E, 0x47],
      fileName: 'reader.png',
    );

    expect(
      await service.isThemeOwnedReaderWallpaper(
        themeId: 'theme_reader_private',
        path: path,
      ),
      isTrue,
    );
    expect(await File(path).exists(), isTrue);
  });
}

Future<ManagedAssetStore> _createAssetStore() async {
  final documentsDir = await Directory.systemTemp.createTemp('theme_docs_');
  final supportDir = await Directory.systemTemp.createTemp('theme_support_');
  addTearDown(() async {
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
    if (supportDir.existsSync()) {
      await supportDir.delete(recursive: true);
    }
  });
  return ManagedAssetStore(
    documentsDirectoryProvider: () async => documentsDir,
    supportDirectoryProvider: () async => supportDir,
  );
}

Future<File> _createTempFile({
  required String prefix,
  required String fileName,
}) async {
  final directory = await Directory.systemTemp.createTemp(prefix);
  addTearDown(() async {
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(const <int>[0x89, 0x50, 0x4E, 0x47], flush: true);
  return file;
}

List<int> _buildRedThemePackageBytes({
  required Map<String, dynamic> themeJson,
  required Map<String, List<int>> files,
}) {
  final archive = Archive();
  final themeBytes = utf8.encode(jsonEncode(themeJson));
  archive.addFile(ArchiveFile('theme.json', themeBytes.length, themeBytes));
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  final zipBytes = ZipEncoder().encode(archive);
  return <int>[0x52, 0x45, 0x44, 0x04, ...zipBytes];
}

List<int> _buildZipPackageBytes(Map<String, List<int>> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return ZipEncoder().encode(archive);
}
