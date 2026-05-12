import '../../../domain/entities/bookshelf_book.dart';
import '../../book/application/book_detail_service.dart';
import 'chapter_content_service.dart';

class ContentCapabilities {
  const ContentCapabilities({
    this.canSwitchSource = false,
    this.canCacheChapter = false,
    this.canRefreshToc = false,
    this.canSearchInSource = false,
    this.canReindexLocal = false,
  });

  final bool canSwitchSource;
  final bool canCacheChapter;
  final bool canRefreshToc;
  final bool canSearchInSource;
  final bool canReindexLocal;

  ContentCapabilities copyWith({
    bool? canSwitchSource,
    bool? canCacheChapter,
    bool? canRefreshToc,
    bool? canSearchInSource,
    bool? canReindexLocal,
  }) {
    return ContentCapabilities(
      canSwitchSource: canSwitchSource ?? this.canSwitchSource,
      canCacheChapter: canCacheChapter ?? this.canCacheChapter,
      canRefreshToc: canRefreshToc ?? this.canRefreshToc,
      canSearchInSource: canSearchInSource ?? this.canSearchInSource,
      canReindexLocal: canReindexLocal ?? this.canReindexLocal,
    );
  }
}

abstract class ContentProvider {
  const ContentProvider();

  ContentCapabilities get capabilities;

  bool supportsSourceId(String sourceId);

  bool supportsBook(BookshelfBook book) {
    return supportsSourceId(book.sourceId);
  }

  Future<BookDetailLoadResult> loadDetail({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    String? fallbackTitle,
    String? fallbackAuthor,
    bool forceRefresh = false,
    bool includeCatalog = true,
  });

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
  });
}

class ContentProviderRegistry {
  ContentProviderRegistry({Iterable<ContentProvider> providers = const []})
    : _providers = List<ContentProvider>.of(providers);

  final List<ContentProvider> _providers;

  List<ContentProvider> get providers => List.unmodifiable(_providers);

  void register(ContentProvider provider) {
    _providers.add(provider);
  }

  void registerAll(Iterable<ContentProvider> providers) {
    _providers.addAll(providers);
  }

  ContentProvider? findForBook(BookshelfBook book) {
    for (final provider in _providers) {
      if (provider.supportsBook(book)) {
        return provider;
      }
    }
    return null;
  }

  ContentProvider? findForSourceId(String sourceId) {
    final normalized = sourceId.trim();
    if (normalized.isEmpty) {
      return null;
    }
    for (final provider in _providers) {
      if (provider.supportsSourceId(normalized)) {
        return provider;
      }
    }
    return null;
  }

  ContentProvider providerForBook(BookshelfBook book) {
    final provider = findForBook(book);
    if (provider == null) {
      throw StateError('No ContentProvider for book sourceId=${book.sourceId}');
    }
    return provider;
  }

  ContentProvider providerForSourceId(String sourceId) {
    final provider = findForSourceId(sourceId);
    if (provider == null) {
      throw StateError('No ContentProvider for sourceId=$sourceId');
    }
    return provider;
  }
}
