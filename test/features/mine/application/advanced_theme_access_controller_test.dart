import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/membership/membership_access_resolver.dart';
import 'package:shuxiang_reading_next/core/membership/membership_access_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_access_controller.dart';

void main() {
  test(
    'explicit inactive membership asks page to clear active theme',
    () async {
      final controller = AdvancedThemeAccessController(
        membershipAccessService: _AccessService(
          snapshot: const MembershipAccessSnapshot(
            hasMembership: false,
            hasExplicitMembershipState: true,
          ),
        ),
      );

      final result = await controller.load(refreshRemote: true);

      expect(result.canUseAdvancedThemes, isFalse);
      expect(result.shouldClearActiveTheme, isTrue);
    },
  );

  test('access errors do not clear active theme implicitly', () async {
    final controller = AdvancedThemeAccessController(
      membershipAccessService: _ThrowingAccessService(),
    );

    final result = await controller.load(refreshRemote: true);

    expect(result.canUseAdvancedThemes, isFalse);
    expect(result.shouldClearActiveTheme, isFalse);
  });

  test('active membership keeps advanced theme access', () async {
    final controller = AdvancedThemeAccessController(
      membershipAccessService: _AccessService(
        snapshot: const MembershipAccessSnapshot(
          hasMembership: true,
          hasExplicitMembershipState: true,
          features: <String>{MembershipAccessResolver.themeCustomFeature},
        ),
      ),
    );

    final result = await controller.load(refreshRemote: true);

    expect(result.canUseAdvancedThemes, isTrue);
    expect(result.shouldClearActiveTheme, isFalse);
  });
}

class _AccessService implements MembershipAccessService {
  const _AccessService({required this.snapshot});

  final MembershipAccessSnapshot snapshot;

  @override
  Future<AuthSession?> getCurrentSession() async {
    return const AuthSession(accessToken: 'token');
  }

  @override
  Future<MembershipAccessSnapshot> fetchCurrentAccess({
    AuthSession? session,
    bool allowProfileFallback = true,
  }) async {
    return snapshot;
  }

  @override
  Future<bool> fetchOnlineServiceAccess({
    AuthSession? session,
    bool allowProfileFallback = true,
  }) async {
    return snapshot.hasOnlineService;
  }
}

class _ThrowingAccessService implements MembershipAccessService {
  @override
  Future<AuthSession?> getCurrentSession() async {
    return const AuthSession(accessToken: 'token');
  }

  @override
  Future<MembershipAccessSnapshot> fetchCurrentAccess({
    AuthSession? session,
    bool allowProfileFallback = true,
  }) async {
    throw StateError('network failed');
  }

  @override
  Future<bool> fetchOnlineServiceAccess({
    AuthSession? session,
    bool allowProfileFallback = true,
  }) async {
    throw StateError('network failed');
  }
}
