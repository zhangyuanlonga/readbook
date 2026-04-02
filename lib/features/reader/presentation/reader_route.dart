String buildReaderRoute({
  required String bookId,
  required String chapterId,
  String? chapterUrl,
  String? chapterTitle,
  String? sourceId,
  String? detailUrl,
  int? chapterIndex,
  String? bookmarkId,
}) {
  final normalizedBookId = bookId.trim();
  final normalizedChapterId = chapterId.trim();
  final effectiveBookId =
      normalizedBookId.isNotEmpty ? normalizedBookId : 'unknown-book';
  final effectiveChapterId =
      normalizedChapterId.isNotEmpty ? normalizedChapterId : 'unknown-chapter';
  final query = <String, String>{};

  void putIfNotBlank(String key, String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return;
    }
    query[key] = normalized;
  }

  putIfNotBlank('chapterUrl', chapterUrl);
  putIfNotBlank('chapterTitle', chapterTitle);
  putIfNotBlank('sourceId', sourceId);
  putIfNotBlank('detailUrl', detailUrl);
  putIfNotBlank('bookmarkId', bookmarkId);
  if (chapterIndex != null) {
    query['chapterIndex'] = chapterIndex.toString();
  }

  return Uri(
    path:
        '/reader/${Uri.encodeComponent(effectiveBookId)}/${Uri.encodeComponent(effectiveChapterId)}',
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}
