import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_session_manager.dart';
import 'user_session_state.dart';

final userSessionManagerProvider = Provider<UserSessionManager>((ref) {
  return UserSessionManager.instance;
});

final userSessionProvider = FutureProvider<UserSessionState>((ref) {
  return ref.watch(userSessionManagerProvider).load();
});
