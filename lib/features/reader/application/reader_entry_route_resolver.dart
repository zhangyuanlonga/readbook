import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reading_progress.dart';
import '../presentation/reader_route.dart';
import 'local/local_reader_identity.dart';

class ReaderEntryRouteResolver {
  const ReaderEntryRouteResolver();

  String buildChapterRoute({
    required String bookId,
    required String chapterId,
    required String? sourceId,
    required String? detailUrl,
    String? chapterUrl,
    String? chapterTitle,
    int? chapterIndex,
    String? bookmarkId,
    int? openRequestedAtMs,
    String? openRouteKind,
    String? heroTag,
  }) {
    final normalizedSourceId = (sourceId ?? '').trim();
    return buildReaderRoute(
      bookId: bookId,
      chapterId: chapterId,
      chapterUrl: _normalizeChapterUrl(
        sourceId: normalizedSourceId,
        chapterId: chapterId,
        chapterUrl: chapterUrl,
      ),
      chapterTitle: chapterTitle,
      sourceId: normalizedSourceId,
      detailUrl: _normalizeDetailUrl(
        sourceId: normalizedSourceId,
        bookId: bookId,
        detailUrl: detailUrl,
      ),
      chapterIndex: chapterIndex,
      bookmarkId: bookmarkId,
      openRequestedAtMs: openRequestedAtMs,
      openRouteKind: openRouteKind,
      heroTag: heroTag,
    );
  }

  String buildRouteFromProgress(
    ReadingProgress progress, {
    int? openRequestedAtMs,
    String? openRouteKind,
    String? heroTag,
  }) {
    return buildChapterRoute(
      bookId: progress.bookId,
      chapterId: progress.chapterId,
      chapterUrl: progress.chapterUrl,
      chapterTitle: progress.chapterTitle,
      sourceId: progress.sourceId,
      detailUrl: progress.detailUrl,
      chapterIndex: progress.chapterIndex,
      openRequestedAtMs: openRequestedAtMs,
      openRouteKind: openRouteKind,
      heroTag: heroTag,
    );
  }

  String buildRouteFromBookshelfFallback(
    BookshelfBook book, {
    int? openRequestedAtMs,
    String? openRouteKind,
    String? heroTag,
  }) {
    return buildChapterRoute(
      bookId: book.bookId,
      chapterId: 'bootstrap',
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
      chapterTitle: book.title,
      openRequestedAtMs: openRequestedAtMs,
      openRouteKind: openRouteKind,
      heroTag: heroTag,
    );
  }

  String buildRouteFromChapter({
    required String bookId,
    required String sourceId,
    required String detailUrl,
    required Chapter chapter,
    int? openRequestedAtMs,
    String? openRouteKind,
    String? heroTag,
  }) {
    return buildChapterRoute(
      bookId: bookId,
      chapterId: chapter.id,
      chapterUrl: chapter.chapterUrl,
      chapterTitle: chapter.title,
      sourceId: sourceId,
      detailUrl: detailUrl,
      chapterIndex: chapter.index,
      openRequestedAtMs: openRequestedAtMs,
      openRouteKind: openRouteKind,
      heroTag: heroTag,
    );
  }

  String buildRouteFromBookmark({
    required Bookmark bookmark,
    required String sourceId,
    required String detailUrl,
    String? heroTag,
  }) {
    final chapterId =
        bookmark.chapterId.trim().isEmpty ? 'bootstrap' : bookmark.chapterId.trim();
    return buildChapterRoute(
      bookId: bookmark.bookId,
      chapterId: chapterId,
      sourceId: sourceId,
      detailUrl: detailUrl,
      chapterIndex: bookmark.chapterIndex,
      bookmarkId: bookmark.id,
      heroTag: heroTag,
    );
  }

  String? _normalizeDetailUrl({
    required String sourceId,
    required String bookId,
    required String? detailUrl,
  }) {
    final normalized = (detailUrl ?? '').trim();
    if (!LocalReaderIdentity.isLocalSourceId(sourceId)) {
      return normalized.isEmpty ? null : normalized;
    }
    if (LocalReaderIdentity.isLocalSchemeUrl(normalized)) {
      return normalized;
    }
    return LocalReaderIdentity.buildBookDetailUrl(bookId);
  }

  String? _normalizeChapterUrl({
    required String sourceId,
    required String chapterId,
    required String? chapterUrl,
  }) {
    final normalized = (chapterUrl ?? '').trim();
    if (!LocalReaderIdentity.isLocalSourceId(sourceId)) {
      return normalized.isEmpty ? null : normalized;
    }
    if (LocalReaderIdentity.isLocalSchemeUrl(normalized)) {
      return normalized;
    }
    final normalizedChapterId = chapterId.trim();
    if (normalizedChapterId.isEmpty) {
      return normalized.isEmpty ? null : normalized;
    }
    return LocalReaderIdentity.buildChapterUrl(normalizedChapterId);
  }
}
