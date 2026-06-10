import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/features/reader/application/chapter_cache_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_session_listener.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('logout clears rebuildable chapter caches', () async {
    final cacheService = _FakeChapterCacheService();
    final listener = ReaderSessionListener(chapterCacheService: cacheService);

    await listener.onUserLogout('user-a');

    expect(cacheService.clearAllCalls, 1);
  });
}

class _FakeChapterCacheService extends ChapterCacheService {
  int clearAllCalls = 0;

  @override
  Future<void> clearAllCaches() async {
    clearAllCalls += 1;
  }
}
