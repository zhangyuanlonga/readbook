import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/storage/managed_file_path_resolver.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/book_detail.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/local_chapter.dart';
import '../../../domain/entities/local_book.dart' as local_entities;
import '../../../domain/entities/reader_document.dart';
import '../../book/application/book_detail_service.dart';
import '../../book/application/local_book_detail_service.dart';
import 'chapter_content_service.dart';
import 'content_provider.dart';
import 'local/local_chapter_content_service.dart';
import 'local/local_book_storage_service.dart';
import 'local/local_book_preview_service.dart';
import 'local/local_reader_identity.dart';

class LocalContentProvider extends ContentProvider {
  LocalContentProvider({
    LocalBookDetailService? detailService,
    LocalChapterContentService? chapterContentService,
    LocalBookPreviewService? previewService,
  }) : _detailService = detailService,
       _chapterContentService = chapterContentService,
       _previewService = previewService;

  static const String sourceName = '本地导入';
  static final ManagedFilePathResolver _pathResolver =
      ManagedFilePathResolver();
  static final LocalBookStorageService _storageService =
      LocalBookStorageService();

  final LocalBookDetailService? _detailService;
  final LocalChapterContentService? _chapterContentService;
  final LocalBookPreviewService? _previewService;

  @override
  ContentCapabilities get capabilities => const ContentCapabilities(
    canSwitchSource: false,
    canCacheChapter: false,
    canRefreshToc: false,
    canSearchInSource: false,
    canReindexLocal: true,
  );

  Future<BookDetailLoadResult?> loadBookSnapshotDetail({
    required String sourceId,
    required String bookId,
    required String detailUrl,
  }) async {
    _ensureLocalSource(sourceId, stage: ErrorStage.detail);

    final resolvedBookId = LocalReaderIdentity.resolveBookId(
      bookId: bookId,
      detailUrl: detailUrl,
    );
    if (resolvedBookId == null || resolvedBookId.isEmpty) {
      return null;
    }

    final book = await _requireDetailService().loadBookSnapshot(
      bookId: resolvedBookId,
    );
    if (book == null) {
      return null;
    }

    return BookDetailLoadResult(
      detail: _buildDetailFromLocalBook(book),
      chapters: const <Chapter>[],
      sourceName: sourceName,
      tocFromCache: true,
      tocError: null,
      catalogAvailable:
          book.indexStatus == local_entities.LocalBookIndexStatus.ready &&
          book.chapterCount > 0,
      catalogLoaded: false,
      catalogComplete: false,
    );
  }

  @override
  bool supportsSourceId(String sourceId) {
    return LocalReaderIdentity.isLocalSourceId(sourceId);
  }

  @override
  Future<BookDetailLoadResult> loadDetail({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    Book? initialBook,
    String? fallbackTitle,
    String? fallbackAuthor,
    bool forceRefresh = false,
    bool includeCatalog = true,
  }) async {
    _ensureLocalSource(sourceId, stage: ErrorStage.detail);

    final resolvedBookId = LocalReaderIdentity.resolveBookId(
      bookId: bookId,
      detailUrl: detailUrl,
    );
    if (resolvedBookId == null || resolvedBookId.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.detail,
        briefMessage: '本地图书标识缺失，无法加载详情。',
      );
    }

    final result = await _requireDetailService().load(
      bookId: resolvedBookId,
      mode:
          includeCatalog
              ? LocalBookDetailLoadMode.directoryOnly
              : LocalBookDetailLoadMode.bookOnly,
      forceReindex: forceRefresh,
      allowBackgroundIndex: !forceRefresh,
    );

    final detail = _buildDetailFromLocalBook(result.book);

    final chapters = result.chapters
        .map(
          (chapter) => Chapter(
            id: chapter.id,
            bookId: chapter.bookId,
            title: chapter.title,
            chapterUrl: LocalReaderIdentity.buildChapterUrl(chapter.id),
            index: chapter.chapterIndex,
          ),
        )
        .toList(growable: false);

