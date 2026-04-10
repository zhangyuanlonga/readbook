import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reading_book_status.dart';
import '../../../domain/entities/reading_record.dart';

class ReadingBookStatusService {
  ReadingBookStatusService({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  static const double completedPositionRatioThreshold = 0.9;

  Stream<List<ReadingBookStatusEntry>> watchManualStatuses() {
    return _database.watchReadingBookStatuses();
  }

  Stream<List<LocalBook>> watchLocalBooks() {
    return _database.watchAllLocalBooks();
  }

  Future<void> setManualStatus({
    required ReadingRecord record,
    required ReadingBookStatusOverride override,
  }) {
    return _database.upsertReadingBookStatus(
      ReadingBookStatusEntry(
        bookId: record.bookId,
        sourceId: record.sourceId,
        detailUrl: record.detailUrl,
        bookTitle: record.bookTitle,
        override: override,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> clearManualStatus(String bookId) {
    return _database.deleteReadingBookStatus(bookId);
  }

  Map<String, ReadingBookResolvedStatus> resolveStatuses({
    required List<ReadingRecord> latestRecords,
    required List<LocalBook> localBooks,
    required List<ReadingBookStatusEntry> manualStatuses,
  }) {
    final localBookById = <String, LocalBook>{
      for (final book in localBooks) book.id: book,
    };
    final manualByBookId = <String, ReadingBookStatusEntry>{
      for (final item in manualStatuses) item.bookId: item,
    };

    return {
      for (final record in latestRecords)
        record.bookId: resolveStatus(
          record: record,
          localBook: localBookById[record.bookId],
          manualStatus: manualByBookId[record.bookId],
        ),
    };
  }

  ReadingBookResolvedStatus resolveStatus({
    required ReadingRecord record,
    LocalBook? localBook,
    ReadingBookStatusEntry? manualStatus,
  }) {
    final manualOverride = manualStatus?.override;
    if (manualOverride != null) {
      return ReadingBookResolvedStatus(
        kind: _overrideToKind(manualOverride),
        isManual: true,
      );
    }

    if (_isLocalBookCompleted(record: record, localBook: localBook)) {
      return const ReadingBookResolvedStatus(
        kind: ReadingBookStatusKind.completed,
        isManual: false,
      );
    }

    return const ReadingBookResolvedStatus(
      kind: ReadingBookStatusKind.reading,
      isManual: false,
    );
  }

  bool _isLocalBookCompleted({
    required ReadingRecord record,
    required LocalBook? localBook,
  }) {
    if (localBook == null || localBook.chapterCount <= 0) {
      return false;
    }

    final chapterIndex = record.lastChapterIndex;
    if (chapterIndex == null || chapterIndex < 0) {
      return false;
    }

    if (chapterIndex >= localBook.chapterCount) {
      return true;
    }

    return chapterIndex == localBook.chapterCount - 1 &&
        record.lastPositionRatio >= completedPositionRatioThreshold;
  }

  ReadingBookStatusKind _overrideToKind(ReadingBookStatusOverride override) {
    return switch (override) {
      ReadingBookStatusOverride.reading => ReadingBookStatusKind.reading,
      ReadingBookStatusOverride.completed => ReadingBookStatusKind.completed,
    };
  }
}
