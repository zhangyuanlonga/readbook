class ReaderRouteData {
  const ReaderRouteData({
    required this.bookId,
    required this.chapterId,
    this.chapterUrl,
    this.chapterTitle,
    this.sourceId,
    this.detailUrl,
    this.chapterIndex,
    this.bookmarkId,
    this.openRequestedAtMs,
    this.openRouteKind,
    this.heroTag,
  });

  static const String routeName = 'reader';
  static const String pathPattern = '/reader/:bookId/:chapterId';

  final String bookId;
  final String chapterId;
  final String? chapterUrl;
  final String? chapterTitle;
  final String? sourceId;
  final String? detailUrl;
  final int? chapterIndex;
  final String? bookmarkId;
  final int? openRequestedAtMs;
  final String? openRouteKind;
  final String? heroTag;

  String get location {
    final normalizedBookId = bookId.trim();
    final normalizedChapterId = chapterId.trim();
    final effectiveBookId =
        normalizedBookId.isNotEmpty ? normalizedBookId : 'unknown-book';
    final effectiveChapterId =
        normalizedChapterId.isNotEmpty
            ? normalizedChapterId
            : 'unknown-chapter';
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
    putIfNotBlank('openRouteKind', openRouteKind);
    putIfNotBlank('heroTag', heroTag);
    if (chapterIndex != null) {
      query['chapterIndex'] = chapterIndex.toString();
    }
    if (openRequestedAtMs != null && openRequestedAtMs! > 0) {
      query['openRequestedAtMs'] = openRequestedAtMs.toString();
    }

    return Uri(
      path:
          '/reader/${Uri.encodeComponent(effectiveBookId)}/${Uri.encodeComponent(effectiveChapterId)}',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  factory ReaderRouteData.fromUri(Uri uri) {
    final segments = uri.pathSegments;
    final bookId =
        segments.length > 1 && segments[1].trim().isNotEmpty
            ? segments[1]
            : 'unknown-book';
    final chapterId =
        segments.length > 2 && segments[2].trim().isNotEmpty
            ? segments[2]
            : 'unknown-chapter';
    return ReaderRouteData(
      bookId: bookId,
      chapterId: chapterId,
      chapterUrl: uri.queryParameters['chapterUrl'],
      chapterTitle: uri.queryParameters['chapterTitle'],
      sourceId: uri.queryParameters['sourceId'],
      detailUrl: uri.queryParameters['detailUrl'],
      chapterIndex: int.tryParse(uri.queryParameters['chapterIndex'] ?? ''),
      bookmarkId: uri.queryParameters['bookmarkId'],
      openRequestedAtMs: int.tryParse(
        uri.queryParameters['openRequestedAtMs'] ?? '',
      ),
      openRouteKind: uri.queryParameters['openRouteKind'],
      heroTag: uri.queryParameters['heroTag'],
    );
  }
}

String buildReaderRoute({
  required String bookId,
  required String chapterId,
  String? chapterUrl,
  String? chapterTitle,
  String? sourceId,
  String? detailUrl,
  int? chapterIndex,
  String? bookmarkId,
  int? openRequestedAtMs,
  String? openRouteKind,
  String? heroTag,
}) {
  return ReaderRouteData(
    bookId: bookId,
    chapterId: chapterId,
    chapterUrl: chapterUrl,
    chapterTitle: chapterTitle,
    sourceId: sourceId,
    detailUrl: detailUrl,
    chapterIndex: chapterIndex,
    bookmarkId: bookmarkId,
    openRequestedAtMs: openRequestedAtMs,
    openRouteKind: openRouteKind,
    heroTag: heroTag,
  ).location;
}
