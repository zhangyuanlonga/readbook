import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shuxiang_reading_next/core/auth/auth_event_bus.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/auth/auth_service.dart';
import 'package:shuxiang_reading_next/core/membership/membership_service.dart';
import 'package:shuxiang_reading_next/core/mobile_features/mobile_feature_service.dart';
import 'package:shuxiang_reading_next/core/user/user_profile_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_page.dart';
import 'package:shuxiang_reading_next/features/auth/providers.dart';
import 'package:shuxiang_reading_next/features/mine/application/mine_page_session_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/remote_access_snapshot_service.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/mine_page.dart';
import 'package:shuxiang_reading_next/features/mine/providers.dart';
import 'package:shuxiang_reading_next/features/search/presentation/search_page.dart';

import '../../test_utils/adaptive_test_harness.dart';
import '../../test_utils/fake_auth_session_secret_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('BookshelfPage renders on phone and large screens', (
    tester,
  ) async {
    await runAdaptivePageSmokeMatrix(
      tester,
      pageBuilder: () => const BookshelfPage(prefetchAnnouncementOnInit: false),
      useProviderScope: true,
      pageName: 'BookshelfPage',
    );
  });

  testWidgets('MinePage renders on phone and large screens', (tester) async {
    await runAdaptivePageSmokeMatrix(
      tester,
      pageBuilder: () => const MinePage(),
      useProviderScope: true,
      pageName: 'MinePage',
    );
  });

  testWidgets('MinePage uses desktop profile card on desktop platform', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: const MinePage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey<String>('mine_desktop_profile_card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('mine_mobile_profile_card')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'MinePage renders with secure auth session after startup priming',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth.user_id': 'user_smoke',
        'auth.username': 'reader_smoke',
        'auth.display_name': 'Reader Smoke',
      });
      final prefs = await SharedPreferences.getInstance();
      MinePageSessionPriming.prime(prefs);
      final sessionStore = AuthSessionStore(
        preferences: prefs,
        secretStore: FakeAuthSessionSecretStore(),
      );
      await sessionStore.saveSession(
        const AuthSession(
          accessToken: 'secure_token',
          refreshToken: 'secure_refresh',
          userId: 'user_smoke',
          username: 'reader_smoke',
          displayName: 'Reader Smoke',
        ),
      );

      await runAdaptivePageSmokeMatrix(
        tester,
        pageBuilder: () => const MinePage(),
        pageName: 'MinePageSecureSession',
        overrides: <Override>[
          mineAuthSessionStoreProvider.overrideWithValue(sessionStore),
        ],
        cases: const <AdaptiveViewportCase>[
          AdaptiveViewportCase(name: 'phone_390', size: Size(390, 844), dpr: 3),
          AdaptiveViewportCase(
            name: 'desktop_1280',
            size: Size(1280, 800),
            dpr: 1,
          ),
        ],
      );
    },
  );

  testWidgets('MinePage refreshes remote access after cached session load', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });

    final sessionService = _MembershipAwareMinePageSessionService(
      cachedHasMembership: false,
      remoteHasMembership: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          minePageSessionServiceProvider.overrideWithValue(sessionService),
        ],
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: const MinePage(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(
      sessionService.refreshRemoteRequests.length,
      greaterThanOrEqualTo(2),
    );
    expect(sessionService.refreshRemoteRequests[0], isFalse);
    expect(sessionService.refreshRemoteRequests[1], isTrue);
    expect(find.widgetWithText(OutlinedButton, '查看权益'), findsOneWidget);
  });

  testWidgets('MinePage refreshes when membership snapshot revision changes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });

    final sessionService = _MembershipAwareMinePageSessionService(
      cachedHasMembership: false,
      remoteHasMembership: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          minePageSessionServiceProvider.overrideWithValue(sessionService),
        ],
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: const MinePage(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.widgetWithText(FilledButton, '开通会员'), findsOneWidget);

    sessionService.remoteHasMembership = true;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MinePage)),
      listen: false,
    );
    container
        .read(mineRemoteAccessSnapshotRevisionProvider.notifier)
        .update((value) => value + 1);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(sessionService.refreshRemoteRequests.last, isTrue);
    expect(find.widgetWithText(OutlinedButton, '查看权益'), findsOneWidget);
  });

  testWidgets('MinePage opens membership center from profile membership card', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });

    final sessionService = _MembershipAwareMinePageSessionService(
      cachedHasMembership: false,
      remoteHasMembership: false,
    );
    final router = GoRouter(
      initialLocation: '/mine',
      routes: <RouteBase>[
        GoRoute(path: '/mine', builder: (context, state) => const MinePage()),
        GoRoute(
          path: '/membership',
          builder: (context, state) => const _MineTestMembershipPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          minePageSessionServiceProvider.overrideWithValue(sessionService),
        ],
        child: MaterialApp.router(
          theme: ThemeData(platform: TargetPlatform.macOS),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.widgetWithText(FilledButton, '开通会员'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('mine_profile_membership_action_button'),
      ),
      findsOneWidget,
    );
    expect(find.text('会员中心测试页'), findsNothing);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('mine_profile_membership_action_button'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('会员中心测试页'), findsOneWidget);
  });

  testWidgets('MinePage guest profile card opens auth', (tester) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/mine',
      routes: <RouteBase>[
        GoRoute(path: '/mine', builder: (context, state) => const MinePage()),
        GoRoute(
          path: '/auth',
          builder: (context, state) => const _MineTestAuthPage(),
        ),
        GoRoute(
          path: '/membership',
          builder: (context, state) => const _MineTestMembershipPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: ThemeData(platform: TargetPlatform.android),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey<String>('mine_mobile_profile_card')),
      findsOneWidget,
    );
    expect(find.text('登录测试页'), findsNothing);
    expect(find.text('会员中心测试页'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('mine_mobile_profile_card')),
    );
    await tester.pumpAndSettle();

    expect(find.text('登录测试页'), findsOneWidget);
    expect(find.text('会员中心测试页'), findsNothing);
  });

  testWidgets(
    'MinePage profile card opens profile and logout button confirms logout',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
        tester.view.resetDevicePixelRatio();
      });

      final prefs = await SharedPreferences.getInstance();
      final secretStore = FakeAuthSessionSecretStore();
      final sessionStore = AuthSessionStore(
        preferences: prefs,
        secretStore: secretStore,
      );
      final sessionService = _ScriptedMinePageSessionService(
        sessionStore: sessionStore,
      );
      final authService = _MinePageLogoutAuthService(sessionStore);
      await sessionService.saveSession(
        const AuthSession(
          accessToken: 'old_access',
          refreshToken: 'old_refresh',
          userId: 'old_user',
          username: 'old@example.com',
          displayName: 'Old Reader',
        ),
      );

      final router = GoRouter(
        initialLocation: '/mine',
        routes: <RouteBase>[
          GoRoute(path: '/mine', builder: (context, state) => const MinePage()),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const _MineTestProfilePage(),
          ),
          GoRoute(
            path: '/auth',
            builder: (context, state) => const _MineTestAuthPage(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            authSessionStoreProvider.overrideWithValue(sessionStore),
            authSessionSecretStoreProvider.overrideWithValue(secretStore),
            authServiceProvider.overrideWithValue(authService),
            mineAuthSessionStoreProvider.overrideWithValue(sessionStore),
            mineAuthSessionSecretStoreProvider.overrideWithValue(secretStore),
            minePageSessionServiceProvider.overrideWithValue(sessionService),
          ],
          child: MaterialApp.router(
            theme: ThemeData(platform: TargetPlatform.macOS),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Old Reader'), findsWidgets);

      sessionService.holdNextLoad();
      AuthEventBus.instance.emitLoggedIn();
      await tester.pump();
      await sessionService.saveSession(
        const AuthSession(
          accessToken: 'new_access',
          refreshToken: 'new_refresh',
          userId: 'new_user',
          username: 'new@example.com',
          displayName: 'New Reader',
        ),
      );
      AuthEventBus.instance.emitLoggedIn();
      await tester.pump(const Duration(milliseconds: 300));
      sessionService.completeHeldLoad();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('New Reader'), findsWidgets);
      expect(find.text('Old Reader'), findsNothing);

      final profileCardRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('mine_desktop_profile_card_tap_area'),
        ),
      );
      await tester.tapAt(profileCardRect.topLeft + const Offset(48, 42));
      await tester.pumpAndSettle();

      expect(find.text('账号信息测试页'), findsOneWidget);
      expect(await sessionStore.getSession(), isNotNull);
      expect(authService.logoutCount, 0);

      router.go('/mine');
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('mine_desktop_profile_action_button'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('确定要退出当前账号吗？'), findsOneWidget);
      expect(await sessionStore.getSession(), isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, '退出'));
      await tester.pumpAndSettle();

      expect(await sessionStore.getSession(), isNull);
      expect(authService.logoutCount, 1);
      expect(find.text('登录 / 注册'), findsWidgets);
    },
  );

  testWidgets('SearchPage renders on phone and large screens', (tester) async {
    await runAdaptivePageSmokeMatrix(
      tester,
      pageBuilder: () => const SearchPage(),
      useProviderScope: true,
      pageName: 'SearchPage',
    );
  });
}

