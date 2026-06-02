import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_session_secret_store.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/user/user_profile_service.dart';

final authSessionSecretStoreProvider = Provider<AuthSessionSecretStore>((ref) {
  return createDefaultAuthSessionSecretStore();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(sessionStore: ref.watch(authSessionStoreProvider));
});

final authSessionStoreProvider = Provider<AuthSessionStore>((ref) {
  return AuthSessionStore(
    secretStore: ref.watch(authSessionSecretStoreProvider),
  );
});

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService(sessionStore: ref.watch(authSessionStoreProvider));
});
