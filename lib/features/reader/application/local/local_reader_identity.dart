import '../../../../domain/entities/book_identity.dart' as book_identity;

/// Canonical local-reading identity codec.
///
/// Keep all local source/url/id parsing and building in one place so reader,
/// detail, and provider layers share the same rules.
class LocalReaderIdentity {
  const LocalReaderIdentity._();

  static const String localSourceId =
      book_identity.BookIdentityScheme.localSourceId;

  static bool isLocalSourceId(String? sourceId) {
    return book_identity.isLocalBookSourceId(sourceId);
  }

  static bool isLocalSchemeUrl(String? value) {
    return book_identity.isLocalSchemeUrl(value);
  }

  static String buildBookDetailUrl(String bookId) {
    return book_identity.buildLocalBookDetailUrl(bookId);
  }

  static String buildChapterUrl(String chapterId) {
    return book_identity.buildLocalChapterUrl(chapterId);
  }

  static String? resolveBookId({
    required String? bookId,
    required String? detailUrl,
  }) {
    final byId = (bookId ?? '').trim();
    if (byId.isNotEmpty) {
      return byId;
    }
    final byUrl = parseBookIdFromDetailUrl(detailUrl);
    if (byUrl != null && byUrl.isNotEmpty) {
      return byUrl;
    }
    return null;
  }

  static String? resolveChapterId({
    required String? chapterId,
    required String? chapterUrl,
  }) {
    final byId = (chapterId ?? '').trim();
    if (byId.isNotEmpty) {
      return byId;
    }
    final byUrl = parseChapterIdFromChapterUrl(chapterUrl);
    if (byUrl != null && byUrl.isNotEmpty) {
      return byUrl;
    }
    return null;
  }

  static String? parseBookIdFromDetailUrl(String? detailUrl) {
    return book_identity.parseLocalBookIdFromDetailUrl(detailUrl);
  }

  static String? parseChapterIdFromChapterUrl(String? chapterUrl) {
    return book_identity.parseLocalChapterIdFromChapterUrl(chapterUrl);
  }
}
