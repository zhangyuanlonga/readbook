import '../network/auth_token_refresher.dart';
import 'auth_event_bus.dart';
import 'auth_service.dart';
import 'auth_session_store.dart';

class AuthTokenRefresherImpl implements AuthTokenRefresher {
  AuthTokenRefresherImpl({
    AuthService? authService,
    AuthSessionStore? sessionStore,
  }) : _authService = authService ?? AuthService(),
       _sessionStore = sessionStore ?? AuthSessionStore();

  final AuthService _authService;
  final AuthSessionStore _sessionStore;

  @override
  Future<String?> getAccessToken() {
    return _sessionStore.getAccessToken();
  }

  @override
  Future<bool> refreshToken() async {
    final refreshToken = await _sessionStore.getRefreshToken();
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      return false;
    }
    try {
      final session = await _authService.refreshAndStore(
        refreshToken: refreshToken,
      );
      return session.isValid;
    } catch (_) {
      await _sessionStore.clear();
      AuthEventBus.instance.emitSessionExpired();
      return false;
    }
  }
}
