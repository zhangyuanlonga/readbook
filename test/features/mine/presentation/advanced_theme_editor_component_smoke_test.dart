import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  testWidgets(
    'editor renders component style section and six preview modules',
    (tester) async {
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
        if (find.text('组件风格').evaluate().isNotEmpty) {
          break;
        }
      }
      await tester.scrollUntilVisible(
        find.text('全局圆角'),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(find.text('组件风格'), findsOneWidget);
      expect(find.text('全局圆角'), findsOneWidget);
      expect(find.text('卡片风格'), findsOneWidget);
      expect(find.text('按钮风格'), findsOneWidget);
      expect(find.text('输入框风格'), findsOneWidget);
      expect(find.text('弹层风格'), findsOneWidget);
      expect(find.text('导航栏风格'), findsOneWidget);
      expect(find.text('切换风格'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('自动跟随主题'),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text('页面预览'), findsWidgets);
      expect(find.text('搜索预览'), findsWidgets);
      expect(find.text('按钮预览'), findsWidgets);
      expect(find.text('弹窗预览'), findsWidgets);
      expect(find.text('切换预览'), findsWidgets);
      expect(find.text('阅读器预览'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
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
