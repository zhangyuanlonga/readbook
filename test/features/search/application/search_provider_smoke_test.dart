import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/membership/membership_access_service.dart';
import 'package:shuxiang_reading_next/app/composition/app_providers.dart';
import 'package:shuxiang_reading_next/features/auth/providers.dart';
import 'package:shuxiang_reading_next/features/book/application/book_presentation_query_service.dart';
import 'package:shuxiang_reading_next/features/search/application/search_history_service.dart';
import 'package:shuxiang_reading_next/features/search/application/server_online_search_service.dart';
import 'package:shuxiang_reading_next/features/search/application/search_system_settings_service.dart';
import 'package:shuxiang_reading_next/features/search/providers.dart';

import '../../../test_utils/fake_auth_session_secret_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('search providers expose services and shared presentation query', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(serverOnlineSearchServiceProvider),
      isA<ServerOnlineSearchService>(),
    );
    expect(
      container.read(searchHistoryServiceProvider),
      isA<SearchHistoryService>(),
    );
    expect(
      container.read(searchSystemSettingsServiceProvider),
      isA<SearchSystemSettingsService>(),
    );
    expect(
      container.read(searchBookPresentationQueryServiceProvider),
      isA<BookPresentationQueryService>(),
    );
    expect(
      container.read(searchMembershipAccessServiceProvider),
      isA<MembershipAccessService>(),
    );
    expect(
      container.read(searchMembershipAccessServiceProvider),
      same(container.read(appMembershipAccessServiceProvider)),
    );
  });

  test(
    'online search membership service reuses auth session provider',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final sessionStore = AuthSessionStore(
        preferences: prefs,
        secretStore: FakeAuthSessionSecretStore(),
      );
      const session = AuthSession(
        accessToken: 'access_member',
        userId: 'member_1',
        username: 'member',
        membershipActive: true,
        vipLevel: 'pro',
        vipStatus: 'active',
      );
      await sessionStore.saveSession(session);

      final container = ProviderContainer(
        overrides: <Override>[
          authSessionStoreProvider.overrideWithValue(sessionStore),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(searchMembershipAccessServiceProvider);
      final currentSession = await service.getCurrentSession();

      expect(currentSession?.accessToken, 'access_member');
      expect(currentSession?.membershipActive, isTrue);
    },
  );
}
