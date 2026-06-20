import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/theme/app_theme_palette.dart';
import 'package:shuxiang_reading_next/core/storage/managed_asset_store.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/domain/entities/bottom_nav_icon_gallery.dart';
import 'package:shuxiang_reading_next/domain/entities/cover_gallery.dart';
import 'package:shuxiang_reading_next/domain/entities/launch_image_gallery.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_editor_state_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_provider.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/app_background_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/cover_gallery_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/launch_image_gallery_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/reader_background_service.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/advanced_theme_editor_page.dart';
import 'package:shuxiang_reading_next/features/mine/providers.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_font_registry_service.dart';
import 'package:shuxiang_reading_next/app/navigation/bottom_nav_icon_gallery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory documentsDir;
  late Directory supportDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    documentsDir = await Directory.systemTemp.createTemp(
      'advanced_theme_editor_docs_',
    );
    supportDir = await Directory.systemTemp.createTemp(
      'advanced_theme_editor_support_',
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
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
    if (supportDir.existsSync()) {
      await supportDir.delete(recursive: true);
    }
  });

  testWidgets('editor renders simplified component and resource sections', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final service = AdvancedThemeService(
      preferences: prefs,
      assetStore: ManagedAssetStore(),
    );
    final draft = AppAdvancedTheme(
      id: 'editor_component_smoke',
      name: '组件风格验证主题',
      createdAt: DateTime.parse('2026-05-21T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-05-21T00:00:00.000Z'),
      lightConfig: AppAdvancedThemeModeConfig(
        colors: const AppAdvancedThemeColors(
          primaryColorValue: 0xFF556677,
          backgroundColorValue: 0xFFF4EFE6,
          surfaceColorValue: 0xFFF2EBDF,
        ),
      ),
      darkConfig: AppAdvancedThemeModeConfig(
        colors: const AppAdvancedThemeColors(
          primaryColorValue: 0xFF99AABB,
          backgroundColorValue: 0xFF141B24,
          surfaceColorValue: 0xFF202733,
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          advancedThemeServiceProvider.overrideWithValue(service),
          advancedThemeEditorStateServiceProvider.overrideWithValue(
            _FakeAdvancedThemeEditorStateService(
              draft: draft,
              service: service,
              bottomNavIconGalleryService: BottomNavIconGalleryService(),
              appBackgroundService: AppBackgroundService(),
              coverGalleryService: CoverGalleryService(),
              launchImageGalleryService: LaunchImageGalleryService(),
              readerBackgroundService: ReaderBackgroundService(),
              fontRegistryService: ReaderFontRegistryService(),
            ),
          ),
        ],
        child: const MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(1.6),
            size: Size(430, 932),
          ),
          child: MaterialApp(
            home: AdvancedThemeEditorPage(themeId: 'editor_component_smoke'),
          ),
        ),
      ),
    );

    for (var index = 0; index < 20; index += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .byKey(const ValueKey<String>('advanced_theme_editor_scroll'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    final editorScroll = find.byKey(
      const ValueKey<String>('advanced_theme_editor_scroll'),
    );
    expect(find.text('壁纸图片适配'), findsNothing);
    expect(find.text('阅读器图片适配'), findsNothing);
    await _dragUntilFound(tester, editorScroll, find.text('视觉资源'));
    await tester.pump();

    expect(find.text('视觉资源'), findsOneWidget);
    expect(find.text('应用背景'), findsOneWidget);
    expect(find.text('阅读背景'), findsOneWidget);
    expect(find.text('书籍封面'), findsOneWidget);
    expect(find.text('启动图集'), findsOneWidget);
    expect(find.text('底栏图集'), findsOneWidget);
    expect(find.text('主题特效'), findsOneWidget);
    final resourceGrid = tester.widget<GridView>(
      find.byKey(const ValueKey<String>('advanced_theme_visual_resource_grid')),
    );
    final resourceGridDelegate =
        resourceGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(resourceGridDelegate.crossAxisCount, 3);
    expect(resourceGridDelegate.mainAxisExtent, 216);

    await _dragUntilFound(tester, editorScroll, find.text('圆角比例'));
    await tester.pump();

    expect(find.text('组件'), findsOneWidget);
    expect(find.text('圆角比例'), findsWidgets);
    expect(find.text('利落'), findsOneWidget);
    expect(find.text('标准'), findsOneWidget);
    expect(find.text('柔和'), findsOneWidget);
    expect(find.text('圆润'), findsOneWidget);
    expect(find.text('圆角预览'), findsOneWidget);
    await _dragUntilFound(tester, editorScroll, find.text('弹窗预览'));
    await tester.pump();

    expect(find.text('弹窗预览'), findsOneWidget);
    expect(find.text('普通弹窗'), findsOneWidget);
    expect(find.text('底部面板'), findsOneWidget);
    expect(find.text('弹窗背景模糊'), findsNothing);

    await _dragUntilFound(tester, editorScroll, find.text('高级参数'));
    await tester.ensureVisible(find.text('高级参数'));
    await tester.pump();

    expect(find.text('高级参数'), findsOneWidget);
    expect(find.text('卡片样式'), findsNothing);
    expect(find.text('按钮样式'), findsNothing);
    expect(find.text('输入框样式'), findsNothing);
    expect(find.text('弹窗样式'), findsNothing);
    expect(find.text('导航样式'), findsNothing);
    expect(find.text('切换样式'), findsNothing);
    expect(find.text('页面预览'), findsNothing);
    expect(find.text('搜索预览'), findsNothing);

    await tester.tap(find.text('高级参数'));
    await tester.pump();
    await _dragUntilFound(tester, editorScroll, find.text('卡片样式'));
    await tester.ensureVisible(find.text('卡片样式'));
    await tester.pump();

    expect(find.text('组件样式'), findsOneWidget);
    expect(find.text('卡片样式'), findsOneWidget);
    expect(find.text('按钮样式'), findsOneWidget);
    expect(find.text('输入框样式'), findsOneWidget);
    expect(find.text('弹窗样式'), findsOneWidget);
    expect(find.text('导航样式'), findsOneWidget);
    expect(find.text('切换样式'), findsOneWidget);

    await _dragUntilFound(tester, editorScroll, find.text('阴影色'));
    await tester.ensureVisible(find.text('阴影色'));
    await tester.pump();

    expect(find.text('卡片文字'), findsOneWidget);
    expect(find.text('阴影色'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new editor opens and allows changing title from top bar', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final service = AdvancedThemeService(
      preferences: prefs,
      assetStore: ManagedAssetStore(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          advancedThemeServiceProvider.overrideWithValue(service),
          advancedThemeEditorStateServiceProvider.overrideWithValue(
            _FakeAdvancedThemeEditorStateService(
              draft: _theme(),
              service: service,
              bottomNavIconGalleryService: BottomNavIconGalleryService(),
              appBackgroundService: AppBackgroundService(),
              coverGalleryService: CoverGalleryService(),
              launchImageGalleryService: LaunchImageGalleryService(),
              readerBackgroundService: ReaderBackgroundService(),
              fontRegistryService: ReaderFontRegistryService(),
            ),
          ),
        ],
        child: const MediaQuery(
          data: MediaQueryData(size: Size(430, 932)),
          child: MaterialApp(home: AdvancedThemeEditorPage()),
        ),
      ),
    );

    for (var index = 0; index < 20; index += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .byKey(const ValueKey<String>('advanced_theme_editor_scroll'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }

    expect(
      find.byKey(const ValueKey<String>('advanced_theme_loading')),
      findsNothing,
    );
    expect(find.text('未命名主题'), findsOneWidget);

    await tester.tap(find.text('未命名主题'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('advanced_theme_name_field')),
      '我的新主题',
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pump();

    expect(find.text('我的新主题'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('section descriptions and labels follow selected mode colors', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final service = AdvancedThemeService(
      preferences: prefs,
      assetStore: ManagedAssetStore(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          advancedThemeServiceProvider.overrideWithValue(service),
          advancedThemeEditorStateServiceProvider.overrideWithValue(
            _FakeAdvancedThemeEditorStateService(
              draft: _theme(),
              service: service,
              bottomNavIconGalleryService: BottomNavIconGalleryService(),
              appBackgroundService: AppBackgroundService(),
              coverGalleryService: CoverGalleryService(),
              launchImageGalleryService: LaunchImageGalleryService(),
              readerBackgroundService: ReaderBackgroundService(),
              fontRegistryService: ReaderFontRegistryService(),
            ),
          ),
        ],
        child: const MediaQuery(
          data: MediaQueryData(size: Size(430, 932)),
          child: MaterialApp(
            home: AdvancedThemeEditorPage(themeId: 'editor_component_smoke'),
          ),
        ),
      ),
    );

    for (var index = 0; index < 20; index += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find
          .byKey(const ValueKey<String>('advanced_theme_editor_scroll'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }

    expect(find.text('颜色卡片'), findsOneWidget);
    expect(find.text('这里放全局共享的颜色语义，优先决定整体氛围。'), findsOneWidget);
    expect(find.text('按钮、链接和选中状态的颜色'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline_rounded), findsNothing);

    await tester.tap(find.text('深色主题'));
    await tester.pumpAndSettle();

    final darkScheme = buildAppBaseDarkColorScheme(
      AppBaseColorSchemeId.luminaNeutral,
    );
    final sectionTitle = tester.widget<Text>(find.text('颜色卡片'));
    final fieldLabel = tester.widget<Text>(find.text('强调色'));

    expect(sectionTitle.style?.color, darkScheme.onSurfaceVariant);
    expect(fieldLabel.style?.color, darkScheme.onSurface);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _dragUntilFound(
  WidgetTester tester,
  Finder scrollable,
  Finder target, {
  int maxIterations = 24,
}) async {
  for (var index = 0; index < maxIterations; index += 1) {
    if (target.evaluate().isNotEmpty) {
      return;
    }
    await tester.drag(scrollable, const Offset(0, -320));
    await tester.pump(const Duration(milliseconds: 80));
  }
}

class _FakeAdvancedThemeEditorStateService
    extends AdvancedThemeEditorStateService {
  _FakeAdvancedThemeEditorStateService({
    required this.draft,
    required super.service,
    required super.bottomNavIconGalleryService,
    required super.appBackgroundService,
    required super.coverGalleryService,
    required super.launchImageGalleryService,
    required super.readerBackgroundService,
    required super.fontRegistryService,
  });

  final AppAdvancedTheme draft;

  @override
  Future<AppAdvancedTheme?> loadDraft(String? themeId) async => draft;

  @override
  Future<AdvancedThemeEditorAppearanceLinks> loadAppearanceLinks() async {
    return const AdvancedThemeEditorAppearanceLinks(
      backgroundLibraryPaths: <String>[],
      readerBackgroundLibraryPaths: <String>[],
      bottomNavGalleries: <BottomNavIconGallery>[],
      coverGalleries: <CoverGallery>[],
      launchImageGalleries: <LaunchImageGallery>[],
      availableFonts: <ReaderCustomFontEntry>[],
      activeBottomNavGalleryName: null,
    );
  }
}

AppAdvancedTheme _theme() {
  return AppAdvancedTheme(
    id: 'editor_component_smoke',
    name: '组件风格验证主题',
    createdAt: DateTime.parse('2026-05-21T00:00:00.000Z'),
    updatedAt: DateTime.parse('2026-05-21T00:00:00.000Z'),
    lightConfig: AppAdvancedThemeModeConfig(
      colors: const AppAdvancedThemeColors(
        primaryColorValue: 0xFF556677,
        backgroundColorValue: 0xFFF4EFE6,
        surfaceColorValue: 0xFFF2EBDF,
      ),
    ),
    darkConfig: AppAdvancedThemeModeConfig(
      colors: const AppAdvancedThemeColors(
        primaryColorValue: 0xFF99AABB,
        backgroundColorValue: 0xFF141B24,
        surfaceColorValue: 0xFF202733,
      ),
    ),
  );
}
