import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shuxiang_reading_next/core/auth/auth_event_bus.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/membership/membership_service.dart';
import 'package:shuxiang_reading_next/core/mobile_features/mobile_feature_service.dart';
import 'package:shuxiang_reading_next/core/user/user_profile.dart';
import 'package:shuxiang_reading_next/core/user/user_profile_service.dart';
import 'package:shuxiang_reading_next/features/auth/presentation/user_profile_page.dart';
import 'package:shuxiang_reading_next/features/auth/providers.dart';
import 'package:shuxiang_reading_next/features/mine/application/mine_page_session_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/remote_access_snapshot_service.dart';
import 'package:shuxiang_reading_next/features/mine/providers.dart';

import '../../../test_utils/fake_auth_session_secret_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'UserProfilePage ignores stale profile loads after account switch',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      await tester.binding.setSurfaceSize(const Size(390, 844));
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
      const oldSession = AuthSession(
        accessToken: 'old_access',
        refreshToken: 'old_refresh',
        userId: 'old_user',
        username: 'old@example.com',
        account: 'old@example.com',
        displayName: 'Old Reader',
        membershipActive: false,
      );
      const memberSession = AuthSession(
        accessToken: 'member_access',
        refreshToken: 'member_refresh',
        userId: 'member_user',
        username: 'member@example.com',
        account: 'member@example.com',
        displayName: 'Member Reader',
        membershipActive: true,
        vipLevel: 'premium',
        planType: 'lifetime',
        vipStatus: 'active',
      );
      await sessionStore.saveSession(oldSession);

      final profileService = _SwitchingUserProfileService();
      final router = GoRouter(
        initialLocation: '/profile',
        routes: <RouteBase>[
          GoRoute(
            path: '/profile',
            builder: (context, state) => const UserProfilePage(),
          ),
          GoRoute(path: '/mine', builder: (context, state) => const Scaffold()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            authSessionStoreProvider.overrideWithValue(sessionStore),
            authSessionSecretStoreProvider.overrideWithValue(secretStore),
            userProfileServiceProvider.overrideWithValue(profileService),
            minePageSessionServiceProvider.overrideWithValue(
              _UserProfileTestMinePageSessionService(sessionStore),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Old Reader'), findsWidgets);
      expect(profileService.fetchCount, 1);

      await sessionStore.saveSession(memberSession);
      AuthEventBus.instance.emitLoggedIn('登录成功。', memberSession, oldSession);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(profileService.fetchCount, 2);
      expect(find.text('Member Reader'), findsWidgets);
      expect(find.text('Old Reader'), findsNothing);
      expect(find.text('永久有效'), findsOneWidget);

      profileService.completeOldProfile();
      await tester.pumpAndSettle();

      expect(find.text('Member Reader'), findsWidgets);
      expect(find.text('Old Reader'), findsNothing);
      expect(find.text('永久有效'), findsOneWidget);
    },
  );
}

class _SwitchingUserProfileService extends UserProfileService {
  _SwitchingUserProfileService() : super(baseUrl: 'https://example.com');

  final Completer<UserProfile> _oldProfileCompleter = Completer<UserProfile>();
  int fetchCount = 0;

  @override
  Future<UserProfile> fetchMe() {
    fetchCount += 1;
    if (fetchCount == 1) {
      return _oldProfileCompleter.future;
    }
    return Future<UserProfile>.value(
      _profile(
        userId: 'member_user',
        username: 'member@example.com',
        displayName: 'Member Reader',
        membershipActive: true,
        vipLevel: 'premium',
        planType: 'lifetime',
        vipStatus: 'active',
      ),
    );
  }

  void completeOldProfile() {
    if (_oldProfileCompleter.isCompleted) {
      return;
    }
    _oldProfileCompleter.complete(
      _profile(
        userId: 'old_user',
        username: 'old@example.com',
        displayName: 'Old Reader',
        membershipActive: false,
      ),
    );
  }
}

UserProfile _profile({
  required String userId,
  required String username,
  required String displayName,
  bool membershipActive = false,
  String? vipLevel,
  String? planType,
  String? vipStatus,
}) {
  return UserProfile(
    userId: userId,
    username: username,
    account: username,
    displayName: displayName,
    phone: null,
    email: null,
    role: null,
    createdAt: DateTime.parse('2026-01-01T00:00:00.000Z'),
    membershipActive: membershipActive,
    vipLevel: vipLevel,
    planType: planType,
    vipStatus: vipStatus,
    vipExpireAt: null,
    features: const <String>[],
  );
}

class _UserProfileTestMinePageSessionService extends MinePageSessionService {
  _UserProfileTestMinePageSessionService(AuthSessionStore sessionStore)
    : super(
        authSessionStore: sessionStore,
        mobileFeatureService: _UnusedMobileFeatureService(),
        membershipService: _UnusedMembershipService(),
        userProfileService: _UnusedUserProfileService(),
        remoteAccessSnapshotService: _UnusedRemoteAccessSnapshotService(),
      );

  @override
  Future<String?> loadLocalAvatarPath(String? userId) async => null;
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
