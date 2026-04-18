String buildBookDetailRoute({
  required String bookId,
  String? sourceId,
  String? detailUrl,
  String? title,
  String? heroTag,
}) {
  final normalizedBookId = bookId.trim();
  final effectiveBookId =
      normalizedBookId.isNotEmpty ? normalizedBookId : 'unknown-book';
  final query = <String, String>{};

  void putIfNotBlank(String key, String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return;
    }
    query[key] = normalized;
  }

  putIfNotBlank('sourceId', sourceId);
  putIfNotBlank('detailUrl', detailUrl);
  putIfNotBlank('title', title);
  putIfNotBlank('heroTag', heroTag);

  return Uri(
    pathSegments: ['book', effectiveBookId],
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}
