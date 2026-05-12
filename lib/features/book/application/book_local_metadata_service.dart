import '../../../domain/entities/local_book.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../reader/application/local/local_reader_identity.dart';

class BookLocalMetadataService {
  const BookLocalMetadataService({
    required LocalBookRepository localBookRepository,
  }) : _localBookRepository = localBookRepository;

  final LocalBookRepository _localBookRepository;

  Future<LocalBook?> loadLocalBook({
    required String sourceId,
    required String bookId,
  }) async {
    if (!LocalReaderIdentity.isLocalSourceId(sourceId)) {
      return null;
    }
    return _localBookRepository.getBookById(bookId);
  }
}
