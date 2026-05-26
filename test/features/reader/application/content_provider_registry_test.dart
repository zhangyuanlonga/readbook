import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/book.dart';
import 'package:shuxiang_reading_next/domain/entities/bookshelf_book.dart';
import 'package:shuxiang_reading_next/features/book/application/book_detail_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/chapter_content_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/content_provider.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_reader_identity.dart';

class _FakeContentProvider extends ContentProvider {
  const _FakeContentProvider({
    required this.label,
    required this.supportedSourceIds,
    required this.capabilities,
  });

  final String label;
  final Set<String> supportedSourceIds;

  @override
  final ContentCapabilities capabilities;

  @override
  bool supportsSourceId(String sourceId) {
    return supportedSourceIds.contains(sourceId.trim());
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
  }) {
    throw UnimplementedError();
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
  }) {
    throw UnimplementedError();
  }
}

void main() {
  group('ContentProviderRegistry', () {
    const localProvider = _FakeContentProvider(
      label: 'local',
      supportedSourceIds: <String>{LocalReaderIdentity.localSourceId},
      capabilities: ContentCapabilities(canReindexLocal: true),
    );
    const remoteProvider = _FakeContentProvider(
      label: 'remote',
      supportedSourceIds: <String>{'remote_source'},
      capabilities: ContentCapabilities(canSwitchSource: true),
    );

    test('resolves local provider for local source id and bookshelf book', () {
      final registry = ContentProviderRegistry(
        providers: <ContentProvider>[localProvider, remoteProvider],
      );
      final localBook = BookshelfBook(
        bookId: 'local_book_1',
        sourceId: LocalReaderIdentity.localSourceId,
        title: '本地书',
        detailUrl: LocalReaderIdentity.buildBookDetailUrl('local_book_1'),
        addedAt: DateTime(2026, 4, 27),
      );

      final resolvedBySource = registry.providerForSourceId(
        LocalReaderIdentity.localSourceId,
      );
      final resolvedByBook = registry.providerForBook(localBook);

      expect(resolvedBySource, same(localProvider));
      expect(resolvedByBook, same(localProvider));
      expect(resolvedByBook.capabilities.canReindexLocal, isTrue);
    });
  });
}
