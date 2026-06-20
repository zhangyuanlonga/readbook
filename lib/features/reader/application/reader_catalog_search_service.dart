import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reader_document.dart';
import '../domain/entities/reader_layout_models.dart';
import 'reader_logical_position.dart';
import 'reader_search_anchor_mapper.dart';

class ReaderCatalogSearchEntry {
  const ReaderCatalogSearchEntry({
    required this.title,
    required this.subtitle,
    required this.chapterIndex,
    this.scrollRatio,
    this.logicalPosition,
    this.isContent = false,
    this.isVolume = false,
    this.targetChapterIndex,
  });

  final String title;
  final String subtitle;
  final int chapterIndex;
  final double? scrollRatio;
  final ReaderLogicalPosition? logicalPosition;
  final bool isContent;
  final bool isVolume;
  final int? targetChapterIndex;
}

class ReaderCatalogSearchCacheState {
  const ReaderCatalogSearchCacheState({
    this.fingerprint,
    this.entriesCache = const <String, List<ReaderCatalogSearchEntry>>{},
  });

  final String? fingerprint;
  final Map<String, List<ReaderCatalogSearchEntry>> entriesCache;
}

class ReaderCatalogSearchLookupResult {
  const ReaderCatalogSearchLookupResult({
    required this.entries,
    required this.state,
  });

  final List<ReaderCatalogSearchEntry> entries;
  final ReaderCatalogSearchCacheState state;
}

class ReaderCatalogSearchService {
  const ReaderCatalogSearchService();

  ReaderCatalogSearchLookupResult lookup({
    required String keyword,
    required ReaderCatalogSearchCacheState state,
    required bool supportsContentSearch,
    required String chapterId,
    required String? chapterUrl,
    required int? currentChapterIndex,
    required List<Chapter> chapters,
    required String chapterContent,
    required List<String> chapterParagraphs,
    required ReaderDocument chapterDocument,
    required bool isPagedTextReaderEnabled,
    required int currentPageIndex,
    List<ReaderLayoutPage> chapterLayoutPages = const <ReaderLayoutPage>[],
    String? chapterLayoutSignature,
    ReaderSearchAnchorMapper searchAnchorMapper =
        const ReaderSearchAnchorMapper(),
  }) {
    final normalizedKeyword = keyword.trim().toLowerCase();
    final fingerprint = buildCacheFingerprint(
      chapterId: chapterId,
      chapterUrl: chapterUrl,
      currentChapterIndex: currentChapterIndex,
      chapters: chapters,
      supportsContentSearch: supportsContentSearch,
      chapterContent: chapterContent,
      chapterParagraphCount: chapterParagraphs.length,
      chapterLayoutPageCount: chapterLayoutPages.length,
      chapterLayoutSignature: chapterLayoutSignature,
    );

    var cache = state.entriesCache;
    if (state.fingerprint != fingerprint) {
      cache = const <String, List<ReaderCatalogSearchEntry>>{};
    }

    final nextState = ReaderCatalogSearchCacheState(
      fingerprint: fingerprint,
      entriesCache: cache,
    );
    if (normalizedKeyword.isEmpty) {
      return ReaderCatalogSearchLookupResult(
        entries: const [],
        state: nextState,
      );
    }

    final cached = cache[normalizedKeyword];
    if (cached != null) {
      return ReaderCatalogSearchLookupResult(entries: cached, state: nextState);
    }

    final entries = List<ReaderCatalogSearchEntry>.unmodifiable(
      buildFullTextSearchEntries(
        keyword: keyword,
        chapters: chapters,
        currentChapterIndex: currentChapterIndex,
        supportsContentSearch: supportsContentSearch,
        chapterContent: chapterContent,
        chapterParagraphs: chapterParagraphs,
        chapterDocument: chapterDocument,
        isPagedTextReaderEnabled: isPagedTextReaderEnabled,
        currentPageIndex: currentPageIndex,
        chapterLayoutPages: chapterLayoutPages,
        searchAnchorMapper: searchAnchorMapper,
      ),
    );
    final mergedCache = <String, List<ReaderCatalogSearchEntry>>{
      ...cache,
      normalizedKeyword: entries,
    };
    return ReaderCatalogSearchLookupResult(
      entries: entries,
      state: ReaderCatalogSearchCacheState(
        fingerprint: fingerprint,
        entriesCache: mergedCache,
      ),
    );
  }