class _MineTestProfilePage extends StatelessWidget {
  const _MineTestProfilePage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('账号信息测试页')));
  }
}

class _MineTestAuthPage extends StatelessWidget {
  const _MineTestAuthPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('登录测试页')));
  }
}

class _MineTestMembershipPage extends StatelessWidget {
  const _MineTestMembershipPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('会员中心测试页')));
  }
}

class _ScriptedMinePageSessionService extends MinePageSessionService {
  _ScriptedMinePageSessionService({required this.sessionStore})
    : super(
        authSessionStore: sessionStore,
        mobileFeatureService: _UnusedMobileFeatureService(),
        membershipService: _UnusedMembershipService(),
        userProfileService: _UnusedUserProfileService(),
        remoteAccessSnapshotService: _UnusedRemoteAccessSnapshotService(),
      );

  final AuthSessionStore sessionStore;
  Completer<void>? _heldLoad;

  void holdNextLoad() {
    _heldLoad = Completer<void>();
  }

  void completeHeldLoad() {
    final held = _heldLoad;
    _heldLoad = null;
    held?.complete();
  }

  Future<void> saveSession(AuthSession session) {
    return sessionStore.saveSession(session);
  }

  @override
  Future<MinePageSessionSnapshot> loadSession({
    bool refreshRemote = true,
  }) async {
    final held = _heldLoad;
    if (held != null) {
      await held.future;
    }
    final session = await sessionStore.getSession();
    return MinePageSessionSnapshot(
      session: session,
      localAvatarPath: null,
      serverSourceGatewayEnabled: false,
      hasMembership: false,
      hasThemeCustom: false,
      serverSourceGatewayLimit: 10,
      isRemoteAccessResolved: true,
      shouldRefreshRemoteAccess: false,
      vipExpireAt: null,
      membershipPlanType: null,
      totalReadingHours: 0,
      readingStreakDays: 0,
    );
  }

