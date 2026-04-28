import '../../../domain/entities/book.dart';
import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/repositories/book_metadata_override_repository.dart';
import '../../bookshelf/application/local_book_import_service.dart';
import 'book_metadata_presentation_resolver.dart';

class BookPresentationQueryService {
  BookPresentationQueryService({
    required BookMetadataOverrideRepository bookMetadataOverrideRepository,
    BookMetadataPresentationResolver resolver =
        const BookMetadataPresentationResolver(),
  }) : _bookMetadataOverrideRepository = bookMetadataOverrideRepository,
       _resolver = resolver;

  final BookMetadataOverrideRepository _bookMetadataOverrideRepository;
  final BookMetadataPresentationResolver _resolver;

  Future<BookMetadataPresentation> resolveRemoteBook(Book book) async {
    final override = await _bookMetadataOverrideRepository.getByRemoteBook(
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
    );
    return _resolver.resolveRemoteBook(book: book, metadataOverride: override);
  }

  Future<Map<String, BookMetadataOverride>> loadMetadataOverrideMapForBooks(
    List<BookshelfBook> books,
  ) async {
    if (books.isEmpty) {
      return const <String, BookMetadataOverride>{};
    }

    final overrides = await _bookMetadataOverrideRepository.getAll();
    final validKeys =
        books
            .map(metadataTargetKeyForBookshelfBook)
            .whereType<String>()
            .toSet();
    return <String, BookMetadataOverride>{
      for (final item in overrides)
        if (validKeys.contains(item.targetKey)) item.targetKey: item,
    };
  }

  String? metadataTargetKeyForBookshelfBook(BookshelfBook book) {
    final normalizedBookId = book.bookId.trim();
    if (normalizedBookId.isEmpty) {
      return null;
    }
    if (book.sourceId.trim() == LocalBookImportService.localBookSourceId) {
      return BookMetadataOverride.localTargetKey(normalizedBookId);
    }

    final detailUrl = book.detailUrl.trim();
    if (detailUrl.isEmpty) {
      return null;
    }
    return BookMetadataOverride.remoteTargetKey(
      sourceId: book.sourceId,
      detailUrl: detailUrl,
    );
  }
}
