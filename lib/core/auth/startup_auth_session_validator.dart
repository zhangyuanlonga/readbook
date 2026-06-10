import '../logging/app_logger.dart';
import '../network/api_client.dart';
import 'auth_event_bus.dart';
import 'auth_service.dart';
import 'auth_session.dart';
import 'auth_session_store.dart';

class StartupAuthSessionValidator {
  StartupAuthSessionValidator({
    AuthSessionStore? sessionStore,
    AuthService? authService,
    AppLogger? logger,
    DateTime Function()? now,
  }) : _sessionStore = sessionStore ?? AuthSessionStore(),
       _authService = authService ?? AuthService(sessionStore: sessionStore),
       _logger = logger ?? AppLogger.instance,
       _now = now ?? (() => DateTime.now().toUtc());

  final AuthSessionStore _sessionStore;
  final AuthService _authService;
  final AppLogger _logger;
  final DateTime Function() _now;

  Future<bool> validate() async {
    final session = await _sessionStore.getSession();
    if (session == null || !session.isValid) {
      return false;
    }

    if (session.isRefreshExpired()) {
      await _expireSession(
        session,
        reason: 'refresh_expired',
        message: '登录已过期，请重新登录。',
      );
      return false;
    }

    if (!session.isAccessExpired()) {
      return true;
    }

    final refreshToken = session.refreshToken?.trim() ?? '';
    if (refreshToken.isEmpty) {
      await _expireSession(
        session,
        reason: 'access_expired_without_refresh_token',
        message: '登录已过期，请重新登录。',
      );
      return false;
    }

    try {
      final refreshed = await _authService.refreshAndStore(
        refreshToken: refreshToken,
      );
      final success = refreshed.isValid && !refreshed.isAccessExpired();
      if (!success) {
        await _expireSession(
          session,
          reason: 'refresh_result_invalid',
          message: '登录已过期，请重新登录。',
        );
      }
      return success;
    } on ApiException catch (error, stackTrace) {
      if (_shouldInvalidateSession(error)) {
        await _expireSession(
          session,
          reason: 'refresh_rejected',
          message: '登录已过期，请重新登录。',
        );
        return false;
      }
      _logger.warn(
        'Startup auth session refresh failed',
        context: <String, Object?>{
          'reason': 'refresh_transient_api_exception',
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      return false;
    } catch (error, stackTrace) {
      _logger.warn(
        'Startup auth session refresh failed',
        context: <String, Object?>{
          'reason': 'refresh_exception',
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      return false;
    }
  }

  Future<void> _expireSession(
    AuthSession previousSession, {
    required String reason,
    required String message,
  }) async {
    await _sessionStore.clear();
    _logger.info(
      'Startup auth session invalidated',
      context: <String, Object?>{
        'reason': reason,
        'now': _now().toIso8601String(),
        'accessExpiresAt': previousSession.accessExpiresAt?.toIso8601String(),
        'refreshExpiresAt': previousSession.refreshExpiresAt?.toIso8601String(),
      },
    );
    AuthEventBus.instance.emitSessionExpired(message, previousSession);
  }

  bool _shouldInvalidateSession(ApiException error) {
    final apiCode = error.apiCode.toUpperCase();
    return error.statusCode == 401 ||
        apiCode.contains('UNAUTHORIZED') ||
        apiCode.contains('TOKEN') ||
        apiCode.contains('SESSION') ||
        apiCode.contains('REFRESH');
  }
}
