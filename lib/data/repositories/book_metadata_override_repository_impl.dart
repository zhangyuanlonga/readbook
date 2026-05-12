import '../../data/datasources/local/app_database.dart';
import '../../domain/entities/book_metadata_override.dart';
import '../../domain/repositories/book_metadata_override_repository.dart';

class BookMetadataOverrideRepositoryImpl
    implements BookMetadataOverrideRepository {
  BookMetadataOverrideRepositoryImpl(this._database);

  final AppDatabase _database;

  @override
  Future<void> deleteByLocalBookId(String bookId) =>
      _database.deleteBookMetadataOverrideByLocalBookId(bookId);

  @override
  Future<void> deleteByRemoteBook({
    required String sourceId,
    required String detailUrl,
  }) => _database.deleteBookMetadataOverrideByRemoteBook(
    sourceId: sourceId,
    detailUrl: detailUrl,
  );

  @override
  Future<void> deleteByTargetKey(String targetKey) =>
      _database.deleteBookMetadataOverrideByTargetKey(targetKey);

  @override
  Future<BookMetadataOverride?> getByLocalBookId(String bookId) =>
      _database.getBookMetadataOverrideByLocalBookId(bookId);

  @override
  Future<BookMetadataOverride?> getByRemoteBook({
    required String sourceId,
    required String detailUrl,
  }) => _database.getBookMetadataOverrideByRemoteBook(
    sourceId: sourceId,
    detailUrl: detailUrl,
  );

  @override
  Future<BookMetadataOverride?> getByTargetKey(String targetKey) =>
      _database.getBookMetadataOverrideByTargetKey(targetKey);

  @override
  Future<List<BookMetadataOverride>> getAll() =>
      _database.getAllBookMetadataOverrides();

  @override
  Stream<List<BookMetadataOverride>> watchAll() =>
      _database.watchBookMetadataOverrides();

  @override
  Future<void> upsert(BookMetadataOverride metadataOverride) =>
      _database.upsertBookMetadataOverride(metadataOverride);
}