  @override
  Future<void> clearUserScopedCache(String? userId) async {}
}

class _MembershipAwareMinePageSessionService extends MinePageSessionService {
  _MembershipAwareMinePageSessionService({
    required this.cachedHasMembership,
    required this.remoteHasMembership,
  }) : super(
         authSessionStore: AuthSessionStore(
           secretStore: FakeAuthSessionSecretStore(),
         ),
         mobileFeatureService: _UnusedMobileFeatureService(),
         membershipService: _UnusedMembershipService(),
         userProfileService: _UnusedUserProfileService(),
         remoteAccessSnapshotService: _UnusedRemoteAccessSnapshotService(),
       );

  final bool cachedHasMembership;
  bool remoteHasMembership;
  final List<bool> refreshRemoteRequests = <bool>[];

  @override
  Future<MinePageSessionSnapshot> loadSession({
    bool refreshRemote = true,
  }) async {
    refreshRemoteRequests.add(refreshRemote);
    final hasMembership =
        refreshRemote ? remoteHasMembership : cachedHasMembership;
    return MinePageSessionSnapshot(
      session: const AuthSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        userId: 'member_user',
        username: 'member@example.com',
        displayName: 'Member Reader',
      ),
      localAvatarPath: null,
      serverSourceGatewayEnabled: false,
      hasMembership: hasMembership,
      hasThemeCustom: hasMembership,
      serverSourceGatewayLimit: 10,
      isRemoteAccessResolved: true,
      shouldRefreshRemoteAccess: false,
      vipExpireAt: null,
      membershipPlanType: hasMembership ? 'lifetime' : null,
      totalReadingHours: 0,
      readingStreakDays: 0,
    );
  }

  @override
  Future<void> clearUserScopedCache(String? userId) async {}
}

class _MinePageLogoutAuthService extends AuthService {
  _MinePageLogoutAuthService(this.sessionStore)
    : super(baseUrl: 'https://example.com', sessionStore: sessionStore);

  final AuthSessionStore sessionStore;
  int logoutCount = 0;

  @override
  Future<void> logout({String? refreshToken}) async {
    logoutCount += 1;
    await sessionStore.clear();
    AuthEventBus.instance.emitLoggedOut();
  }
}

class _UnusedMobileFeatureService extends MobileFeatureService {
  _UnusedMobileFeatureService() : super(baseUrl: 'https://example.com');
}

class _UnusedMembershipService extends MembershipService {
  _UnusedMembershipService() : super(baseUrl: 'https://example.com');
}

class _UnusedUserProfileService extends UserProfileService {
  _UnusedUserProfileService() : super(baseUrl: 'https://example.com');
}

class _UnusedRemoteAccessSnapshotService extends RemoteAccessSnapshotService {}
