import '../../../core/auth/auth_event_bus.dart';
import '../../../core/membership/membership_access_service.dart';

class AdvancedThemeAccessLoadResult {
  const AdvancedThemeAccessLoadResult({
    required this.canUseAdvancedThemes,
    required this.isAccessLoading,
    required this.shouldRefreshRemote,
    this.shouldClearActiveTheme = false,
  });

  final bool canUseAdvancedThemes;
  final bool isAccessLoading;
  final bool shouldRefreshRemote;
  final bool shouldClearActiveTheme;
}

class AdvancedThemeAccessController {
  AdvancedThemeAccessController({
    required MembershipAccessService membershipAccessService,
  }) : _membershipAccessService = membershipAccessService;

  final MembershipAccessService _membershipAccessService;
  bool _hasRequestedRemoteAccessRefresh = false;

  Future<AdvancedThemeAccessLoadResult> load({
    required bool refreshRemote,
  }) async {
    try {
      final session = await _membershipAccessService.getCurrentSession();
      if (session == null) {
        _hasRequestedRemoteAccessRefresh = false;
        return const AdvancedThemeAccessLoadResult(
          canUseAdvancedThemes: false,
          isAccessLoading: false,
          shouldRefreshRemote: false,
          shouldClearActiveTheme: true,
        );
      }

      final snapshot = await _membershipAccessService.fetchCurrentAccess(
        session: session,
        allowProfileFallback: true,
      );
      final shouldRefreshRemote =
          !refreshRemote &&
          !_hasRequestedRemoteAccessRefresh &&
          !snapshot.hasExplicitMembershipState &&
          !snapshot.hasMembership;
      if (shouldRefreshRemote) {
        _hasRequestedRemoteAccessRefresh = true;
        return const AdvancedThemeAccessLoadResult(
          canUseAdvancedThemes: false,
          isAccessLoading: true,
          shouldRefreshRemote: true,
        );
      }
      if (refreshRemote) {
        _hasRequestedRemoteAccessRefresh = false;
      }
      return AdvancedThemeAccessLoadResult(
        canUseAdvancedThemes: snapshot.hasThemeCustom,
        isAccessLoading: false,
        shouldRefreshRemote: false,
        shouldClearActiveTheme:
            snapshot.hasExplicitMembershipState && !snapshot.hasThemeCustom,
      );
    } catch (_) {
      return const AdvancedThemeAccessLoadResult(
        canUseAdvancedThemes: false,
        isAccessLoading: false,
        shouldRefreshRemote: false,
      );
    }
  }

  bool shouldRefreshForAuthEvent(AuthEvent event) {
    switch (event.type) {
      case AuthEventType.loggedIn:
        _hasRequestedRemoteAccessRefresh = false;
        return true;
      case AuthEventType.loggedOut:
      case AuthEventType.sessionExpired:
        _hasRequestedRemoteAccessRefresh = false;
        return false;
    }
  }
}
