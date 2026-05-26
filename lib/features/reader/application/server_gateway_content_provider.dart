import 'dart:convert';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reader_document.dart';
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
        catalogComplete: false,
      );
    }
    final toc = await _gatewayService.loadTocComplete(
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
      catalogComplete: toc.isComplete,
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
    final rawContent = content.content.trim();
    final normalizedImages = _normalizeServerImageUrls(content.imageUrls);
    final normalizedContent =
        normalizedImages.isEmpty
            ? _cleaner.clean(rawContent)
            : _contentWithoutServerImages(rawContent, normalizedImages);
    final normalizedKind = content.kind.trim().toLowerCase();
    final hasAudioContent =
        (content.audioUrl?.trim().isNotEmpty ?? false) ||
        (content.audioManifestUrl?.trim().isNotEmpty ?? false) ||
        content.contentType.trim().toLowerCase() == 'audio' ||
        normalizedKind == 'audio';
    if (normalizedContent.isEmpty &&
        normalizedImages.isEmpty &&
        !hasAudioContent) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '服务器正文解析为空，请换源或稍后重试。',
      );
    }
    return ChapterContentResult(
      content: normalizedContent,
      fromCache: content.cacheHit,
      imageUrls: normalizedImages,
      imageHeaders: content.imageHeaders,
      contentType:
          normalizedKind.isNotEmpty ? normalizedKind : content.contentType,
      audioUrl: content.audioUrl,
      audioManifestUrl: content.audioManifestUrl,
      audioHeaders: content.audioHeaders,
      displayChapterTitle: chapterTitle,
      executionContext: content.executionContext,
    );
  }

  List<String> _normalizeServerImageUrls(Iterable<String> values) {
    final seen = <String>{};
    final images = <String>[];
    for (final value in values) {
      final normalized = value.trim();
      if (normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }
      images.add(normalized);
    }
    return List<String>.unmodifiable(images);
  }

  List<String> _extractImageUrlsFromServerContent(String content) {
    final fromStructuredPayload = _extractImagesFromStructuredPayload(content);
    if (fromStructuredPayload.isNotEmpty) {
      return fromStructuredPayload;
    }

    final fromHtml = _extractImageUrlsFromHtml(content);
    if (fromHtml.isNotEmpty) {
      return fromHtml;
    }

    final markerImages = _extractInlineImageMarkers(content);
    if (markerImages.isNotEmpty) {
      return markerImages;
    }

    return _extractImageUrlLines(content);
  }

  List<String> _extractImagesFromStructuredPayload(String content) {
    try {
      final decoded = jsonDecode(content);
      return _extractImagesFromJson(decoded);
    } catch (_) {
      return const <String>[];
    }
  }

  List<String> _extractImagesFromJson(Object? value) {
    if (value == null) {
      return const <String>[];
    }
    if (value is String) {
      return _looksLikeImageUrl(value) ? <String>[value] : const <String>[];
    }
    if (value is List) {
      final images = <String>[];
      for (final item in value) {
        images.addAll(_extractImagesFromJson(item));
      }
      return images;
    }
    if (value is Map) {
      final images = <String>[];
      for (final key in const [
        'imageUrls',
        'images',
        'image_urls',
        'picUrls',
        'pics',
        'url',
        'src',
      ]) {
        images.addAll(_extractImagesFromJson(value[key]));
      }
      if (images.isNotEmpty) {
        return images;
      }
      for (final item in value.values) {
        images.addAll(_extractImagesFromJson(item));
      }
      return images;
    }
    return const <String>[];
  }

  List<String> _extractImageUrlsFromHtml(String content) {
    final matches = RegExp(
      r'''<img\b[^>]*(?:src|data-src|data-original|data-url)\s*=\s*["']([^"']+)["'][^>]*>''',
      caseSensitive: false,
    ).allMatches(content);
    return matches
        .map((match) => match.group(1)?.trim() ?? '')
        .where(_looksLikeImageUrl)
        .toList(growable: false);
  }

  List<String> _extractInlineImageMarkers(String content) {
    final escapedPrefix = RegExp.escape(ReaderDocument.inlineImageMarkerPrefix);
    final escapedSuffix = RegExp.escape(ReaderDocument.inlineImageMarkerSuffix);
    final matches = RegExp(
      '$escapedPrefix(.*?)$escapedSuffix',
      dotAll: true,
    ).allMatches(content);
    return matches
        .map((match) => match.group(1)?.trim() ?? '')
        .where(_looksLikeImageUrl)
        .toList(growable: false);
  }

  List<String> _extractImageUrlLines(String content) {
    final lines = content
        .split(RegExp(r'[\r\n,，\s]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty || lines.any((line) => !_looksLikeImageUrl(line))) {
      return const <String>[];
    }
    return lines;
  }

  String _contentWithoutServerImages(String content, List<String> imageUrls) {
    final withoutHtmlImages = content.replaceAll(
      RegExp(r'<img\b[^>]*>', caseSensitive: false),
      '',
    );
    final withoutMarkers = withoutHtmlImages.replaceAll(
      RegExp(
        '${RegExp.escape(ReaderDocument.inlineImageMarkerPrefix)}.*?${RegExp.escape(ReaderDocument.inlineImageMarkerSuffix)}',
        dotAll: true,
      ),
      '',
    );
    final cleaned = _cleaner.clean(withoutMarkers);
    if (cleaned.isEmpty) {
      return '';
    }
    final remainingLines = cleaned
        .split(RegExp(r'\n+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !imageUrls.contains(line))
        .where((line) => !_looksLikeImageUrl(line))
        .toList(growable: false);
    return remainingLines.join('\n\n').trim();
  }

  bool _looksLikeImageUrl(String value) {
    final normalized = value.trim();
    if (normalized.startsWith('data:image/')) {
      return true;
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      return false;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https' && uri.scheme != 'file') {
      return false;
    }
    final path = uri.path.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif') ||
        path.endsWith('.bmp') ||
        path.endsWith('.svg') ||
        path.endsWith('.svgz') ||
        uri.queryParameters.keys.any(
          (key) => key.toLowerCase().contains('image'),
        );
  }

  Future<void> _ensureServerGatewayEnabled(ErrorStage stage) async {
    await _settingsService.loadServerOnlineSearchEnabled();
  }
}
