import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
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

import '../../test_utils/adaptive_test_harness.dart';

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
