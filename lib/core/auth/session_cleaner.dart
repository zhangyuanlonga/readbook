import 'auth_event_bus.dart';
import 'auth_session.dart';
import 'auth_session_store.dart';
import 'session_cleanup_participant.dart';

class SessionCleaner {
  SessionCleaner({
    AuthSessionStore? sessionStore,
    Iterable<SessionCleanupParticipant> cleanupParticipants =
        const <SessionCleanupParticipant>[],
  }) : _sessionStore = sessionStore ?? AuthSessionStore(),
       _cleanupParticipants = List<SessionCleanupParticipant>.unmodifiable(
         cleanupParticipants,
       );

  final AuthSessionStore _sessionStore;
  final List<SessionCleanupParticipant> _cleanupParticipants;

  Future<void> clear({
    AuthSession? previousSession,
    bool emitEvent = true,
  }) async {
    final resolvedPreviousSession =
        previousSession ?? await _sessionStore.getSession();

    // 清除会员状态缓存，避免旧账号的会员信息残留
    final userId = resolvedPreviousSession?.userId?.trim();
    if (userId != null && userId.isNotEmpty) {
      for (final participant in _cleanupParticipants) {
        await participant.clearForUser(userId);
      }
    }

    await _sessionStore.clear();
    if (emitEvent) {
      AuthEventBus.instance.emitLoggedOut('已退出登录。', resolvedPreviousSession);
    }
  }
}
