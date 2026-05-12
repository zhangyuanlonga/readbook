import 'dart:async';

enum AuthEventType { loggedIn, sessionExpired, loggedOut }

class AuthEvent {
  const AuthEvent({required this.type, required this.message});

  final AuthEventType type;
  final String message;
}

class AuthEventBus {
  AuthEventBus._();

  static final AuthEventBus instance = AuthEventBus._();

  final StreamController<AuthEvent> _controller =
      StreamController<AuthEvent>.broadcast();
  DateTime? _lastSessionExpiredAt;

  Stream<AuthEvent> get stream => _controller.stream;

  void emit(AuthEvent event) {
    _controller.add(event);
  }

  void emitLoggedIn([String message = '登录成功。']) {
    emit(AuthEvent(type: AuthEventType.loggedIn, message: message));
  }

  void emitSessionExpired([String message = '登录已过期，请重新登录。']) {
    final now = DateTime.now();
    final last = _lastSessionExpiredAt;
    if (last != null && now.difference(last).inSeconds < 30) {
      return;
    }
    _lastSessionExpiredAt = now;
    emit(AuthEvent(type: AuthEventType.sessionExpired, message: message));
  }

  void emitLoggedOut([String message = '已退出登录。']) {
    emit(AuthEvent(type: AuthEventType.loggedOut, message: message));
  }
}
