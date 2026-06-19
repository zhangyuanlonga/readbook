import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/composition/app_providers.dart';
import 'package:shuxiang_reading_next/app/theme/app_official_theme_presets.dart';
import 'package:shuxiang_reading_next/core/auth/auth_event_bus.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/membership/membership_access_service.dart';
import 'package:shuxiang_reading_next/core/membership/membership_entitlement.dart';
import 'package:shuxiang_reading_next/core/membership/membership_service.dart';
import 'package:shuxiang_reading_next/core/storage/managed_asset_store.dart';
import 'package:shuxiang_reading_next/core/user/user_profile.dart';
import 'package:shuxiang_reading_next/core/user/user_profile_service.dart';
import 'package:shuxiang_reading_next/features/auth/providers.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_provider.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_service.dart';
import 'package:shuxiang_reading_next/features/mine/providers.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_dependencies_provider.dart';
import 'package:shuxiang_reading_next/features/search/providers.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_service.dart';

import '../../test_utils/fake_auth_session_secret_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('appSourceHealthServiceProvider', () {
    test('creates a provider-managed service instead of reusing singleton', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(appSourceHealthServiceProvider);

      expect(service, isA<SourceHealthService>());
      expect(identical(service, SourceHealthService.instance), isFalse);
    });

    test('can be overridden for feature dependency factories', () {
      final sourceHealthService = SourceHealthService();
      final container = ProviderContainer(
        overrides: <Override>[
          appSourceHealthServiceProvider.overrideWithValue(sourceHealthService),
        ],
      );
      addTearDown(container.dispose);

      final dependencies =
          container.read(readerFeatureDependenciesFactoryProvider)();

      expect(dependencies.sourceHealthService, same(sourceHealthService));
    });
  });

  group('membership access providers', () {
    test('mine session providers reuse auth session providers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(mineAuthSessionStoreProvider),
        same(container.read(authSessionStoreProvider)),
      );
      expect(
        container.read(mineAuthSessionSecretStoreProvider),
        same(container.read(authSessionSecretStoreProvider)),
      );
      expect(
        container.read(mineUserProfileServiceProvider),
        same(container.read(userProfileServiceProvider)),
      );
    });

    test('reader dependencies reuse app membership access service', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final dependencies =
          container.read(readerFeatureDependenciesFactoryProvider)();

      expect(
        dependencies.membershipAccessService,
        same(container.read(appMembershipAccessServiceProvider)),
      );
    });

    test(
      'profile lifetime membership grants online search and advanced theme gates',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final sessionStore = AuthSessionStore(
          preferences: prefs,
          secretStore: FakeAuthSessionSecretStore(),
        );
        await sessionStore.saveSession(
          const AuthSession(accessToken: 'access_member', userId: 'member_1'),
        );
        final service = MembershipAccessService(
          sessionStore: sessionStore,
          membershipService: _FailingMembershipService(),
          userProfileService: _ProfileMembershipService(
            const UserProfile(
              userId: 'member_1',
              username: 'reader',
              account: 'reader@example.com',
              displayName: 'Reader',
              phone: null,
              email: null,
              role: 'user',
              createdAt: null,
              membershipActive: true,
              vipLevel: 'pro',
              planType: 'lifetime',
              vipStatus: 'active',
              vipExpireAt: null,
              features: <String>[],
            ),
          ),
        );
        final container = ProviderContainer(
          overrides: <Override>[
            appMembershipAccessServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(container.dispose);

        final access = await container.read(
          appMembershipAccessSnapshotProvider.future,
        );

        expect(container.read(searchMembershipAccessServiceProvider), service);
        expect(access.hasOnlineService, isTrue);
        expect(access.hasThemeCustom, isTrue);
        expect(access.planType, 'lifetime');
      },
    );

    test('session lifetime membership grants shared feature gates', () async {
      final prefs = await SharedPreferences.getInstance();
      final sessionStore = AuthSessionStore(
        preferences: prefs,
        secretStore: FakeAuthSessionSecretStore(),
      );
      await sessionStore.saveSession(
        const AuthSession(
          accessToken: 'access_lifetime',
          userId: 'member_2',
          membershipActive: true,
          vipLevel: 'pro',
          planType: 'lifetime',
          vipStatus: 'active',
        ),
      );
      final service = MembershipAccessService(
        sessionStore: sessionStore,
        membershipService: _FailingMembershipService(),
        userProfileService: _FailingUserProfileService(),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          appMembershipAccessServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final access = await container.read(
        appMembershipAccessSnapshotProvider.future,
      );

      expect(access.hasOnlineService, isTrue);
      expect(access.hasThemeCustom, isTrue);
      expect(access.planType, 'lifetime');
    });

    test(
      'clears active advanced theme when membership access is revoked',
      () async {
        final pathProviderDocsDir = await Directory.systemTemp.createTemp(
          'app_providers_path_docs_',
        );
        final pathProviderSupportDir = await Directory.systemTemp.createTemp(
          'app_providers_path_support_',
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathProviderChannel, (call) async {
              if (call.method == 'getApplicationDocumentsDirectory') {
                return pathProviderDocsDir.path;
              }
              if (call.method == 'getApplicationSupportDirectory') {
                return pathProviderSupportDir.path;
              }
              return null;
            });
        addTearDown(() async {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(pathProviderChannel, null);
          if (pathProviderDocsDir.existsSync()) {
            await pathProviderDocsDir.delete(recursive: true);
          }
          if (pathProviderSupportDir.existsSync()) {
            await pathProviderSupportDir.delete(recursive: true);
          }
        });
        final prefs = await SharedPreferences.getInstance();
        final sessionStore = AuthSessionStore(
          preferences: prefs,
          secretStore: FakeAuthSessionSecretStore(),
        );
        await sessionStore.saveSession(
          const AuthSession(
            accessToken: 'access_expired',
            userId: 'expired_member',
            membershipActive: false,
            vipLevel: 'normal',
            vipStatus: 'expired',
          ),
        );
        final membershipAccessService = MembershipAccessService(
          sessionStore: sessionStore,
          membershipService: _FailingMembershipService(),
          userProfileService: _FailingUserProfileService(),
        );
        final advancedThemeService = await _createAdvancedThemeService(prefs);
        await advancedThemeService.saveActiveThemeId('theme_to_clear');
        final container = ProviderContainer(
          overrides: <Override>[
            appMembershipAccessServiceProvider.overrideWithValue(
              membershipAccessService,
            ),
            advancedThemeServiceProvider.overrideWithValue(
              advancedThemeService,
            ),
          ],
        );
        addTearDown(container.dispose);

        final access = await container.read(
          appMembershipAccessSnapshotProvider.future,
        );

        expect(access.hasThemeCustom, isFalse);
        expect(
          await advancedThemeService.loadActiveThemeId(),
          appDefaultOfficialThemeId,
        );
        expect(
          container.read(activeAdvancedThemeIdProvider),
          appDefaultOfficialThemeId,
        );
      },
    );

    test('membership revocation keeps official theme active', () async {
      final pathProviderDocsDir = await Directory.systemTemp.createTemp(
        'app_providers_official_theme_docs_',
      );
      final pathProviderSupportDir = await Directory.systemTemp.createTemp(
        'app_providers_official_theme_support_',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (call) async {
            if (call.method == 'getApplicationDocumentsDirectory') {
              return pathProviderDocsDir.path;
            }
            if (call.method == 'getApplicationSupportDirectory') {
              return pathProviderSupportDir.path;
            }
            return null;
          });
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathProviderChannel, null);
        if (pathProviderDocsDir.existsSync()) {
          await pathProviderDocsDir.delete(recursive: true);
        }
        if (pathProviderSupportDir.existsSync()) {
          await pathProviderSupportDir.delete(recursive: true);
        }
      });
      final prefs = await SharedPreferences.getInstance();
      final sessionStore = AuthSessionStore(
        preferences: prefs,
        secretStore: FakeAuthSessionSecretStore(),
      );
      await sessionStore.saveSession(
        const AuthSession(
          accessToken: 'access_expired',
          userId: 'expired_member',
          membershipActive: false,
          vipLevel: 'normal',
          vipStatus: 'expired',
        ),
      );
      final membershipAccessService = MembershipAccessService(
        sessionStore: sessionStore,
        membershipService: _FailingMembershipService(),
        userProfileService: _FailingUserProfileService(),
      );
      final advancedThemeService = await _createAdvancedThemeService(prefs);
      await advancedThemeService.saveActiveThemeId(
        AppOfficialThemePresetId.inkGreen.themeId,
      );
      final container = ProviderContainer(
        overrides: <Override>[
          appMembershipAccessServiceProvider.overrideWithValue(
            membershipAccessService,
          ),
          advancedThemeServiceProvider.overrideWithValue(advancedThemeService),
        ],
      );
      addTearDown(container.dispose);

      final access = await container.read(
        appMembershipAccessSnapshotProvider.future,
      );

      expect(access.hasThemeCustom, isFalse);
      expect(
        await advancedThemeService.loadActiveThemeId(),
        AppOfficialThemePresetId.inkGreen.themeId,
      );
    });

    test('membership snapshot refreshes after account events', () async {
      final prefs = await SharedPreferences.getInstance();
      final sessionStore = AuthSessionStore(
        preferences: prefs,
        secretStore: FakeAuthSessionSecretStore(),
      );
      const regularSession = AuthSession(
        accessToken: 'access_regular',
        userId: 'regular_user',
        membershipActive: false,
        vipLevel: 'normal',
        vipStatus: 'expired',
      );
      const memberSession = AuthSession(
        accessToken: 'access_member',
        userId: 'member_user',
        membershipActive: true,
        vipLevel: 'pro',
        planType: 'lifetime',
        vipStatus: 'active',
      );
      await sessionStore.saveSession(regularSession);
      final authEvents = StreamController<AuthEvent>.broadcast();
      addTearDown(authEvents.close);
      final service = MembershipAccessService(
        sessionStore: sessionStore,
        membershipService: _FailingMembershipService(),
        userProfileService: _FailingUserProfileService(),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          appAuthEventStreamProvider.overrideWithValue(authEvents.stream),
          appMembershipAccessServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        appMembershipAccessSnapshotProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final initial = await container.read(
        appMembershipAccessSnapshotProvider.future,
      );
      expect(initial.hasMembership, isFalse);

      await sessionStore.saveSession(memberSession);
      authEvents.add(
        const AuthEvent(
          type: AuthEventType.loggedIn,
          message: '登录成功。',
          session: memberSession,
          previousSession: regularSession,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final afterLogin = await container.read(
        appMembershipAccessSnapshotProvider.future,
      );
      expect(afterLogin.hasOnlineService, isTrue);
      expect(afterLogin.hasThemeCustom, isTrue);

      await sessionStore.clear();
      authEvents.add(
        const AuthEvent(
          type: AuthEventType.loggedOut,
          message: '已退出登录。',
          previousSession: memberSession,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final afterLogout = await container.read(
        appMembershipAccessSnapshotProvider.future,
      );
      expect(afterLogout.hasMembership, isFalse);

      await sessionStore.saveSession(memberSession);
      authEvents.add(
        const AuthEvent(
          type: AuthEventType.loggedIn,
          message: '注册成功。',
          session: memberSession,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        (await container.read(
          appMembershipAccessSnapshotProvider.future,
        )).hasMembership,
        isTrue,
      );

      await sessionStore.clear();
      authEvents.add(
        const AuthEvent(
          type: AuthEventType.sessionExpired,
          message: '登录已过期，请重新登录。',
          previousSession: memberSession,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        (await container.read(
          appMembershipAccessSnapshotProvider.future,
        )).hasMembership,
        isFalse,
      );
    });
  });
}

class _FailingMembershipService extends MembershipService {
  _FailingMembershipService() : super(baseUrl: 'https://example.com');

  @override
  Future<MembershipEntitlement> fetchEntitlement() async {
    throw StateError('membership network disabled in smoke test');
  }
}

class _ProfileMembershipService extends UserProfileService {
  _ProfileMembershipService(this._profile)
    : super(baseUrl: 'https://example.com');

  final UserProfile _profile;

  @override
  Future<UserProfile> fetchMe({
    String? accessToken,
    bool enableAuthRefresh = true,
  }) async => _profile;
}

class _FailingUserProfileService extends UserProfileService {
  _FailingUserProfileService() : super(baseUrl: 'https://example.com');

  @override
  Future<UserProfile> fetchMe({
    String? accessToken,
    bool enableAuthRefresh = true,
  }) async {
    throw StateError('profile network disabled in smoke test');
  }
}

Future<AdvancedThemeService> _createAdvancedThemeService(
  SharedPreferences prefs,
) async {
  final documentsDir = await Directory.systemTemp.createTemp(
    'app_providers_theme_docs_',
  );
  final supportDir = await Directory.systemTemp.createTemp(
    'app_providers_theme_support_',
  );
  addTearDown(() async {
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
    if (supportDir.existsSync()) {
      await supportDir.delete(recursive: true);
    }
  });
  return AdvancedThemeService(
    preferences: prefs,
    assetStore: ManagedAssetStore(
      documentsDirectoryProvider: () async => documentsDir,
      supportDirectoryProvider: () async => supportDir,
    ),
  );
}
