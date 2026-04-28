import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/mobile_features/mobile_feature_module.dart';
import 'package:shuxiang_reading_next/core/mobile_features/mobile_feature_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_page_access_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loads feature access and computes remaining slots', () async {
    final prefs = await SharedPreferences.getInstance();
    final sessionStore = AuthSessionStore(preferences: prefs);
    await sessionStore.saveSession(
      const AuthSession(accessToken: 'token', userId: 'user_1'),
    );

    final service = SourcePageAccessService(
      authSessionStore: sessionStore,
      mobileFeatureService: _FakeMobileFeatureService(),
    );

    final access = await service.loadFeatureAccess();
    expect(access.canAccessSourcePage, isTrue);
    expect(access.sourceImportLimit, 12);
    expect(
      service.remainingSourceImportSlots(
        sourceImportLimit: access.sourceImportLimit,
        currentSourceCount: 5,
      ),
      7,
    );
    expect(
      service.canAddSource(
        isLoading: false,
        sourceImportLimit: access.sourceImportLimit,
        currentSourceCount: 11,
      ),
      isTrue,
    );
  });
}

class _FakeMobileFeatureService extends MobileFeatureService {
  _FakeMobileFeatureService() : super(baseUrl: 'https://example.com');

  @override
  Future<List<MobileFeatureModule>> fetchMyModules() async {
    return const [
      MobileFeatureModule(
        code: 'source_entry',
        name: 'source entry',
        description: null,
        category: 'general',
        visible: true,
        enabled: true,
        requiresAuth: false,
        requiresMembership: false,
        requiredFeature: null,
        quotaLimit: -1,
        reason: null,
      ),
      MobileFeatureModule(
        code: 'source_import',
        name: 'source import',
        description: null,
        category: 'general',
        visible: true,
        enabled: true,
        requiresAuth: false,
        requiresMembership: false,
        requiredFeature: null,
        quotaLimit: 12,
        reason: null,
      ),
    ];
  }
}
