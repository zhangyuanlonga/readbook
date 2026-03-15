abstract class AuthTokenRefresher {
  Future<String?> getAccessToken();

  /// Refresh access token. Return true when refresh succeeds.
  Future<bool> refreshToken();
}
