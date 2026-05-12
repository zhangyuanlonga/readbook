import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reader_document.dart';
import '../../reader/application/reader_catalog_search_service.dart';

class BookDetailCatalogLookupResult {
  const BookDetailCatalogLookupResult({
    required this.entries,
    required this.state,
  });

  final List<ReaderCatalogSearchEntry> entries;
  final ReaderCatalogSearchCacheState state;
}

class BookDetailCatalogService {
  const BookDetailCatalogService({
    ReaderCatalogSearchService catalogSearchService =
        const ReaderCatalogSearchService(),
  }) : _catalogSearchService = catalogSearchService;

  final ReaderCatalogSearchService _catalogSearchService;

  List<Chapter> buildDisplayedChapters(
    List<Chapter> chapters, {
    required bool reversed,
  }) {
    if (!reversed) {
      return chapters;
    }
    return chapters.reversed.toList(growable: false);
  }

  Chapter? resolveChapterFromBookmark(
    List<Chapter> chapters,
    Bookmark bookmark,
  ) {
    final chapterId = bookmark.chapterId.trim();
    if (chapterId.isNotEmpty) {
      for (final chapter in chapters) {
        if (chapter.id == chapterId &&
            !chapter.isVolume &&
            chapter.chapterUrl.trim().isNotEmpty) {
          return chapter;
        }
      }
    }

    final chapterIndex = bookmark.chapterIndex;
    if (chapterIndex >= 0 && chapterIndex < chapters.length) {
      final chapter = chapters[chapterIndex];
      if (!chapter.isVolume && chapter.chapterUrl.trim().isNotEmpty) {
        return chapter;
      }
    }
    return null;
  }

  BookDetailCatalogLookupResult lookupEntries({
    required String keyword,
    required ReaderCatalogSearchCacheState state,
    required List<Chapter> chapters,
  }) {
    final result = _catalogSearchService.lookup(
      keyword: keyword,
      state: state,
      supportsContentSearch: false,
      chapterId: '',
      chapterUrl: null,
      currentChapterIndex: null,
      chapters: chapters,
      chapterContent: '',
      chapterParagraphs: const <String>[],
      chapterDocument: ReaderDocument(blocks: const <ReaderBlock>[]),
      isPagedTextReaderEnabled: false,
      currentPageIndex: 0,
    );
    return BookDetailCatalogLookupResult(
      entries: result.entries,
      state: result.state,
    );
  }

  List<ReaderCatalogSearchEntry>? peekEntries({
    required String normalizedKeyword,
    required List<Chapter> chapters,
    required String? fingerprint,
    required Map<String, List<ReaderCatalogSearchEntry>> entriesCache,
    required void Function(String fingerprint) onFingerprintResolved,
    required void Function() onCacheInvalidated,
  }) {
    final nextFingerprint = _catalogSearchService.buildCacheFingerprint(
      chapterId: '',
      chapterUrl: null,
      currentChapterIndex: null,
      chapters: chapters,
      supportsContentSearch: false,
      chapterContent: '',
      chapterParagraphCount: 0,
    );
    if (fingerprint != nextFingerprint) {
      onCacheInvalidated();
      onFingerprintResolved(nextFingerprint);
    }
    return entriesCache[normalizedKeyword];
  }

  int? resolveEntryTargetIndex(
    ReaderCatalogSearchEntry entry,
    List<Chapter> chapters,
  ) {
    final candidateIndex =
        entry.isContent
            ? entry.chapterIndex
            : (entry.targetChapterIndex ??
                (entry.isVolume ? null : entry.chapterIndex));
    if (candidateIndex == null ||
        candidateIndex < 0 ||
        candidateIndex >= chapters.length) {
      return null;
    }
    final chapter = chapters[candidateIndex];
    if (chapter.isVolume || chapter.chapterUrl.trim().isEmpty) {
      return null;
    }
    return candidateIndex;
  }
}
