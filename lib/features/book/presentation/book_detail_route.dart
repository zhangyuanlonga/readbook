String buildBookDetailRoute({
  required String bookId,
  String? sourceId,
  String? detailUrl,
  String? title,
  String? author,
  String? coverUrl,
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
  putIfNotBlank('author', author);
  putIfNotBlank('coverUrl', coverUrl);
  putIfNotBlank('heroTag', heroTag);
  final encodedBookId = Uri.encodeComponent(effectiveBookId);

  return Uri(
    path: '/book/$encodedBookId',
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}
