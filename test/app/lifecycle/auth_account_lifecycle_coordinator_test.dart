import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/lifecycle/auth_account_lifecycle_coordinator.dart';
import 'package:shuxiang_reading_next/core/auth/auth_event_bus.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';

void main() {
  test(
    'logged out clears previous account cache and notifies listeners',
    () async {
      final clearedUserIds = <String?>[];
      var refreshCount = 0;
      var revisionCount = 0;
      final coordinator = AuthAccountLifecycleCoordinator(
        clearAccountScopedCache: (userId) async {
          clearedUserIds.add(userId);
        },
        refreshCurrentAccountData: () async {
          refreshCount += 1;
        },
        notifyAccountDataChanged: () {
          revisionCount += 1;
        },
      );

      await coordinator.handle(
        const AuthEvent(
          type: AuthEventType.loggedOut,
          message: '已退出登录。',
          previousSession: AuthSession(accessToken: 'token', userId: 'user_a'),
        ),
      );

      expect(clearedUserIds, <String?>['user_a']);
      expect(refreshCount, 0);
      expect(revisionCount, 1);
    },
  );

  test(
    'account switch clears old cache and refreshes current account',
    () async {
      final clearedUserIds = <String?>[];
      var refreshCount = 0;
      var revisionCount = 0;
      final coordinator = AuthAccountLifecycleCoordinator(
        clearAccountScopedCache: (userId) async {
          clearedUserIds.add(userId);
        },
        refreshCurrentAccountData: () async {
          refreshCount += 1;
        },
        notifyAccountDataChanged: () {
          revisionCount += 1;
        },
      );

      await coordinator.handle(
        const AuthEvent(
          type: AuthEventType.loggedIn,
          message: '登录成功。',
          session: AuthSession(accessToken: 'new', userId: 'user_b'),
          previousSession: AuthSession(accessToken: 'old', userId: 'user_a'),
        ),
      );

      expect(clearedUserIds, <String?>['user_a']);
      expect(refreshCount, 1);
      expect(revisionCount, 1);
    },
  );

  test('same account login refreshes without clearing cache', () async {
    final clearedUserIds = <String?>[];
    var refreshCount = 0;
    var revisionCount = 0;
    final coordinator = AuthAccountLifecycleCoordinator(
      clearAccountScopedCache: (userId) async {
        clearedUserIds.add(userId);
      },
      refreshCurrentAccountData: () async {
        refreshCount += 1;
      },
      notifyAccountDataChanged: () {
        revisionCount += 1;
      },
    );

    await coordinator.handle(
      const AuthEvent(
        type: AuthEventType.loggedIn,
        message: '登录成功。',
        session: AuthSession(accessToken: 'new', userId: 'user_a'),
        previousSession: AuthSession(accessToken: 'old', userId: 'user_a'),
      ),
    );

    expect(clearedUserIds, isEmpty);
    expect(refreshCount, 1);
    expect(revisionCount, 1);
  });
}
