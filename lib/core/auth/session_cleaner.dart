import 'auth_event_bus.dart';
import 'auth_session.dart';
import 'auth_session_store.dart';
import '../../features/mine/application/remote_access_snapshot_service.dart';

class SessionCleaner {
  SessionCleaner({
    AuthSessionStore? sessionStore,
    RemoteAccessSnapshotService? remoteAccessSnapshotService,
  }) : _sessionStore = sessionStore ?? AuthSessionStore(),
       _remoteAccessSnapshotService = remoteAccessSnapshotService ?? RemoteAccessSnapshotService();

  final AuthSessionStore _sessionStore;
  final RemoteAccessSnapshotService _remoteAccessSnapshotService;

  Future<void> clear({
    AuthSession? previousSession,
    bool emitEvent = true,
  }) async {
    final resolvedPreviousSession =
        previousSession ?? await _sessionStore.getSession();

    // 清除会员状态缓存，避免旧账号的会员信息残留
    final userId = resolvedPreviousSession?.userId?.trim();
    if (userId != null && userId.isNotEmpty) {
      await _remoteAccessSnapshotService.clear(userId);
    }

    await _sessionStore.clear();
    if (emitEvent) {
      AuthEventBus.instance.emitLoggedOut('已退出登录。', resolvedPreviousSession);
    }
  }
}
