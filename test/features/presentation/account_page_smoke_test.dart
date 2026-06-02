import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/router.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_service.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_secret_store.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/user/user_profile_service.dart';
import 'package:shuxiang_reading_next/domain/entities/announcement.dart';
import 'package:shuxiang_reading_next/features/announcement/application/announcement_read_state_service.dart';
import 'package:shuxiang_reading_next/features/announcement/application/announcement_service.dart';
import 'package:shuxiang_reading_next/features/announcement/presentation/announcement_list_page.dart';
import 'package:shuxiang_reading_next/features/announcement/providers.dart';
import 'package:shuxiang_reading_next/features/auth/presentation/auth_page.dart';
import 'package:shuxiang_reading_next/features/auth/presentation/user_profile_page.dart';
import 'package:shuxiang_reading_next/features/auth/providers.dart';
import 'package:shuxiang_reading_next/features/error/presentation/error_center_page.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/about_page.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/feedback_page.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/membership_center_page.dart';
import 'package:shuxiang_reading_next/features/mine/providers.dart' as mine;

import '../../test_utils/adaptive_test_harness.dart';
import '../../test_utils/fake_auth_session_secret_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('AuthPage renders on phone and large screens', (tester) async {
    await runAdaptivePageSmokeMatrix(
      tester,
      pageBuilder: () => const AuthPage(),
      useProviderScope: true,
      pageName: 'AuthPage',
    );
  });

  testWidgets('desktop root startup opens auth route by default', (
    tester,
  ) async {
    await registerAdaptiveViewportTearDown(tester);
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    String? startupLocation;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: Builder(
          builder: (context) {
            startupLocation = resolveAppRootStartupLocation(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(startupLocation, '/auth');
  });

  testWidgets('AuthPage renders desktop web-like login route constraints', (
    tester,
  ) async {
    await registerAdaptiveViewportTearDown(tester);
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(1490, 948));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: const AuthPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('欢迎回来。请登录您的账户。'), findsWidgets);
    expect(find.text('Selune'), findsWidgets);
    expect(find.text('静心阅读，\n久一点。'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('auth_desktop_brand_panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('auth_desktop_compact_header')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('auth_desktop_surface')),
      findsOneWidget,
    );
  });

  testWidgets(
    'AuthPage uses compact desktop login layout at small desktop width',
    (tester) async {
      await registerAdaptiveViewportTearDown(tester);
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(840, 900));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.macOS),
            home: const AuthPage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('auth_desktop_compact_header')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('auth_desktop_brand_panel')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('auth_desktop_surface')),
        findsOneWidget,
      );
    },
  );

  testWidgets('desktop auth login persists session and navigates to home', (
    tester,
  ) async {
    await registerAdaptiveViewportTearDown(tester);
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(1280, 800));

    final prefs = await SharedPreferences.getInstance();
    final secretStore = FakeAuthSessionSecretStore();
    final sessionStore = AuthSessionStore(
      preferences: prefs,
      secretStore: secretStore,
    );
    final authService = _FakeSuccessfulAuthService(sessionStore);
    final router = GoRouter(
      initialLocation: '/auth',
      routes: [
        GoRoute(path: '/auth', builder: (context, state) => const AuthPage()),
        GoRoute(
          path: '/home',
          builder: (context, state) => const _AuthTestLandingPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authSessionStoreProvider.overrideWithValue(sessionStore),
          authSessionSecretStoreProvider.overrideWithValue(secretStore),
          authServiceProvider.overrideWithValue(authService),
        ],
        child: MaterialApp.router(
          theme: ThemeData(platform: TargetPlatform.macOS),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'reader@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, '立即登录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('已登录落点'), findsOneWidget);
    expect(await sessionStore.getAccessToken(), 'desktop_access_token');
    final session = await sessionStore.getSession();
    expect(session, isNotNull);
    expect(session?.userId, 'desktop_user');
    expect(session?.displayName, 'Desktop Reader');
  });

  testWidgets(
    'desktop root startup opens app destination when auth snapshot exists',
    (tester) async {
      await registerAdaptiveViewportTearDown(tester);
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth.user_id': 'desktop_user',
        'auth.display_name': 'Desktop Reader',
        authSecretFallbackAccessTokenStorageKey: 'desktop_access_token',
      });
      final prefs = await SharedPreferences.getInstance();
      AuthSessionSnapshotBootstrap.prime(prefs);

      String? startupLocation;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: Builder(
            builder: (context) {
              startupLocation = resolveAppRootStartupLocation(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(startupLocation, '/home');
    },
  );

  testWidgets('AnnouncementListPage renders on phone and large screens', (
    tester,
  ) async {
    await runAdaptivePageSmokeMatrix(
      tester,
      pageBuilder: () => const AnnouncementListPage(),
      pageName: 'AnnouncementListPage',
      overrides: <Override>[
        announcementServiceProvider.overrideWith((ref) {
          return _FakeAnnouncementService();
        }),
        announcementReadStateServiceProvider.overrideWith((ref) {
          return _FakeAnnouncementReadStateService();
        }),
      ],
    );
  });

  testWidgets('AboutPage renders on phone and large screens', (tester) async {
    await runAdaptivePageSmokeMatrix(
      tester,
      pageBuilder: () => const AboutPage(),
      useProviderScope: true,
      pageName: 'AboutPage',
    );
  });

  testWidgets('ErrorCenterPage renders on phone and large screens', (
    tester,
  ) async {
    await runAdaptivePageSmokeMatrix(
      tester,
      pageBuilder: () => const ErrorCenterPage(),
      useProviderScope: true,
      pageName: 'ErrorCenterPage',
    );
  });

  testWidgets('UserProfilePage renders on phone and large screens', (
    tester,
  ) async {
    await runAdaptivePageSmokeMatrix(
      tester,
      pageBuilder: () => const UserProfilePage(),
      pageName: 'UserProfilePage',
      overrides: <Override>[
        authSessionStoreProvider.overrideWith((ref) {
          return _FakeAuthSessionStore();
        }),
        userProfileServiceProvider.overrideWith((ref) {
          return _FakeUserProfileService();
        }),
      ],
    );
  });

  testWidgets('MembershipCenterPage renders on phone and large screens', (
    tester,
  ) async {
    await runAdaptivePageSmokeMatrix(
      tester,
      pageBuilder: () => const MembershipCenterPage(),
      pageName: 'MembershipCenterPage',
      overrides: <Override>[
        mine.mineAuthSessionStoreProvider.overrideWith((ref) {
          return _FakeAuthSessionStore();
        }),
      ],
    );
  });

  testWidgets('FeedbackComposePage renders on phone and large screens', (
    tester,
  ) async {
    await runAdaptivePageSmokeMatrix(
      tester,
      pageBuilder: () => const FeedbackComposePage(),
      useProviderScope: true,
      pageName: 'FeedbackComposePage',
    );
  });
}

class _FakeAnnouncementService extends AnnouncementService {
  static final Announcement _announcement = Announcement(
    id: 'announcement_1',
    title: '测试公告',
    content: '测试内容',
    level: AnnouncementLevel.info,
    publishFrom: DateTime.parse('2026-04-27T00:00:00.000Z'),
    publishTo: null,
    isActive: true,
    createdAt: DateTime.parse('2026-04-27T00:00:00.000Z'),
    updatedAt: DateTime.parse('2026-04-27T00:00:00.000Z'),
  );

  @override
  Future<AnnouncementPage> fetchAnnouncements({
    int page = 1,
    int pageSize = 20,
    bool useCache = true,
  }) async {
    return AnnouncementPage(
      items: <Announcement>[_announcement],
      page: 1,
      pageSize: 20,
      total: 1,
    );
  }

  @override
  Future<Announcement?> fetchLatestAnnouncement({bool useCache = true}) async {
    return _announcement;
  }

  @override
  void clearCache() {}
}

class _FakeAnnouncementReadStateService extends AnnouncementReadStateService {
  @override
  Future<Set<String>> getReadIds() async => const <String>{};
}

class _FakeAuthSessionStore extends AuthSessionStore {
  @override
  Future<AuthSession?> getSession() async => null;
}

class _FakeUserProfileService extends UserProfileService {}

class _FakeSuccessfulAuthService extends AuthService {
  _FakeSuccessfulAuthService(this._sessionStore)
    : super(baseUrl: 'https://example.com', sessionStore: _sessionStore);

  final AuthSessionStore _sessionStore;

  @override
  Future<AuthSession> loginAndStore({
    required String account,
    required String password,
  }) async {
    const session = AuthSession(
      accessToken: 'desktop_access_token',
      refreshToken: 'desktop_refresh_token',
      userId: 'desktop_user',
      username: 'reader@example.com',
      account: 'reader@example.com',
      displayName: 'Desktop Reader',
    );
    await _sessionStore.saveSession(session);
    return session;
  }
}

class _AuthTestLandingPage extends StatelessWidget {
  const _AuthTestLandingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('已登录落点')));
  }
}
