import '../../../domain/entities/reading_book_status.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reading_record_day.dart';
import '../../../domain/entities/reading_record_session.dart';
import 'reading_stats_distribution_aggregator.dart';
import 'reading_stats_heatmap_aggregator.dart';
import 'reading_stats_models.dart';
import 'reading_stats_ranking_aggregator.dart';
import 'reading_stats_records_filter_service.dart';
import 'reading_stats_scope_service.dart';
import 'reading_stats_summary_aggregator.dart';

export 'reading_stats_models.dart';

class ReadingRecordsQueryService {
  const ReadingRecordsQueryService({
    ReadingStatsScopeService scopeService = const ReadingStatsScopeService(),
    ReadingStatsRecordsFilterService filterService =
        const ReadingStatsRecordsFilterService(),
    ReadingStatsSummaryAggregator summaryAggregator =
        const ReadingStatsSummaryAggregator(),
    ReadingStatsDistributionAggregator distributionAggregator =
        const ReadingStatsDistributionAggregator(),
    ReadingStatsRankingAggregator rankingAggregator =
        const ReadingStatsRankingAggregator(),
    ReadingStatsHeatmapAggregator heatmapAggregator =
        const ReadingStatsHeatmapAggregator(),
  }) : _scopeService = scopeService,
       _filterService = filterService,
       _summaryAggregator = summaryAggregator,
       _distributionAggregator = distributionAggregator,
       _rankingAggregator = rankingAggregator,
       _heatmapAggregator = heatmapAggregator;

  final ReadingStatsScopeService _scopeService;
  final ReadingStatsRecordsFilterService _filterService;
  final ReadingStatsSummaryAggregator _summaryAggregator;
  final ReadingStatsDistributionAggregator _distributionAggregator;
  final ReadingStatsRankingAggregator _rankingAggregator;
  final ReadingStatsHeatmapAggregator _heatmapAggregator;

  ReadingRecordsQueryView buildQueryView({
    required List<ReadingRecord> latestRecords,
    required List<ReadingRecordDay> dailyRecords,
    required List<ReadingRecordSession> sessions,
    required ReadingRecordsPeriod period,
    required DateTime anchor,
    required Map<String, ReadingBookResolvedStatus> resolvedStatusesByBookId,
  }) {
    final periodRange = resolvePeriodRange(period: period, anchor: anchor);
    final filtered = _filterService.filter(
      latestRecords: latestRecords,
      dailyRecords: dailyRecords,
      sessions: sessions,
      periodRange: periodRange,
    );

    return ReadingRecordsQueryView(
      periodRange: periodRange,
      filteredLatestRecords: filtered.filteredLatestRecords,
      summary: _summaryAggregator.buildSummary(
        latestRecords: latestRecords,
        dailyRecords: dailyRecords,
        filteredLatestRecords: filtered.filteredLatestRecords,
        filteredDailyRecords: filtered.filteredDailyRecords,
        filteredSessions: filtered.filteredSessions,
        periodRange: periodRange,
        resolvedStatusesByBookId: resolvedStatusesByBookId,
      ),
      distribution: _distributionAggregator.buildDistribution(
        anchor: anchor,
        filteredDailyRecords: filtered.filteredDailyRecords,
      ),
      rankings: _rankingAggregator.buildDurationRankings(
        latestRecords: latestRecords,
        filteredDailyRecords: filtered.filteredDailyRecords,
        periodRange: periodRange,
      ),
    );
  }

  ReadingRecordsPeriodRange resolvePeriodRange({
    required ReadingRecordsPeriod period,
    required DateTime anchor,
  }) {
    return _scopeService.resolvePeriodRange(period: period, anchor: anchor);
  }

  Map<String, DailyHeatmapStat> buildHeatmapStats(
    List<ReadingRecordDay> allDays, {
    required List<ReadingRecordSession> sessions,
  }) {
    return _heatmapAggregator.buildHeatmapStats(allDays, sessions: sessions);
  }
}
