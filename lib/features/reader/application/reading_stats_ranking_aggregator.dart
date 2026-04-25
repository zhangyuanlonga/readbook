import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reading_record_day.dart';
import 'reading_stats_models.dart';
import 'reading_stats_work_identity_service.dart';

class ReadingStatsRankingAggregator {
  const ReadingStatsRankingAggregator({
    ReadingStatsWorkIdentityService workIdentityService =
        const ReadingStatsWorkIdentityService(),
  }) : _workIdentityService = workIdentityService;

  final ReadingStatsWorkIdentityService _workIdentityService;

  List<ReadingDurationRankingItem> buildDurationRankings({
    required List<ReadingRecord> latestRecords,
    required List<ReadingRecordDay> filteredDailyRecords,
    required ReadingRecordsPeriodRange periodRange,
  }) {
    final recordGroups = _workIdentityService.groupItems(
      items: latestRecords,
      titleOf: (item) => item.bookTitle,
      authorOf: (item) => item.bookAuthor,
      fallbackIdOf: (item) => item.bookId,
    );

    if (periodRange.isAll) {
      final items = recordGroups.values
          .map(
            (records) => ReadingDurationRankingItem(
              record: _resolveRepresentativeRecord(records),
              readMillis: records.fold<int>(
                0,
                (sum, item) => sum + item.totalReadMillis,
              ),
              readChars: records.fold<int>(
                0,
                (sum, item) => sum + item.totalReadChars,
              ),
              readDays: 0,
            ),
          )
          .where((item) => item.readMillis > 0)
          .toList(growable: false);
      return _sortRankings(items);
    }

    final dayGroups = _workIdentityService.groupItems(
      items: filteredDailyRecords,
      titleOf: (item) => item.bookTitle,
      authorOf: (item) => item.bookAuthor,
      fallbackIdOf: (item) => item.bookId,
    );

    final items = <ReadingDurationRankingItem>[];
    for (final entry in dayGroups.entries) {
      final representativeRecords = recordGroups[entry.key];
      if (representativeRecords == null || representativeRecords.isEmpty) {
        continue;
      }
      final readMillis = entry.value.fold<int>(
        0,
        (sum, item) => sum + item.readMillis,
      );
      if (readMillis <= 0) {
        continue;
      }
      items.add(
        ReadingDurationRankingItem(
          record: _resolveRepresentativeRecord(representativeRecords),
          readMillis: readMillis,
          readChars: entry.value.fold<int>(
            0,
            (sum, item) => sum + item.readChars,
          ),
          readDays: entry.value.map((item) => item.dateKey).toSet().length,
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

  ReadingRecord _resolveRepresentativeRecord(List<ReadingRecord> records) {
    var best = records.first;
    for (final item in records.skip(1)) {
      if (item.lastReadAt.isAfter(best.lastReadAt)) {
        best = item;
        continue;
      }
      final bestCover = best.coverUrl?.trim() ?? '';
      final itemCover = item.coverUrl?.trim() ?? '';
      if (bestCover.isEmpty && itemCover.isNotEmpty) {
        best = item;
      }
    }
    return best;
  }
}
