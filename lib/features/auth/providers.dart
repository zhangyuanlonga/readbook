import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/user/user_profile_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authSessionStoreProvider = Provider<AuthSessionStore>((ref) {
  return AuthSessionStore();
});

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService();
});
