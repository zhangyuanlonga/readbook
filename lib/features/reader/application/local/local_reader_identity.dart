import '../../../bookshelf/application/local_book_import_service.dart';

/// Canonical local-reading identity codec.
///
/// Keep all local source/url/id parsing and building in one place so reader,
/// detail, and provider layers share the same rules.
class LocalReaderIdentity {
  const LocalReaderIdentity._();

  static const String localSourceId = LocalBookImportService.localBookSourceId;
  static const String _detailHost = 'book';
  static const String _chapterHost = 'chapter';

  static bool isLocalSourceId(String? sourceId) {
    return (sourceId ?? '').trim() == localSourceId;
  }

  static bool isLocalSchemeUrl(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(normalized);
    return uri != null && uri.scheme == 'local';
  }

  static String buildBookDetailUrl(String bookId) {
    final normalized = bookId.trim();
    return 'local://$_detailHost/$normalized';
  }

  static String buildChapterUrl(String chapterId) {
    final normalized = chapterId.trim();
    return 'local://$_chapterHost/$normalized';
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
    return _parseIdByHost(value: detailUrl, expectedHost: _detailHost);
  }

  static String? parseChapterIdFromChapterUrl(String? chapterUrl) {
    return _parseIdByHost(value: chapterUrl, expectedHost: _chapterHost);
  }

  static String? _parseIdByHost({
    required String? value,
    required String expectedHost,
  }) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.scheme != 'local' || uri.host != expectedHost) {
      return null;
    }
    if (uri.pathSegments.isEmpty) {
      return null;
    }
    final id = uri.pathSegments.last.trim();
    if (id.isEmpty) {
      return null;
    }
    return id;
  }
}
