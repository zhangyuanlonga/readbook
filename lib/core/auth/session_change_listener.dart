abstract class SessionChangeListener {
  Future<void> onUserLogin(String userId);

  Future<void> onUserLogout(String? userId);
}
