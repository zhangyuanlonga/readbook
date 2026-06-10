import '../../../core/auth/session_change_listener.dart';
import 'chapter_cache_service.dart';

class ReaderSessionListener implements SessionChangeListener {
  ReaderSessionListener({ChapterCacheService? chapterCacheService})
    : _chapterCacheService = chapterCacheService ?? ChapterCacheService();

  final ChapterCacheService _chapterCacheService;

  @override
  Future<void> onUserLogin(String userId) async {}

  @override
  Future<void> onUserLogout(String? userId) {
    return _chapterCacheService.clearAllCaches();
  }
}
