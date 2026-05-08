import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/navigation/bottom_nav_icon_gallery_service.dart';
import 'package:shuxiang_reading_next/core/auth/auth_event_bus.dart';
import 'package:shuxiang_reading_next/core/membership/membership_entitlement.dart';
import 'package:shuxiang_reading_next/core/membership/membership_features.dart';
import 'package:shuxiang_reading_next/core/membership/membership_service.dart';
import 'package:shuxiang_reading_next/core/storage/managed_asset_store.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_editor_state_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_page_flow_coordinator.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_provider.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/app_background_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/cover_gallery_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/launch_image_gallery_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/reader_background_service.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/advanced_theme_editor_page.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/advanced_theme_list_page.dart';
import 'package:shuxiang_reading_next/features/mine/providers.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_font_registry_service.dart';
import 'package:shuxiang_reading_next/features/source/application/external_source_import_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory documentsDir;
  late Directory supportDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth.access_token': 'token_smoke',
      'auth.user_id': 'user_smoke',
      'auth.username': 'theme_smoke',
    });
    documentsDir = await Directory.systemTemp.createTemp(
      'advanced_theme_pages_docs_',
    );
    supportDir = await Directory.systemTemp.createTemp(
      'advanced_theme_pages_support_',
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
    'legacy flat theme can open editor and save without losing visuals',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'app.advancedThemes',
        jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'legacy_theme_editor',
            'name': '旧结构主题',
            'createdAt': '2026-05-07T00:00:00.000Z',
            'updatedAt': '2026-05-07T00:00:00.000Z',
            'lightConfig': <String, dynamic>{
              'colors': <String, dynamic>{
                'primaryColorValue': 0xFF556677,
                'cardColorValue': 0xFFF8F6F0,
                'cardBorderColorValue': 0xFFD9D3C7,
                'shadowColorValue': 0x55334455,
                'wallpaperOverlayColorValue': 0xFFF2EEE6,
              },
              'wallpaperOpacity': 1.0,
              'wallpaperBlurSigma': 0.0,
              'wallpaperFit': 'cover',
              'wallpaperOverlayOpacity': 0.32,
              'readerWallpaperOpacity': 1.0,
              'readerWallpaperBlurSigma': 0.0,
              'readerWallpaperFit': 'cover',
              'readerWallpaperOverlayOpacity': 0.0,
            },
            'darkConfig': <String, dynamic>{
              'colors': <String, dynamic>{
                'primaryColorValue': 0xFF99AABB,
                'cardColorValue': 0xFF202326,
                'cardBorderColorValue': 0xFF3A4048,
                'shadowColorValue': 0x66334455,
                'wallpaperOverlayColorValue': 0xFF12161C,
              },
              'wallpaperOpacity': 1.0,
              'wallpaperBlurSigma': 0.0,
              'wallpaperFit': 'cover',
              'wallpaperOverlayOpacity': 0.32,
              'readerWallpaperOpacity': 1.0,
              'readerWallpaperBlurSigma': 0.0,
              'readerWallpaperFit': 'cover',
              'readerWallpaperOverlayOpacity': 0.0,
            },
          },
        ]),
      );

      final service = AdvancedThemeService(
        preferences: prefs,
        assetStore: _assetStore(),
      );
      final stateService = _editorStateService(service);

      final router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder:
                (context, state) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () => context.push('/editor'),
                      child: const Text('open-editor'),
                    ),
                  ),
                ),
          ),
          GoRoute(
            path: '/editor',
            builder:
                (context, state) => const AdvancedThemeEditorPage(
                  themeId: 'legacy_theme_editor',
                ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            advancedThemeServiceProvider.overrideWithValue(service),
            advancedThemeEditorStateServiceProvider.overrideWithValue(
              stateService,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      await tester.tap(find.text('open-editor'));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(find.text('旧结构主题'), findsOneWidget);
      await tester.tap(find.byTooltip('保存主题'));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(find.text('open-editor'), findsOneWidget);

      final saved = await service.loadThemeById('legacy_theme_editor');
      expect(saved, isNotNull);
      expect(saved!.lightConfig.colors.primaryColorValue, 0xFF556677);
      expect(saved.lightConfig.colors.cardBorderColorValue, 0xFFD9D3C7);
      expect(saved.lightConfig.colors.shadowColorValue, 0x55334455);
      expect(saved.darkConfig.colors.primaryColorValue, 0xFF99AABB);
      expect(saved.darkConfig.colors.shadowColorValue, 0x66334455);
    },
  );

  testWidgets(
    'advanced theme list renders many themes for active member smoke',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final service = AdvancedThemeService(
        preferences: prefs,
        assetStore: _assetStore(),
      );

      for (var index = 0; index < 50; index += 1) {
        await service.saveTheme(
          AppAdvancedTheme(
            id: 'theme_$index',
            name: '主题 $index',
            createdAt: DateTime.parse('2026-05-07T00:00:00.000Z'),
            updatedAt: DateTime.parse(
              '2026-05-07T00:${(index % 60).toString().padLeft(2, '0')}:00.000Z',
            ),
            lightConfig: AppAdvancedThemeModeConfig(
              colors: AppAdvancedThemeColors(
                primaryColorValue: 0xFF336699 + index,
                backgroundColorValue: 0xFFF5F1E8,
              ),
            ),
            darkConfig: AppAdvancedThemeModeConfig(
              colors: AppAdvancedThemeColors(
                primaryColorValue: 0xFF88AACC + index,
                backgroundColorValue: 0xFF161B22,
              ),
            ),
            category: index.isEven ? '护眼' : '极简',
          ),
        );
      }

      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const AdvancedThemeListPage(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            advancedThemeServiceProvider.overrideWithValue(service),
            mineMembershipServiceProvider.overrideWithValue(
              _FakeMembershipService(),
            ),
            advancedThemePageFlowCoordinatorFactoryProvider.overrideWithValue(
              () => _NoopAdvancedThemePageFlowCoordinator(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('高级主题'), findsOneWidget);
      expect(find.textContaining('主题数量'), findsOneWidget);
      expect(find.textContaining('主题 49'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

ManagedAssetStore _assetStore() {
  return ManagedAssetStore();
}

AdvancedThemeEditorStateService _editorStateService(
  AdvancedThemeService service,
) {
  return AdvancedThemeEditorStateService(
    service: service,
    bottomNavIconGalleryService: BottomNavIconGalleryService(),
    appBackgroundService: AppBackgroundService(),
    coverGalleryService: CoverGalleryService(),
    launchImageGalleryService: LaunchImageGalleryService(),
    readerBackgroundService: ReaderBackgroundService(),
    fontRegistryService: ReaderFontRegistryService(),
  );
}

class _FakeMembershipService extends MembershipService {
  _FakeMembershipService();

  @override
  Future<MembershipEntitlement> fetchEntitlement() async {
    return const MembershipEntitlement(
      vipLevel: 'pro',
      vipStatus: 'active',
      planType: 'year',
      expireAt: null,
      source: 'test',
      membershipLevel: 'pro',
      grantType: 'manual_grant',
      grantSubtype: 'test',
      grantLabel: '测试会员',
      isCustomExpire: false,
      isTrial: false,
      maxDevices: 3,
      features: <String>[MembershipFeatures.themeCustom],
    );
  }
}

class _NoopAdvancedThemePageFlowCoordinator
    extends AdvancedThemePageFlowCoordinator {
  _NoopAdvancedThemePageFlowCoordinator()
    : super(authEvents: const Stream<AuthEvent>.empty());

  @override
  void initialize({
    required VoidCallback onPendingImportAvailable,
    required void Function(AuthEvent event) onAuthEvent,
  }) {}

  @override
  Future<void> consumePendingPayloads(
    AdvancedThemeIncomingImportHandler handler,
  ) async {}

  @override
  Future<CachedExternalImportFile?> cacheExternalFileFromUri(
    IncomingExternalImportPayload payload,
  ) async {
    return null;
  }

  @override
  Future<void> dispose() async {}
}
