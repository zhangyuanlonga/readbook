import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../domain/entities/book_detail.dart';
import '../../../domain/entities/chapter.dart';
import '../../book/application/book_detail_service.dart';
import '../../book/application/local_book_detail_service.dart';
import 'chapter_content_service.dart';
import 'content_provider.dart';
import 'local/local_chapter_content_service.dart';
import 'local/local_book_preview_service.dart';
import 'local/local_reader_identity.dart';

class LocalContentProvider extends ContentProvider {
  LocalContentProvider({
    LocalBookDetailService? detailService,
    LocalChapterContentService? chapterContentService,
    LocalBookPreviewService? previewService,
  }) : _detailService = detailService ?? LocalBookDetailService.legacy(),
       _chapterContentService =
           chapterContentService ?? LocalChapterContentService(),
       _previewService = previewService ?? LocalBookPreviewService();

  static const String sourceName = '本地导入';

  final LocalBookDetailService _detailService;
  final LocalChapterContentService _chapterContentService;
  final LocalBookPreviewService _previewService;

  @override
  ContentCapabilities get capabilities => const ContentCapabilities(
    canSwitchSource: false,
    canCacheChapter: false,
    canRefreshToc: false,
    canSearchInSource: false,
    canReindexLocal: true,
  );

  @override
  bool supportsSourceId(String sourceId) {
    return LocalReaderIdentity.isLocalSourceId(sourceId);
  }

  @override
  Future<BookDetailLoadResult> loadDetail({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    String? fallbackTitle,
    String? fallbackAuthor,
    bool forceRefresh = false,
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

    final result = await _detailService.load(
      bookId: resolvedBookId,
      mode: LocalBookDetailLoadMode.directoryOnly,
      forceReindex: forceRefresh,
      allowBackgroundIndex: !forceRefresh,
    );

    final detail = BookDetail(
      id: result.book.id,
      sourceId: LocalReaderIdentity.localSourceId,
      title: result.book.title,
      detailUrl: LocalReaderIdentity.buildBookDetailUrl(result.book.id),
      author: _resolveAuthor(result.book.author),
      intro: _resolveIntro(result.book.description),
      coverUrl: _resolveCoverUrl(result.book.coverPath),
    );

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
            ? await _previewService.loadTxtBootstrapPreview(
              bookId: resolvedBookId,
            )
            : await _chapterContentService.load(
              bookId: resolvedBookId,
              chapterId: resolvedChapterId,
              chapterIndex: chapterIndex,
            );

    return ChapterContentResult(
      content: chapter.content,
      fromCache: true,
      imageUrls: chapter.imageUrls,
      document: chapter.document,
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

  String? _resolveCoverUrl(String? coverPath) {
    final normalized = coverPath?.trim() ?? '';
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