    return BookDetailLoadResult(
      detail: detail,
      chapters: chapters,
      sourceName: sourceName,
      tocFromCache: false,
      tocError: null,
      catalogAvailable:
          result.book.indexStatus ==
              local_entities.LocalBookIndexStatus.ready &&
          result.book.chapterCount > 0,
      catalogLoaded: includeCatalog,
      catalogComplete: includeCatalog,
    );
  }

  @override
  Future<ChapterContentResult> loadChapterContent({
    required String sourceId,
    required String bookId,
    required String chapterUrl,
    String? bookTitle,
    String? detailUrl,
    String? chapterId,
    int? chapterIndex,
    String? chapterTitle,
    String? nextChapterUrl,
    String? executionContext,
  }) async {
    _ensureLocalSource(sourceId, stage: ErrorStage.content);

    final resolvedBookId = LocalReaderIdentity.resolveBookId(
      bookId: bookId,
      detailUrl: null,
    );
    if (resolvedBookId == null || resolvedBookId.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '本地图书标识缺失，无法加载正文。',
      );
    }

    final resolvedChapterId = LocalReaderIdentity.resolveChapterId(
      chapterId: chapterId,
      chapterUrl: chapterUrl,
    );
    if ((resolvedChapterId == null || resolvedChapterId.isEmpty) &&
        chapterIndex == null) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '缺少本地章节信息，请重新进入或重新索引。',
      );
    }

    final chapter =
        (resolvedChapterId?.trim().toLowerCase() == 'bootstrap')
            ? await _requirePreviewService().loadTxtBootstrapPreview(
              bookId: resolvedBookId,
            )
            : await _requireChapterContentService().load(
              bookId: resolvedBookId,
              chapterId: resolvedChapterId,
              chapterIndex: chapterIndex,
            );
    final bookSnapshot = await _requireDetailService().loadBookSnapshot(
      bookId: resolvedBookId,
    );
    final resolvedStoragePath =
        bookSnapshot == null
            ? null
            : await _storageService.resolveStoragePath(
              bookSnapshot.storagePath,
            );

    return ChapterContentResult(
      content: chapter.content,
      fromCache: true,
      imageUrls: chapter.imageUrls,
      contentType: chapter.contentType ?? _resolveLocalContentType(chapter),
      sourceFilePath: resolvedStoragePath,
      totalPageCount: _resolveLocalTotalPageCount(chapter, bookSnapshot),
      document: chapter.document,
    );
  }

  LocalBookDetailService _requireDetailService() {
    final detailService = _detailService;
    if (detailService != null) {
      return detailService;
    }
    throw StateError(
      'LocalBookDetailService is required to load local detail.',
    );
  }

  LocalChapterContentService _requireChapterContentService() {
    final chapterContentService = _chapterContentService;
    if (chapterContentService != null) {
      return chapterContentService;
    }
    throw StateError(
      'LocalChapterContentService is required to load local chapter content.',
    );
  }

  LocalBookPreviewService _requirePreviewService() {
    final previewService = _previewService;
    if (previewService != null) {
      return previewService;
    }
    throw StateError(
      'LocalBookPreviewService is required to load local bootstrap preview.',
    );
  }

  void _ensureLocalSource(String sourceId, {required ErrorStage stage}) {
    if (supportsSourceId(sourceId)) {
      return;
    }
    throw AppException(
      code: ErrorCode.unknownSource,
      stage: stage,
      briefMessage: '非本地书籍来源，无法使用本地内容提供器。',
    );
  }

  BookDetail _buildDetailFromLocalBook(local_entities.LocalBook book) {
    return BookDetail(
      id: book.id,
      sourceId: LocalReaderIdentity.localSourceId,
      title: book.title,
      detailUrl: LocalReaderIdentity.buildBookDetailUrl(book.id),
      author: _resolveAuthor(book.author),
      intro: _resolveIntro(book.description),
      coverUrl: _resolveCoverUrl(book.coverPath),
    );
  }

  String? _resolveLocalContentType(LocalChapter chapter) {
    final sourceRef = chapter.sourceRef?.trim().toLowerCase() ?? '';
    if (sourceRef.startsWith('pdf:page:')) {
      return 'pdf';
    }
    final document = chapter.document;
    final inlineImageOnly =
        chapter.imageUrls.length == 1 &&
        (document?.isPureImageDocument == true ||
            ReaderDocument.tryParseInlineImageParagraph(chapter.content) !=
                null);
    if (inlineImageOnly) {
      return 'picture-book';
    }
    return null;
  }

  int? _resolveLocalTotalPageCount(
    LocalChapter chapter,
    local_entities.LocalBook? book,
  ) {
    final sourceRef = chapter.sourceRef?.trim().toLowerCase() ?? '';
    if (sourceRef.startsWith('pdf:page:')) {
      return book?.chapterCount;
    }
    if (chapter.imageUrls.isNotEmpty) {
      return chapter.imageUrls.length;
    }
    return null;
  }

  String? _resolveCoverUrl(String? coverPath) {
    final normalized =
        _pathResolver.tryResolveExistingFilePathSync(coverPath) ??
        coverPath?.trim() ??
        '';
    if (normalized.isEmpty) {
      return null;
    }
    return Uri.file(normalized).toString();
  }

  String _resolveAuthor(String? author) {
    final normalized = author?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return sourceName;
  }

  String? _resolveIntro(String? intro) {
    final normalized = intro?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
