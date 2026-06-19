import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_session_secret_store.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/auth/session_cleaner.dart';
import '../../core/user/user_profile_service.dart';
import '../../core/auth/user_session_manager.dart';
import '../mine/application/remote_access_snapshot_service.dart';
import 'application/auth_form_validation_service.dart';

final authFormValidationServiceProvider = Provider<AuthFormValidationService>((
  ref,
) {
  return const AuthFormValidationService();
});

final authSessionSecretStoreProvider = Provider<AuthSessionSecretStore>((ref) {
  return createDefaultAuthSessionSecretStore();
});

final authServiceProvider = Provider<AuthService>((ref) {
  final sessionStore = ref.watch(authSessionStoreProvider);
  return AuthService(
    sessionStore: sessionStore,
    sessionManager: UserSessionManager(
      sessionStore: sessionStore,
      sessionCleaner: SessionCleaner(
        sessionStore: sessionStore,
        cleanupParticipants: <RemoteAccessSnapshotService>[
          RemoteAccessSnapshotService(),
        ],
      ),
    ),
  );
});

final authSessionStoreProvider = Provider<AuthSessionStore>((ref) {
  return AuthSessionStore(
    secretStore: ref.watch(authSessionSecretStoreProvider),
  );
});

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService(sessionStore: ref.watch(authSessionStoreProvider));
});
