import '../entities/book_metadata_override.dart';

abstract class BookMetadataOverrideRepository {
  Future<BookMetadataOverride?> getByTargetKey(String targetKey);

  Future<BookMetadataOverride?> getByLocalBookId(String bookId);

  Future<BookMetadataOverride?> getByRemoteBook({
    required String sourceId,
    required String detailUrl,
  });

  Future<List<BookMetadataOverride>> getAll();

  Stream<List<BookMetadataOverride>> watchAll();

  Future<void> upsert(BookMetadataOverride metadataOverride);

  Future<void> deleteByTargetKey(String targetKey);

  Future<void> deleteByLocalBookId(String bookId);

  Future<void> deleteByRemoteBook({
    required String sourceId,
    required String detailUrl,
  });
}
