import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shuxiang_reading_next/app/composition/app_providers.dart'
    as app_providers;
import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/membership/membership_access_resolver.dart';
import 'package:shuxiang_reading_next/core/membership/membership_access_service.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_provider.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_service.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/advanced_theme_list_page.dart';

void main() {
  testWidgets('advanced theme list stops loading when summaries fail', (
    tester,
  ) async {
    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const AdvancedThemeListPage(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          advancedThemeServiceProvider.overrideWithValue(
            _ThrowingAdvancedThemeService(),
          ),
          app_providers.appMembershipAccessServiceProvider.overrideWithValue(
            _ActiveMembershipAccessService(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('还没有高级主题'), findsOneWidget);
  });
}

class _ThrowingAdvancedThemeService extends AdvancedThemeService {
  @override
  Future<String?> loadActiveThemeId() async => null;

  @override
  Future<AppAdvancedTheme?> loadThemeById(String themeId) async => null;

  @override
  Future<List<AdvancedThemeSummary>> loadThemeSummaries() async {
    throw StateError('summary load failed');
  }

  @override
  Future<List<AdvancedThemeSummary>> hydrateThemeSummaryPreviewPaths(
    List<AdvancedThemeSummary> summaries,
  ) async {
    return summaries;
  }
}

class _ActiveMembershipAccessService implements MembershipAccessService {
  @override
  Future<AuthSession?> getCurrentSession() async {
    return const AuthSession(
      accessToken: 'token',
      membershipActive: true,
      vipLevel: 'svip',
      vipStatus: 'active',
      planType: 'lifetime',
    );
  }

  @override
  Future<MembershipAccessSnapshot> fetchCurrentAccess({
    AuthSession? session,
    bool allowProfileFallback = true,
  }) async {
    return const MembershipAccessSnapshot(
      hasMembership: true,
      hasExplicitMembershipState: true,
      features: <String>{MembershipAccessResolver.themeCustomFeature},
    );
  }

  @override
  Future<bool> fetchOnlineServiceAccess({
    AuthSession? session,
    bool allowProfileFallback = true,
  }) async {
    return true;
  }
}
