class BookDetailRouteData {
  const BookDetailRouteData({
    required this.bookId,
    this.sourceId,
    this.detailUrl,
    this.title,
    this.author,
    this.coverUrl,
    this.heroTag,
    this.titleHeroTag,
    this.metaHeroTag,
    this.revealTransition = false,
    this.initialEditMode = false,
  });

  static const String routeName = 'book';
  static const String pathPattern = '/book/:bookId';

  final String bookId;
  final String? sourceId;
  final String? detailUrl;
  final String? title;
  final String? author;
  final String? coverUrl;
  final String? heroTag;
  final String? titleHeroTag;
  final String? metaHeroTag;
  final bool revealTransition;
  final bool initialEditMode;

  String get location {
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
    putIfNotBlank('titleHeroTag', titleHeroTag);
    putIfNotBlank('metaHeroTag', metaHeroTag);
    if (revealTransition) {
      query['transition'] = 'reveal';
    }
    if (initialEditMode) {
      query['mode'] = 'edit';
    }
    final encodedBookId = Uri.encodeComponent(effectiveBookId);

    return Uri(
      path: '/book/$encodedBookId',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  factory BookDetailRouteData.fromUri(Uri uri) {
    final segments = uri.pathSegments;
    final bookId =
        segments.length > 1 && segments[1].trim().isNotEmpty
            ? segments[1]
            : 'unknown-book';
    return BookDetailRouteData(
      bookId: bookId,
      sourceId: uri.queryParameters['sourceId'],
      detailUrl: uri.queryParameters['detailUrl'],
      title: uri.queryParameters['title'],
      author: uri.queryParameters['author'],
      coverUrl: uri.queryParameters['coverUrl'],
      heroTag: uri.queryParameters['heroTag'],
      titleHeroTag: uri.queryParameters['titleHeroTag'],
      metaHeroTag: uri.queryParameters['metaHeroTag'],
      revealTransition: uri.queryParameters['transition'] == 'reveal',
      initialEditMode: uri.queryParameters['mode'] == 'edit',
    );
  }
}

String buildBookDetailRoute({
  required String bookId,
  String? sourceId,
  String? detailUrl,
  String? title,
  String? author,
  String? coverUrl,
  String? heroTag,
  String? titleHeroTag,
  String? metaHeroTag,
  bool revealTransition = false,
  bool initialEditMode = false,
}) {
  return BookDetailRouteData(
    bookId: bookId,
    sourceId: sourceId,
    detailUrl: detailUrl,
    title: title,
    author: author,
    coverUrl: coverUrl,
    heroTag: heroTag,
    titleHeroTag: titleHeroTag,
    metaHeroTag: metaHeroTag,
    revealTransition: revealTransition,
    initialEditMode: initialEditMode,
  ).location;
}
