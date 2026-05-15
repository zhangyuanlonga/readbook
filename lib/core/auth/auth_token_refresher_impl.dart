import '../network/auth_token_refresher.dart';
import '../network/api_client.dart';
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
    } on ApiException catch (error) {
      if (_shouldInvalidateSession(error)) {
        await _sessionStore.clear();
        AuthEventBus.instance.emitSessionExpired();
      }
      return false;
    } catch (_) {
      // Transient refresh failures should not immediately wipe local session.
      // Let the next authenticated request or foreground refresh retry again.
      return false;
    }
  }

  bool _shouldInvalidateSession(ApiException error) {
    final apiCode = error.apiCode.toUpperCase();
    return error.statusCode == 401 ||
        error.statusCode == 403 ||
        apiCode.contains('UNAUTHORIZED') ||
        apiCode.contains('TOKEN') ||
        apiCode.contains('SESSION') ||
        apiCode.contains('REFRESH');
  }
}
