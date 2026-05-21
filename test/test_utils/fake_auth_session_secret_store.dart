import 'package:shuxiang_reading_next/core/auth/auth_session_secret_store.dart';

class FakeAuthSessionSecretStore implements AuthSessionSecretStore {
  AuthSessionSecrets _secrets;

  FakeAuthSessionSecretStore({AuthSessionSecrets? initialSecrets})
    : _secrets = initialSecrets ?? const AuthSessionSecrets();

  @override
  Future<void> clear() async {
    _secrets = const AuthSessionSecrets();
  }

  @override
  Future<AuthSessionSecrets> readSecrets() async => _secrets;

  @override
  Future<void> writeSecrets(AuthSessionSecrets secrets) async {
    _secrets = AuthSessionSecrets(
      accessToken: secrets.accessToken,
      refreshToken: secrets.refreshToken,
      accessExpiresAt: secrets.accessExpiresAt,
      refreshExpiresAt: secrets.refreshExpiresAt,
    );
  }
}
