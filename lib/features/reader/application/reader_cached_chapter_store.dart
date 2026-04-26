import '../../../data/datasources/local/app_database.dart';

class ReaderCachedChapterStore {
  ReaderCachedChapterStore({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<String?> getCachedPayload({
    required String sourceId,
    required String chapterUrl,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final normalizedChapterUrl = chapterUrl.trim();
    if (normalizedSourceId.isEmpty || normalizedChapterUrl.isEmpty) {
      return null;
    }
    final cached = await _database.getChapterCache(
      '$normalizedSourceId|$normalizedChapterUrl',
    );
    final payload = cached?.content.trim() ?? '';
    return payload.isEmpty ? null : payload;
  }

  Future<bool> hasCachedPayload({
    required String sourceId,
    required String chapterUrl,
  }) async {
    final payload = await getCachedPayload(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
    );
    return payload != null;
  }
}
