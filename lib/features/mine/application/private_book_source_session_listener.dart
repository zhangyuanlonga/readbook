import '../../../core/auth/session_change_listener.dart';

class PrivateBookSourceSessionListener implements SessionChangeListener {
  const PrivateBookSourceSessionListener();

  @override
  Future<void> onUserLogin(String userId) async {}

  @override
  Future<void> onUserLogout(String? userId) async {
    // Private book sources are served by authenticated realtime APIs. There is
    // no local source-list cache to clear here; this listener keeps the session
    // lifecycle contract explicit for the module.
  }
}
