import '../auth/auth_session.dart';
import '../auth/auth_session_store.dart';
import '../user/user_profile.dart';
import '../user/user_profile_service.dart';
import 'membership_access_resolver.dart';
import 'membership_entitlement.dart';
import 'membership_service.dart';

class MembershipAccessService {
  factory MembershipAccessService({
    AuthSessionStore? sessionStore,
    MembershipService? membershipService,
    UserProfileService? userProfileService,
  }) {
    final resolvedSessionStore = sessionStore ?? AuthSessionStore();
    return MembershipAccessService._(
      sessionStore: resolvedSessionStore,
      membershipService: membershipService ?? MembershipService(),
      userProfileService:
          userProfileService ??
          UserProfileService(sessionStore: resolvedSessionStore),
    );
  }

  const MembershipAccessService._({
    required AuthSessionStore sessionStore,
    required MembershipService membershipService,
    required UserProfileService userProfileService,
  }) : _sessionStore = sessionStore,
       _membershipService = membershipService,
       _userProfileService = userProfileService;

  final AuthSessionStore _sessionStore;
  final MembershipService _membershipService;
  final UserProfileService _userProfileService;

  Future<AuthSession?> getCurrentSession() {
    return _sessionStore.getSession();
  }

  Future<MembershipAccessSnapshot> fetchCurrentAccess({
    AuthSession? session,
    bool allowProfileFallback = true,
  }) async {
    final currentSession = session ?? await _sessionStore.getSession();
    if (currentSession == null) {
      return MembershipAccessResolver.unknown;
    }

    MembershipEntitlement? entitlement;
    Object? entitlementError;
    StackTrace? entitlementStackTrace;
    try {
      entitlement = await _membershipService.fetchEntitlement();
      if (entitlement.hasExplicitMembershipState) {
        return MembershipAccessResolver.resolve(
          session: currentSession,
          entitlement: entitlement,
        );
      }
    } catch (error, stackTrace) {
      entitlementError = error;
      entitlementStackTrace = stackTrace;
    }

    UserProfile? profile;
    Object? profileError;
    StackTrace? profileStackTrace;
    if (allowProfileFallback) {
      try {
        profile = await _userProfileService.fetchMe();
      } catch (error, stackTrace) {
        profileError = error;
        profileStackTrace = stackTrace;
      }
    }

    final resolved = MembershipAccessResolver.resolve(
      session: currentSession,
      profile: profile,
      entitlement: entitlement,
    );
    if (resolved.hasExplicitMembershipState || resolved.hasMembership) {
      return resolved;
    }
    if (profileError != null && profileStackTrace != null) {
      Error.throwWithStackTrace(profileError, profileStackTrace);
    }
    if (entitlementError != null && entitlementStackTrace != null) {
      Error.throwWithStackTrace(entitlementError, entitlementStackTrace);
    }
    return resolved;
  }

  Future<bool> fetchOnlineServiceAccess({
    AuthSession? session,
    bool allowProfileFallback = true,
  }) async {
    final access = await fetchCurrentAccess(
      session: session,
      allowProfileFallback: allowProfileFallback,
    );
    return access.hasOnlineService;
  }
}
