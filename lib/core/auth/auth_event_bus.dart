import 'dart:async';

import 'auth_session.dart';

enum AuthEventType { loggedIn, sessionExpired, loggedOut }

class AuthEvent {
  const AuthEvent({
    required this.type,
    required this.message,
    this.session,
    this.previousSession,
  });

  final AuthEventType type;
  final String message;
  final AuthSession? session;
  final AuthSession? previousSession;

  String? get userId => _normalizedUserId(session);

  String? get previousUserId => _normalizedUserId(previousSession);

  bool get isAccountSwitch {
    if (type != AuthEventType.loggedIn) {
      return false;
    }
    final currentKey = _accountKey(session);
    final previousKey = _accountKey(previousSession);
    return currentKey != null &&
        previousKey != null &&
        currentKey != previousKey;
  }

  static String? _normalizedUserId(AuthSession? session) {
    final normalized = session?.userId?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static String? _accountKey(AuthSession? session) {
    final userId = _normalizedUserId(session);
    if (userId != null) {
      return 'id:$userId';
    }
    final identity = session?.loginIdentity?.trim() ?? '';
    if (identity.isNotEmpty) {
      return 'identity:${identity.toLowerCase()}';
    }
    return null;
  }
}

class AuthEventBus {
  AuthEventBus._();

  static final AuthEventBus instance = AuthEventBus._();

  final StreamController<AuthEvent> _controller =
      StreamController<AuthEvent>.broadcast();
  DateTime? _lastSessionExpiredAt;
  String? _lastSessionExpiredAccountKey;

  Stream<AuthEvent> get stream => _controller.stream;

  void emit(AuthEvent event) {
    _controller.add(event);
  }

  void emitLoggedIn([
    String message = '登录成功。',
    AuthSession? session,
    AuthSession? previousSession,
  ]) {
    emit(
      AuthEvent(
        type: AuthEventType.loggedIn,
        message: message,
        session: session,
        previousSession: previousSession,
      ),
    );
  }

  void emitSessionExpired([
    String message = '登录已过期，请重新登录。',
    AuthSession? previousSession,
  ]) {
    final now = DateTime.now();
    final last = _lastSessionExpiredAt;
    final accountKey = AuthEvent._accountKey(previousSession);
    if (last != null &&
        now.difference(last).inSeconds < 30 &&
        accountKey == _lastSessionExpiredAccountKey) {
      return;
    }
    _lastSessionExpiredAt = now;
    _lastSessionExpiredAccountKey = accountKey;
    emit(
      AuthEvent(
        type: AuthEventType.sessionExpired,
        message: message,
        previousSession: previousSession,
      ),
    );
  }

  void emitLoggedOut([
    String message = '已退出登录。',
    AuthSession? previousSession,
  ]) {
    emit(
      AuthEvent(
        type: AuthEventType.loggedOut,
        message: message,
        previousSession: previousSession,
      ),
    );
  }
}
