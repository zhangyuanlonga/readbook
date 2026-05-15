import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../domain/entities/chapter.dart';
import '../../book/application/book_detail_service.dart';
import '../../search/application/server_book_gateway_service.dart';
import '../../search/application/server_gateway_identity.dart';
import '../../search/application/search_system_settings_service.dart';
import 'chapter_content_service.dart';
import 'content_text_cleaner.dart';
import 'content_provider.dart';

class ServerGatewayContentProvider extends ContentProvider {
  ServerGatewayContentProvider({
    ServerBookGatewayService? gatewayService,
    SearchSystemSettingsService? settingsService,
    ContentTextCleaner? cleaner,
  }) : _gatewayService = gatewayService ?? ServerBookGatewayService(),
       _settingsService = settingsService ?? SearchSystemSettingsService(),
       _cleaner = cleaner ?? const ContentTextCleaner();

  final ServerBookGatewayService _gatewayService;
  final SearchSystemSettingsService _settingsService;
  final ContentTextCleaner _cleaner;

  @override
  ContentCapabilities get capabilities => const ContentCapabilities(
    canSwitchSource: false,
    canCacheChapter: false,
    canRefreshToc: true,
    canSearchInSource: false,
    canReindexLocal: false,
  );

  @override
  bool supportsSourceId(String sourceId) {
    return isServerGatewaySourceId(sourceId);
  }

  @override
  Future<BookDetailLoadResult> loadDetail({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    String? fallbackTitle,
    String? fallbackAuthor,
    bool forceRefresh = false,
    bool includeCatalog = true,
  }) async {
    await _ensureServerGatewayEnabled(ErrorStage.detail);
    final detail = await _gatewayService.loadDetail(
      sourceId: sourceId,
      bookId: bookId,
      detailUrl: detailUrl,
      fallbackTitle: fallbackTitle,
      fallbackAuthor: fallbackAuthor,
      refresh: forceRefresh,
    );
    if (!includeCatalog) {
      return BookDetailLoadResult(
        detail: detail.detail,
        chapters: const <Chapter>[],
        sourceName: detail.sourceName,
        tocFromCache: false,
        catalogAvailable: true,
        catalogLoaded: false,
      );
    }
    final toc = await _gatewayService.loadTocFirstBatch(
      sourceId: detail.detail.sourceId,
      bookId: detail.detail.id,
      detailUrl: detail.detail.detailUrl,
      tocUrl: detail.detail.tocUrl,
      refresh: forceRefresh,
    );
    return BookDetailLoadResult(
      detail: detail.detail,
      chapters: toc.chapters,
      sourceName: detail.sourceName,
      tocFromCache: toc.cacheHit,
      catalogAvailable: true,
      catalogLoaded: true,
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
    await _ensureServerGatewayEnabled(ErrorStage.content);
    final content = await _gatewayService.loadContent(
      sourceId: sourceId,
      bookId: bookId,
      detailUrl: detailUrl ?? '',
      chapterUrl: chapterUrl,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
    );
    final normalizedContent = _cleaner.clean(content.content.trim());
    if (normalizedContent.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '服务器正文解析为空，请换源或稍后重试。',
      );
    }
    return ChapterContentResult(
      content: normalizedContent,
      fromCache: content.cacheHit,
      displayChapterTitle: chapterTitle,
    );
  }

  Future<void> _ensureServerGatewayEnabled(ErrorStage stage) async {
    if (await _settingsService.loadServerOnlineSearchEnabled()) {
      return;
    }
    throw AppException(
      code: ErrorCode.validation,
      stage: stage,
      briefMessage: '服务器在线搜索已关闭，请在会员中心开启后再继续。',
    );
  }
}
