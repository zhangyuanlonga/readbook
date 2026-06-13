import '../../../core/cache/app_cache_coordinator.dart';
import '../../../core/cache/cache_result.dart';
import '../../../data/datasources/local/app_database.dart';
import 'reader_chapter_content_cache_store.dart';

class ReaderCachedChapterStore {
  ReaderCachedChapterStore({
    AppDatabase? database,
    AppCacheCoordinator? cacheCoordinator,
    ReaderChapterContentCacheKeyBuilder? keyBuilder,
  }) : _database = database ?? AppDatabase.instance,
       _keyBuilder = keyBuilder ?? const ReaderChapterContentCacheKeyBuilder() {
    final chapterStore = ReaderChapterContentCacheStore(
      database: _database,
      keyBuilder: _keyBuilder,
    );
    _cacheCoordinator = cacheCoordinator ?? AppCacheCoordinator();
    _cacheCoordinator.registerStore(chapterStore);
  }

  final AppDatabase _database;
  final ReaderChapterContentCacheKeyBuilder _keyBuilder;
  late final AppCacheCoordinator _cacheCoordinator;

  Future<String?> getCachedPayload({
    String? bookId,
    required String sourceId,
    required String chapterUrl,
    int? chapterIndex,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final normalizedChapterUrl = chapterUrl.trim();
    if (normalizedSourceId.isEmpty || normalizedChapterUrl.isEmpty) {
      return null;
    }
    final result = await _cacheCoordinator.read(
      _keyBuilder.build(
        bookId: bookId,
        sourceId: normalizedSourceId,
        chapterUrl: normalizedChapterUrl,
        chapterIndex: chapterIndex,
      ),
    );
    if (result.status != AppCacheReadStatus.hit) {
      return null;
    }
    final payload = result.entry?.payload?.toString().trim() ?? '';
    return payload.isEmpty ? null : payload;
  }

  Future<bool> hasCachedPayload({
    String? bookId,
    required String sourceId,
    required String chapterUrl,
    int? chapterIndex,
  }) async {
    final payload = await getCachedPayload(
      bookId: bookId,
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      chapterIndex: chapterIndex,
    );
    return payload != null;
  }
}
