import '../../../../domain/entities/bookmark.dart';
import '../../../../domain/entities/local_book.dart';
import '../../../../domain/entities/reading_progress.dart';
import '../../../../domain/entities/reading_record.dart';
import '../../../../domain/repositories/local_book_repository.dart';
import '../reader_entry_route_resolver.dart';
import 'local_reader_identity.dart';

enum LocalReaderEntryGuardAction { openReader, openDetail, unavailable }

class LocalReaderEntryGuardResult {
  const LocalReaderEntryGuardResult._({
    required this.action,
    this.route,
    this.message,
  });

  const LocalReaderEntryGuardResult.openReader(String route)
    : this._(action: LocalReaderEntryGuardAction.openReader, route: route);

  const LocalReaderEntryGuardResult.openDetail({
    required String route,
    String? message,
  }) : this._(
         action: LocalReaderEntryGuardAction.openDetail,
         route: route,
         message: message,
       );

  const LocalReaderEntryGuardResult.unavailable(String message)
    : this._(action: LocalReaderEntryGuardAction.unavailable, message: message);

  final LocalReaderEntryGuardAction action;
  final String? route;
  final String? message;
}

class LocalReaderEntryGuardService {
  const LocalReaderEntryGuardService({
    required LocalBookRepository localBookRepository,
    ReaderEntryRouteResolver readerEntryRouteResolver =
        const ReaderEntryRouteResolver(),
  }) : _localBookRepository = localBookRepository,
       _readerEntryRouteResolver = readerEntryRouteResolver;

  final LocalBookRepository _localBookRepository;
  final ReaderEntryRouteResolver _readerEntryRouteResolver;

  Future<LocalReaderEntryGuardResult> guardProgress(ReadingProgress progress) {
    return guardChapter(
      bookId: progress.bookId,
      chapterId: progress.chapterId,
      chapterUrl: progress.chapterUrl,
      chapterTitle: progress.chapterTitle,
      chapterIndex: progress.chapterIndex,
      bookmarkId: null,
    );
  }

  Future<LocalReaderEntryGuardResult> guardRecord(ReadingRecord record) {
    return guardChapter(
      bookId: record.bookId,
      chapterId: record.lastChapterId,
      chapterUrl: record.lastChapterUrl,
      chapterTitle: record.lastChapterTitle ?? record.bookTitle,
      chapterIndex: record.lastChapterIndex,
      bookmarkId: null,
    );
  }

  Future<LocalReaderEntryGuardResult> guardBookmark(Bookmark bookmark) {
    return guardChapter(
      bookId: bookmark.bookId,
      chapterId: bookmark.chapterId,
      chapterIndex: bookmark.chapterIndex,
      bookmarkId: bookmark.id,
    );
  }

  Future<LocalReaderEntryGuardResult> guardChapter({
    required String bookId,
    required String? chapterId,
    String? chapterUrl,
    String? chapterTitle,
    int? chapterIndex,
    String? bookmarkId,
  }) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return const LocalReaderEntryGuardResult.unavailable('本地图书定位缺失，暂无法打开。');
    }

    final book = await _localBookRepository.getBookById(normalizedBookId);
    if (book == null) {
      return const LocalReaderEntryGuardResult.unavailable(
        '本地图书已从书库移除，暂无法继续阅读。',
      );
    }

    if (!book.isReadableReady) {
      return LocalReaderEntryGuardResult.openDetail(
        route: _buildLocalBookDetailRoute(normalizedBookId),
        message: _notReadyMessage(book),
      );
    }

    final resolvedChapter = await _resolveChapter(
      bookId: normalizedBookId,
      chapterId: chapterId,
      chapterUrl: chapterUrl,
      chapterIndex: chapterIndex,
    );
    if (resolvedChapter == null) {
      return LocalReaderEntryGuardResult.openDetail(
        route: _buildLocalBookDetailRoute(normalizedBookId),
        message: '本地章节已缺失，请在详情页重建索引后再试。',
      );
    }

    final route = _readerEntryRouteResolver.buildChapterRoute(
      bookId: normalizedBookId,
      chapterId: resolvedChapter.id,
      chapterUrl: LocalReaderIdentity.buildChapterUrl(resolvedChapter.id),
      chapterTitle:
          resolvedChapter.title.trim().isNotEmpty
              ? resolvedChapter.title
              : chapterTitle,
      sourceId: LocalReaderIdentity.localSourceId,
      detailUrl: LocalReaderIdentity.buildBookDetailUrl(normalizedBookId),
      chapterIndex: resolvedChapter.chapterIndex,
      bookmarkId: bookmarkId,
    );
    return LocalReaderEntryGuardResult.openReader(route);
  }

  Future<_ResolvedLocalChapter?> _resolveChapter({
    required String bookId,
    required String? chapterId,
    required String? chapterUrl,
    required int? chapterIndex,
  }) async {
    final normalizedChapterId =
        LocalReaderIdentity.resolveChapterId(
          chapterId: chapterId,
          chapterUrl: chapterUrl,
        )?.trim() ??
        '';
    if (normalizedChapterId.isNotEmpty &&
        normalizedChapterId.toLowerCase() != 'bootstrap') {
      final chapter = await _localBookRepository.getChapterById(
        normalizedChapterId,
      );
      if (chapter != null && chapter.bookId == bookId) {
        return _ResolvedLocalChapter(
          id: chapter.id,
          title: chapter.title,
          chapterIndex: chapter.chapterIndex,
        );
      }
    }

    final safeIndex = chapterIndex;
    if (safeIndex != null && safeIndex >= 0) {
      final chapter = await _localBookRepository.getChapterMetaByIndex(
        bookId,
        safeIndex,
      );
      if (chapter != null) {
        return _ResolvedLocalChapter(
          id: chapter.id,
          title: chapter.title,
          chapterIndex: chapter.chapterIndex,
        );
      }
    }

    final firstChapter = await _localBookRepository.getChapterMetaByIndex(
      bookId,
      0,
    );
    if (firstChapter == null) {
      return null;
    }
    return _ResolvedLocalChapter(
      id: firstChapter.id,
      title: firstChapter.title,
      chapterIndex: firstChapter.chapterIndex,
    );
  }

  String _buildLocalBookDetailRoute(String bookId) {
    return Uri(
      path: '/book/$bookId',
      queryParameters: <String, String>{
        'sourceId': LocalReaderIdentity.localSourceId,
        'detailUrl': LocalReaderIdentity.buildBookDetailUrl(bookId),
      },
    ).toString();
  }

  String _notReadyMessage(LocalBook book) {
    return switch (book.indexStatus) {
      LocalBookIndexStatus.pending ||
      LocalBookIndexStatus.indexing => '本地图书仍在索引，完成后即可继续阅读。',
      LocalBookIndexStatus.stale => '本地图书索引已过期，请在详情页重建索引。',
      LocalBookIndexStatus.failed => '本地图书索引失败，请在详情页查看诊断并重建索引。',
      LocalBookIndexStatus.ready => '本地图书暂无可读章节，请在详情页重建索引。',
    };
  }
}

class _ResolvedLocalChapter {
  const _ResolvedLocalChapter({
    required this.id,
    required this.title,
    required this.chapterIndex,
  });

  final String id;
  final String title;
  final int chapterIndex;
}
