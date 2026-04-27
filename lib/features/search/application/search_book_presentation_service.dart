import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/book.dart';
import '../../book/application/book_metadata_presentation_resolver.dart';

class SearchBookPresentationService {
  SearchBookPresentationService({
    AppDatabase? database,
    BookMetadataPresentationResolver resolver =
        const BookMetadataPresentationResolver(),
  }) : _database = database ?? AppDatabase.instance,
       _resolver = resolver;

  final AppDatabase _database;
  final BookMetadataPresentationResolver _resolver;

  Future<BookMetadataPresentation> resolve(Book book) async {
    final override = await _database.getBookMetadataOverrideByRemoteBook(
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
    );
    return _resolver.resolve(
      fallbackTitle: book.title,
      fallbackAuthor: book.author,
      fallbackIntro: book.intro,
      realCoverUrl: book.coverUrl,
      metadataOverride: override,
    );
  }
}