  List<ReaderCatalogSearchEntry> buildFullTextSearchEntries({
    required String keyword,
    required List<Chapter> chapters,
    required int? currentChapterIndex,
    required bool supportsContentSearch,
    required String chapterContent,
    required List<String> chapterParagraphs,
    required ReaderDocument chapterDocument,
    required bool isPagedTextReaderEnabled,
    required int currentPageIndex,
    List<ReaderLayoutPage> chapterLayoutPages = const <ReaderLayoutPage>[],
    ReaderSearchAnchorMapper searchAnchorMapper =
        const ReaderSearchAnchorMapper(),
    int maxEntries = 60,
  }) {
    if (keyword.isEmpty) {
      return const [];
    }

    final normalizedKeyword = keyword.toLowerCase();
    final entries = <ReaderCatalogSearchEntry>[];

    for (var index = 0; index < chapters.length; index++) {
      final chapter = chapters[index];
      final title = chapter.title;
      if (_containsKeyword(title, keyword, normalizedKeyword)) {
        final targetChapterIndex =
            chapter.isVolume
                ? _findReadableChapterIndex(chapters, index + 1)
                : index;
        entries.add(
          ReaderCatalogSearchEntry(
            title: title,
            subtitle:
                chapter.isVolume
                    ? targetChapterIndex == null
                        ? '第 ${index + 1} 项 · 分卷标题，当前无可读章节'
                        : '第 ${index + 1} 项 · 分卷标题，将定位到卷首章节'
                    : '第 ${index + 1} 章 · 目录匹配',
            chapterIndex: index,
            isVolume: chapter.isVolume,
            targetChapterIndex: targetChapterIndex,
          ),
        );
      }
    }

    if (!supportsContentSearch ||
        currentChapterIndex == null ||
        chapterContent.trim().isEmpty) {
      return entries;
    }

    final paragraphs =
        chapterParagraphs.isEmpty
            ? chapterDocument.paragraphs
            : chapterParagraphs;
    if (isPagedTextReaderEnabled &&
        chapterLayoutPages.isNotEmpty &&
        paragraphs.isNotEmpty) {
      final hits = searchAnchorMapper.resolveKeywordHits(
        keyword: keyword,
        paragraphs: paragraphs,
        layoutPages: chapterLayoutPages,
        chapterIndex: currentChapterIndex,
        maxHits: maxEntries - entries.length,
      );
      for (final hit in hits) {
        entries.add(
          ReaderCatalogSearchEntry(
            title: '第 ${currentChapterIndex + 1} 章正文命中',
            subtitle: _buildSearchSnippet(hit.anchor.selectedText, keyword),
            chapterIndex: currentChapterIndex,
            scrollRatio: hit.scrollRatio,
            logicalPosition: hit.logicalPosition,
            isContent: true,
          ),
        );
        if (entries.length >= maxEntries) {
          break;
        }
      }
      return entries;
    }
    if (paragraphs.isEmpty) {
      if (_containsKeyword(chapterContent, keyword, normalizedKeyword)) {
        final logicalPosition = ReaderLogicalPosition.fromDocument(
          document: chapterDocument,
          chapterIndex: currentChapterIndex,
          chapterPositionRatio: 0,
          pageIndex: isPagedTextReaderEnabled ? currentPageIndex : null,
        );
        entries.add(
          ReaderCatalogSearchEntry(
            title: '第 ${currentChapterIndex + 1} 章正文',
            subtitle: _buildSearchSnippet(chapterContent, keyword),
            chapterIndex: currentChapterIndex,
            scrollRatio: 0,
            logicalPosition: logicalPosition,
            isContent: true,
          ),
        );
      }
      return entries;
    }

    for (var index = 0; index < paragraphs.length; index++) {
      final paragraph = paragraphs[index];
      if (!_containsKeyword(paragraph, keyword, normalizedKeyword)) {
        continue;
      }

      final ratio =
          paragraphs.length <= 1 ? 0.0 : index / (paragraphs.length - 1);
      final logicalPosition = ReaderLogicalPosition.fromDocument(
        document: chapterDocument,
        chapterIndex: currentChapterIndex,
        chapterPositionRatio: ratio,
        pageIndex: isPagedTextReaderEnabled ? currentPageIndex : null,
      );
      entries.add(
        ReaderCatalogSearchEntry(
          title: '第 ${currentChapterIndex + 1} 章正文命中',
          subtitle: _buildSearchSnippet(paragraph, keyword),
          chapterIndex: currentChapterIndex,
          scrollRatio: ratio,
          logicalPosition: logicalPosition,
          isContent: true,
        ),
      );
      if (entries.length >= maxEntries) {
        break;
      }
    }

    return entries;
  }

  String buildCacheFingerprint({
    required String chapterId,
    required String? chapterUrl,
    required int? currentChapterIndex,
    required List<Chapter> chapters,
    required bool supportsContentSearch,
    required String chapterContent,
    required int chapterParagraphCount,
    int chapterLayoutPageCount = 0,
    String? chapterLayoutSignature,
  }) {
    final firstChapterId = chapters.isEmpty ? '' : chapters.first.id;
    final lastChapterId = chapters.isEmpty ? '' : chapters.last.id;
    return [
      chapterId,
      chapterUrl ?? '',
      (currentChapterIndex ?? -1).toString(),
      chapters.length.toString(),
      supportsContentSearch ? 'content:on' : 'content:off',
      firstChapterId,
      lastChapterId,
      chapterContent.hashCode.toString(),
      chapterParagraphCount.toString(),
      chapterLayoutPageCount.toString(),
      chapterLayoutSignature ?? '',
    ].join('|');
  }

  bool _containsKeyword(String text, String keyword, String normalizedKeyword) {
    return text.contains(keyword) ||
        text.toLowerCase().contains(normalizedKeyword);
  }

  int? _findReadableChapterIndex(List<Chapter> chapters, int startIndex) {
    if (chapters.isEmpty || startIndex < 0 || startIndex >= chapters.length) {
      return null;
    }
    for (var index = startIndex; index < chapters.length; index++) {
      final chapter = chapters[index];
      if (!chapter.isVolume && chapter.chapterUrl.trim().isNotEmpty) {
        return index;
      }
    }
    return null;
  }

  String _buildSearchSnippet(String source, String keyword) {
    final normalized = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return '未匹配到可展示内容';
    }

    if (normalized.length <= 56) {
      return normalized;
    }

    final keywordLower = keyword.toLowerCase();
    final lower = normalized.toLowerCase();
    final keywordIndex = lower.indexOf(keywordLower);
    if (keywordIndex < 0) {
      return '${normalized.substring(0, 56)}...';
    }

    final start = (keywordIndex - 14).clamp(0, normalized.length);
    final end = (keywordIndex + keyword.length + 22).clamp(
      0,
      normalized.length,
    );
    final snippet = normalized.substring(start, end);

    final prefix = start > 0 ? '...' : '';
    final suffix = end < normalized.length ? '...' : '';
    return '$prefix$snippet$suffix';
  }
}
