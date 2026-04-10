import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reading_record_day.dart';
import 'reading_stats_models.dart';

class ReadingStatsRankingAggregator {
  const ReadingStatsRankingAggregator();

  List<ReadingDurationRankingItem> buildDurationRankings({
    required List<ReadingRecord> latestRecords,
    required List<ReadingRecordDay> filteredDailyRecords,
    required ReadingRecordsPeriodRange periodRange,
  }) {
    if (periodRange.isAll) {
      final items = latestRecords
          .map(
            (record) => ReadingDurationRankingItem(
              record: record,
              readMillis: record.totalReadMillis,
              readChars: record.totalReadChars,
              readDays: 0,
            ),
          )
          .where((item) => item.readMillis > 0)
          .toList(growable: false);
      return _sortRankings(items);
    }

    final recordByBookId = <String, ReadingRecord>{
      for (final record in latestRecords) record.bookId: record,
    };
    final millisByBookId = <String, int>{};
    final charsByBookId = <String, int>{};
    final daysByBookId = <String, Set<String>>{};

    for (final item in filteredDailyRecords) {
      millisByBookId[item.bookId] =
          (millisByBookId[item.bookId] ?? 0) + item.readMillis;
      charsByBookId[item.bookId] =
          (charsByBookId[item.bookId] ?? 0) + item.readChars;
      daysByBookId.putIfAbsent(item.bookId, () => <String>{}).add(item.dateKey);
    }

    final items = <ReadingDurationRankingItem>[];
    for (final entry in millisByBookId.entries) {
      final record = recordByBookId[entry.key];
      if (record == null || entry.value <= 0) {
        continue;
      }
      items.add(
        ReadingDurationRankingItem(
          record: record,
          readMillis: entry.value,
          readChars: charsByBookId[entry.key] ?? 0,
          readDays: daysByBookId[entry.key]?.length ?? 0,
        ),
      );
    }
    return _sortRankings(items);
  }

  List<ReadingDurationRankingItem> _sortRankings(
    List<ReadingDurationRankingItem> items,
  ) {
    final mutable = List<ReadingDurationRankingItem>.from(items);
    mutable.sort((a, b) {
      final millisCompare = b.readMillis.compareTo(a.readMillis);
      if (millisCompare != 0) {
        return millisCompare;
      }
      final daysCompare = b.readDays.compareTo(a.readDays);
      if (daysCompare != 0) {
        return daysCompare;
      }
      return b.record.lastReadAt.compareTo(a.record.lastReadAt);
    });
    return List<ReadingDurationRankingItem>.unmodifiable(mutable);
  }
}
