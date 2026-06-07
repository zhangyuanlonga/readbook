import '../../../core/auth/auth_event_bus.dart';
import '../../../core/auth/auth_session_store.dart';
import 'mine_page_session_service.dart';

class AdvancedThemeAccessLoadResult {
  const AdvancedThemeAccessLoadResult({
    required this.canUseAdvancedThemes,
    required this.isAccessLoading,
    required this.shouldRefreshRemote,
  });

  final bool canUseAdvancedThemes;
  final bool isAccessLoading;
  final bool shouldRefreshRemote;
}

class AdvancedThemeAccessController {
  AdvancedThemeAccessController({
    required AuthSessionStore sessionStore,
    required MinePageSessionService sessionService,
  }) : _sessionStore = sessionStore,
       _sessionService = sessionService;

  final AuthSessionStore _sessionStore;
  final MinePageSessionService _sessionService;
  bool _hasRequestedRemoteAccessRefresh = false;

  Future<AdvancedThemeAccessLoadResult> load({
    required bool refreshRemote,
  }) async {
    final session = await _sessionStore.getSession();
    if (session == null) {
      _hasRequestedRemoteAccessRefresh = false;
      return const AdvancedThemeAccessLoadResult(
        canUseAdvancedThemes: false,
        isAccessLoading: false,
        shouldRefreshRemote: false,
      );
    }

    final snapshot = await _sessionService.loadSession(
      refreshRemote: refreshRemote,
    );
    final shouldRefreshRemote =
        !refreshRemote &&
        !_hasRequestedRemoteAccessRefresh &&
        (!snapshot.hasThemeCustom || snapshot.shouldRefreshRemoteAccess);
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
    );
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
