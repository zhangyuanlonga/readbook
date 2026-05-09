import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/navigation/app_navigation_style_provider.dart';
import '../../../app/navigation/mobile_bottom_navigation_inset.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/app_empty_state_card.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reading_record_day.dart';
import '../../../domain/entities/reading_record_session.dart';
import '../../book/application/book_display_state.dart';
import '../../mine/application/advanced_theme_provider.dart';
import '../../mine/application/cover_gallery_provider.dart';
import '../application/reading_records_page_dependencies_provider.dart';
import '../application/reading_records_page_state_service.dart';
import '../application/reading_book_status_service.dart';
import '../application/reader_entry_route_resolver.dart';
import '../application/reader_preferences_service.dart';
import '../application/reading_records_query_service.dart';
import '../application/reading_records_stats_presenter.dart';
import '../application/reading_record_service.dart';
import '../application/reader_system_settings_service.dart';

enum _HeatmapRangeMode { threeMonths, sixMonths, oneYear, all }

class ReadingRecordsPage extends ConsumerStatefulWidget {
  const ReadingRecordsPage({
    super.key,
    ReadingRecordService? readingRecordService,
    ReaderPreferencesService? preferencesService,
    ReaderSystemSettingsService? readerSystemSettingsService,
    ReadingBookStatusService? readingBookStatusService,
    ReadingRecordOpenRouteService? recordOpenRouteService,
    ReadingRecordsPresentationService? presentationService,
    this.initialPeriod,
  }) : _readingRecordService = readingRecordService,
       _preferencesService = preferencesService,
       _readerSystemSettingsService = readerSystemSettingsService,
       _readingBookStatusService = readingBookStatusService,
       _recordOpenRouteService = recordOpenRouteService,
       _presentationService = presentationService;

  final ReadingRecordService? _readingRecordService;
  final ReaderPreferencesService? _preferencesService;
  final ReaderSystemSettingsService? _readerSystemSettingsService;
  final ReadingBookStatusService? _readingBookStatusService;
  final ReadingRecordOpenRouteService? _recordOpenRouteService;
  final ReadingRecordsPresentationService? _presentationService;
  final ReadingRecordsPeriod? initialPeriod;

  @override
  ConsumerState<ReadingRecordsPage> createState() => _ReadingRecordsPageState();
}

class _ReadingRecordsPageState extends ConsumerState<ReadingRecordsPage> {
  static const double _kHeatmapCellSize = 14;
  static const double _kHeatmapCellGap = 4;
  static const double _kHeatmapWeekGap = 4;

  late final ReadingRecordService _readingRecordService;
  late final ReadingRecordsQueryService _readingRecordsQueryService;
  late final ReaderSystemSettingsService _readerSystemSettingsService;
  late final ReadingBookStatusService _readingBookStatusService;
  late final ReadingRecordOpenRouteService _recordOpenRouteService;
  late final ReadingRecordsPresentationService _presentationService;
  late final ReadingRecordsPageStateService _pageStateService;
  late final ReadingRecordsStatsPresenter _statsPresenter;
  late final Stream<bool> _readRecordEnabledStream;
  Map<String, LocalBook> _localBooksById = const <String, LocalBook>{};
  Map<String, BookMetadataOverride> _metadataOverridesByTargetKey =
      const <String, BookMetadataOverride>{};

  ReadingRecordsPeriod _period = ReadingRecordsPeriod.day;
  DateTime _periodAnchor = DateTime.now();
  _HeatmapRangeMode _heatmapRangeMode = _HeatmapRangeMode.threeMonths;
  DateTime? _selectedCalendarDate;

  @override
  void initState() {
    super.initState();
    final dependencies = ref.read(readingRecordsPageDependenciesProvider);
    _readingRecordService =
        widget._readingRecordService ?? dependencies.readingRecordService;
    _readingRecordsQueryService = dependencies.readingRecordsQueryService;
    _readerSystemSettingsService =
        widget._readerSystemSettingsService ??
        dependencies.readerSystemSettingsService;
    _readingBookStatusService =
        widget._readingBookStatusService ??
        dependencies.readingBookStatusService;
    _recordOpenRouteService =
        widget._recordOpenRouteService ??
        (widget._preferencesService == null
            ? dependencies.recordOpenRouteService
            : ReadingRecordOpenRouteService(
              preferencesService: widget._preferencesService!,
              readerEntryRouteResolver: const ReaderEntryRouteResolver(),
            ));
    _presentationService =
        widget._presentationService ?? dependencies.presentationService;
    _pageStateService = dependencies.pageStateService;
    _statsPresenter = dependencies.statsPresenter;
    _period = widget.initialPeriod ?? _period;
    _readRecordEnabledStream =
        _readerSystemSettingsService.watchReadRecordEnabled();
  }

  @override
  void dispose() {
    super.dispose();
  }

  ReadingRecordsPeriodRange get _currentPeriodRange =>
      _readingRecordsQueryService.resolvePeriodRange(
        period: _period,
        anchor: _periodAnchor,
      );

  void _setPeriod(ReadingRecordsPeriod period, {DateTime? anchor}) {
    setState(() {
      _period = period;
      if (anchor != null) {
        _periodAnchor = _stripDate(anchor);
      }
      if (period != ReadingRecordsPeriod.month) {
        _selectedCalendarDate = null;
      }
    });
  }

  void _movePeriod(int offset) {
    if (_period == ReadingRecordsPeriod.all) {
      return;
    }
    setState(() {
      _periodAnchor = _shiftPeriodAnchor(_periodAnchor, offset);
      if (_period != ReadingRecordsPeriod.month) {
        _selectedCalendarDate = null;
      }
    });
  }

  DateTime _shiftPeriodAnchor(DateTime anchor, int offset) {
    final normalized = _stripDate(anchor);
    switch (_period) {
      case ReadingRecordsPeriod.day:
        return normalized.add(Duration(days: offset));
      case ReadingRecordsPeriod.week:
        return normalized.add(Duration(days: 7 * offset));
      case ReadingRecordsPeriod.month:
        return DateTime(normalized.year, normalized.month + offset, 1);
      case ReadingRecordsPeriod.year:
        return DateTime(
          normalized.year + offset,
          normalized.month,
          normalized.day,
        );
      case ReadingRecordsPeriod.all:
        return normalized;
    }
  }

  bool get _canMovePeriodForward {
    if (_period == ReadingRecordsPeriod.all) {
      return false;
    }
    final nextRange = _readingRecordsQueryService.resolvePeriodRange(
      period: _period,
      anchor: _shiftPeriodAnchor(_periodAnchor, 1),
    );
    final currentRange = _readingRecordsQueryService.resolvePeriodRange(
      period: _period,
      anchor: DateTime.now(),
    );
    if (nextRange.start == null || currentRange.start == null) {
      return false;
    }
    return !nextRange.start!.isAfter(currentRange.start!);
  }

  String _periodLabel(ReadingRecordsPeriod period) {
    return switch (period) {
      ReadingRecordsPeriod.day => '日',
      ReadingRecordsPeriod.week => '周',
      ReadingRecordsPeriod.month => '月',
      ReadingRecordsPeriod.year => '年',
      ReadingRecordsPeriod.all => '总',
    };
  }

  Future<void> _openRecord(ReadingRecord record) async {
    final route = await _recordOpenRouteService.resolveRoute(record);
    if (!mounted) {
      return;
    }
    context.push(route);
  }

  Future<void> _openDistributionCalendarSheet(
    ReadingCalendarDistribution distribution,
  ) async {
    final bottomInset = mobileBottomNavigationBodyInset(
      context,
      style: _resolveEffectiveNavigationStyle(),
      showNavigationLabels: ref.read(appNavigationLabelVisibilityProvider),
      standardAppearance: ref.read(appStandardNavigationBarAppearanceProvider),
    );
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final metrics = AppAdaptiveMetrics.of(sheetContext);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.pagePadding,
            metrics.contentGap,
            metrics.pagePadding,
            metrics.sectionGap + bottomInset,
          ),
          child: SingleChildScrollView(
            child: _buildDistributionCalendarOverview(
              distribution,
              embeddedInSheet: true,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(activeAdvancedThemeProvider);
    final metrics = AppAdaptiveMetrics.of(context);
    final horizontal = metrics.pagePadding;
    final backdrop = resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      ref.read(activeAdvancedThemeProvider).valueOrNull,
    );
    final platform = Theme.of(context).platform;
    final effectiveNavigationStyle = resolveAppNavigationStyle(
      ref.watch(appNavigationStylePreferenceProvider),
      isWeb: false,
      platform: platform,
    );
    final showNavigationLabels = ref.watch(
      appNavigationLabelVisibilityProvider,
    );
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('统计'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      body: DecoratedBox(
        decoration: buildAdvancedThemeBackdropDecoration(backdrop),
        child: LayoutBuilder(
          builder: (context, _) {
            final maxWidth = AppLayout.pageContentMaxWidth(
              context,
              maxWidth: AppLayout.settingsContentMaxWidth,
            );
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: StreamBuilder<ReadingRecordsPageState>(
                  stream: _pageStateService.watchPageState(
                    latestRecordsStream:
                        _readingRecordService.watchLatestRecords(),
                    dailyRecordsStream:
                        _readingRecordService.watchDailyRecords(),
                    sessionsStream: _readingRecordService.watchSessions(),
                    localBooksStream: _presentationService.watchLocalBooks(),
                    metadataOverridesStream:
                        _presentationService.watchMetadataOverrides(),
                    manualStatusesStream:
                        _readingBookStatusService.watchManualStatuses(),
                    period: _period,
                    anchor: _periodAnchor,
                  ),
                  builder: (context, snapshot) {
                    final pageState = snapshot.data;
                    if (pageState == null) {
                      return const SizedBox.shrink();
                    }
                    _localBooksById = pageState.localBooksById;
                    _metadataOverridesByTargetKey =
                        pageState.metadataOverridesByTargetKey;
                    final queryView = pageState.queryView;
                    final visibleSections = pageState.visibleSections;

                    return ListView(
                      padding: mobileBottomNavigationBodyPadding(
                        context,
                        style: effectiveNavigationStyle,
                        showNavigationLabels: showNavigationLabels,
                        standardAppearance: ref.watch(
                          appStandardNavigationBarAppearanceProvider,
                        ),
                        left: horizontal,
                        top: topInset + metrics.contentGap,
                        right: horizontal,
                        bottom: metrics.sectionGap,
                      ),
                      children: [
                        _buildControlsCard(),
                        SizedBox(height: metrics.contentGap * 0.6),
                        _buildSummaryCard(summary: queryView.summary),
                        SizedBox(height: metrics.contentGap),
                        _buildSectionHeading(
                          queryView.distribution.title,
                          subtitle: '当前周期内的阅读时长变化',
                        ),
                        _buildDurationDistributionCard(
                          queryView.distribution,
                          calendar: queryView.distributionCalendar,
                        ),
                        if (visibleSections.showWeekActivity) ...[
                          SizedBox(height: metrics.contentGap),
                          _buildWeeklyActivityCard(
                            periodRange: queryView.periodRange,
                            dailyRecords: pageState.dailyRecords,
                            sessions: pageState.sessions,
                          ),
                        ],
                        if (visibleSections.showCalendar) ...[
                          SizedBox(height: metrics.contentGap),
                          _buildReadingCalendarCard(
                            queryView.distributionCalendar,
                            dailyRecords: pageState.dailyRecords,
                            sessions: pageState.sessions,
                          ),
                        ],
                        if (visibleSections.showRanking) ...[
                          SizedBox(height: metrics.contentGap),
                          _buildDurationRankingSection(queryView.rankings),
                        ],
                        if (visibleSections.showHeatmap) ...[
                          SizedBox(height: metrics.contentGap),
                          _buildHeatmapCard(
                            pageState.dailyRecords,
                            sessions: pageState.sessions,
                            periodRange: queryView.periodRange,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlsCard() {
    final currentPeriodRange = _currentPeriodRange;
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                for (
                  var index = 0;
                  index < ReadingRecordsPeriod.values.length;
                  index++
                ) ...[
                  Expanded(
                    child: _buildPeriodTab(
                      period: ReadingRecordsPeriod.values[index],
                    ),
                  ),
                  if (index < ReadingRecordsPeriod.values.length - 1)
                    Container(
                      width: 1,
                      height: 22,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (_period != ReadingRecordsPeriod.all) ...[
          SizedBox(height: metrics.contentGap * 0.8),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: metrics.contentGap * 0.6,
              vertical: metrics.isCompactDensity ? 2 : 4,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: '上一个周期',
                  onPressed: () => _movePeriod(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    currentPeriodRange.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '下一个周期',
                  onPressed:
                      _canMovePeriodForward ? () => _movePeriod(1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                TextButton(
                  onPressed: () => _setPeriod(ReadingRecordsPeriod.all),
                  child: const Text('重置'),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: metrics.contentGap * 0.8),
        StreamBuilder<bool>(
          stream: _readRecordEnabledStream,
          initialData: true,
          builder: (context, snapshot) {
            final enabled = snapshot.data ?? true;
            if (enabled) {
              return const SizedBox.shrink();
            }
            final colorScheme = Theme.of(context).colorScheme;
            return Container(
              width: double.infinity,
              padding: EdgeInsets.all(metrics.cardPadding * 0.8),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.pause_circle_outline_rounded,
                    size: 18,
                    color: colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '阅读记录已关闭，当前不会继续新增记录。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPeriodTab({required ReadingRecordsPeriod period}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = _period == period;

    return Material(
      color:
          selected
              ? colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
      child: InkWell(
        onTap: () => _setPeriod(period),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Center(
            child: Text(
              _periodLabel(period),
              style: theme.textTheme.labelLarge?.copyWith(
                color:
                    selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeatmapCard(
    List<ReadingRecordDay> allDays, {
    required List<ReadingRecordSession> sessions,
    required ReadingRecordsPeriodRange periodRange,
  }) {
    if (allDays.isEmpty) {
      return _buildEmptyCard('还没有可以展示的阅读热力图。');
    }

    final statsByDate = _readingRecordsQueryService.buildHeatmapStats(
      allDays,
      sessions: sessions,
    );
    final today = _stripDate(DateTime.now());
    final firstDate = statsByDate.keys
        .map(DateTime.parse)
        .fold<DateTime>(
          today,
          (current, item) => item.isBefore(current) ? item : current,
        );
    final startDate =
        _period == ReadingRecordsPeriod.year
            ? _startOfWeek(_stripDate(periodRange.start!))
            : _resolveHeatmapStartDate(firstDate: firstDate, today: today);
    final endDate =
        _period == ReadingRecordsPeriod.year
            ? _stripDate(
                  periodRange.endExclusive!.subtract(const Duration(days: 1)),
                ).isAfter(today)
                ? today
                : _stripDate(
                  periodRange.endExclusive!.subtract(const Duration(days: 1)),
                )
            : today;
    final showEarlierDataIndicator =
        _period == ReadingRecordsPeriod.all &&
        _heatmapRangeMode != _HeatmapRangeMode.all &&
        firstDate.isBefore(startDate);
    final weeks = _buildHeatmapWeeks(startDate: startDate, endDate: endDate);
    final monthLabels = _buildHeatmapMonthLabels(weeks);
    final visibleDateKeys = <String>{};
    for (final week in weeks) {
      for (final day in week) {
        if (day.isBefore(startDate) || day.isAfter(endDate)) {
          continue;
        }
        visibleDateKeys.add(_dateKeyFor(day));
      }
    }
    final maxValue = visibleDateKeys.fold<int>(0, (current, key) {
      final item = statsByDate[key];
      if (item == null) {
        return current;
      }
      return math.max(current, item.readMillis);
    });

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '阅读热力图',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (_period == ReadingRecordsPeriod.all)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _heatmapRangeMode = _HeatmapRangeMode.all;
                    });
                  },
                  child: const Text('重置'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _period == ReadingRecordsPeriod.year
                ? '查看全年每天的阅读活跃分布。'
                : '查看长期每天的阅读活跃分布。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_dateKeyFor(startDate)} 至 ${_dateKeyFor(endDate)}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (_period == ReadingRecordsPeriod.all) ...[
            _buildHeatmapMenu<_HeatmapRangeMode>(
              icon: Icons.date_range_rounded,
              label: _heatmapRangeLabel,
              items: const [
                PopupMenuItem(
                  value: _HeatmapRangeMode.threeMonths,
                  child: Text('近 3 个月'),
                ),
                PopupMenuItem(
                  value: _HeatmapRangeMode.sixMonths,
                  child: Text('近 6 个月'),
                ),
                PopupMenuItem(
                  value: _HeatmapRangeMode.oneYear,
                  child: Text('近 1 年'),
                ),
                PopupMenuItem(value: _HeatmapRangeMode.all, child: Text('全部')),
              ],
              onSelected: (value) {
                setState(() {
                  _heatmapRangeMode = value;
                });
              },
            ),
            const SizedBox(height: 14),
          ] else
            const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: _heatmapLeadingAreaWidth(
                          showEarlierDataIndicator,
                        ),
                      ),
                      for (final label in monthLabels)
                        Padding(
                          padding: const EdgeInsets.only(
                            right: _kHeatmapWeekGap,
                          ),
                          child: SizedBox(
                            width: _heatmapWeekColumnWidth,
                            child: Text(
                              label,
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 18,
                        child: Column(
                          children: const [
                            _WeekdayLabel('一'),
                            SizedBox(height: 4),
                            _WeekdayLabel(''),
                            SizedBox(height: 4),
                            _WeekdayLabel('三'),
                            SizedBox(height: 4),
                            _WeekdayLabel(''),
                            SizedBox(height: 4),
                            _WeekdayLabel('五'),
                            SizedBox(height: 4),
                            _WeekdayLabel(''),
                            SizedBox(height: 4),
                            _WeekdayLabel('日'),
                          ],
                        ),
                      ),
                    ),
                    if (showEarlierDataIndicator) ...[
                      _buildEarlierDataPlaceholderColumn(),
                      const SizedBox(width: 8),
                      _buildEarlierDataHint(),
                      const SizedBox(width: 12),
                    ],
                    for (final week in weeks)
                      Padding(
                        padding: const EdgeInsets.only(right: _kHeatmapWeekGap),
                        child: Column(
                          children: [
                            for (final day in week)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: _kHeatmapCellGap,
                                ),
                                child: _buildHeatmapCell(
                                  day: day,
                                  stats: statsByDate[_dateKeyFor(day)],
                                  maxValue: maxValue,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('少', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 8),
              for (final opacity in const [0.15, 0.35, 0.6, 0.9])
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: opacity),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const SizedBox(width: 12, height: 12),
                  ),
                ),
              const SizedBox(width: 4),
              Text('多', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '点击某一天可切换到按日查看。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: content,
    );
  }

  Widget _buildDurationDistributionCard(
    ReadingDurationDistribution distribution, {
    required ReadingCalendarDistribution calendar,
  }) {
    if (distribution.buckets.isEmpty) {
      return _buildEmptyCard('当前周期下还没有可以展示的阅读时间分布。');
    }

    final colorScheme = Theme.of(context).colorScheme;
    final maxValue =
        distribution.maxReadMillis <= 0
            ? Duration.millisecondsPerMinute
            : distribution.maxReadMillis;
    final axisValues = List<int>.generate(
      5,
      (index) => ((maxValue * (4 - index)) / 4).round(),
      growable: false,
    );
    final visibleLabelCount = distribution.buckets.length;
    final barWidth =
        visibleLabelCount <= 7
            ? 20.0
            : visibleLabelCount <= 12
            ? 16.0
            : 12.0;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '阅读时间分布',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '查看日历',
                  onPressed: () => _openDistributionCalendarSheet(calendar),
                  icon: const Icon(Icons.calendar_month_rounded),
                ),
              ],
            ),
            Text(
              '按当前统计周期展示阅读时长变化。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 208,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 40,
                    child: Column(
                      children: [
                        for (final value in axisValues)
                          Expanded(
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                _formatDistributionAxisValue(value),
                                style: Theme.of(
                                  context,
                                ).textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final chartContentWidth =
                            math.max(
                              distribution.buckets.length * (barWidth + 10),
                              constraints.maxWidth,
                            ) +
                            8;
                        final chartHeight = constraints.maxHeight;
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: chartContentWidth,
                            child: Column(
                              children: [
                                Expanded(
                                  child: Stack(
                                    children: [
                                      for (
                                        var index = 0;
                                        index < axisValues.length;
                                        index++
                                      )
                                        Positioned.fill(
                                          top:
                                              index == 0
                                                  ? 0
                                                  : (index /
                                                          axisValues.length) *
                                                      chartHeight,
                                          child: Align(
                                            alignment: Alignment.topCenter,
                                            child: _DashedHorizontalLine(
                                              color: colorScheme.outlineVariant
                                                  .withValues(alpha: 0.35),
                                              dashWidth: 6,
                                              gapWidth: 4,
                                              strokeWidth: 1,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          for (final bucket
                                              in distribution.buckets)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                  ),
                                              child: Tooltip(
                                                message:
                                                    '${bucket.label}\n${_formatDuration(bucket.readMillis)}',
                                                child: SizedBox(
                                                  width: barWidth,
                                                  height: chartHeight,
                                                  child: Align(
                                                    alignment:
                                                        Alignment.bottomCenter,
                                                    child: Container(
                                                      width: barWidth,
                                                      height:
                                                          maxValue <= 0
                                                              ? 0
                                                              : (bucket.readMillis /
                                                                          maxValue)
                                                                      .clamp(
                                                                        0.0,
                                                                        1.0,
                                                                      ) *
                                                                  chartHeight,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            colorScheme.primary,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    for (
                                      var index = 0;
                                      index < distribution.buckets.length;
                                      index++
                                    )
                                      SizedBox(
                                        width: barWidth + 10,
                                        child: Center(
                                          child: Text(
                                            _shouldShowDistributionLabel(
                                                  index,
                                                  distribution.buckets.length,
                                                )
                                                ? distribution
                                                    .buckets[index]
                                                    .label
                                                : '',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelSmall?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionCalendarOverview(
    ReadingCalendarDistribution distribution, {
    bool embeddedInSheet = false,
    String title = '阅读时间分布',
    String subtitle = '缩略查看相邻 3 个月的阅读分布。',
  }) {
    if (distribution.months.isEmpty) {
      return _buildEmptyCard('当前周期下还没有可以展示的阅读时间分布。');
    }

    final colorScheme = Theme.of(context).colorScheme;
    const weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

    return Container(
      decoration: BoxDecoration(
        color:
            embeddedInSheet
                ? colorScheme.surfaceContainerLowest
                : colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (
                    var index = 0;
                    index < distribution.months.length;
                    index++
                  )
                    Padding(
                      padding: EdgeInsets.only(
                        right: index == distribution.months.length - 1 ? 0 : 12,
                      ),
                      child: _buildDistributionMonthMiniCard(
                        distribution.months[index],
                        weekLabels: weekLabels,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingCalendarCard(
    ReadingCalendarDistribution distribution, {
    required List<ReadingRecordDay> dailyRecords,
    required List<ReadingRecordSession> sessions,
  }) {
    if (distribution.months.length < 2) {
      return _buildEmptyCard('当前月份还没有可以展示的阅读日历。');
    }

    final month = distribution.months[1];
    final currentMonthDays = <DateTime>[
      for (final week in month.weeks)
        for (final day in week.days)
          if (day.isInCurrentMonth) day.day,
    ];
    if (currentMonthDays.isEmpty) {
      return _buildEmptyCard('当前月份还没有可以展示的阅读日历。');
    }

    final allowedDateKeys = currentMonthDays.map(_dateKeyFor).toSet();
    final detailsByDate = _buildReadingCalendarDetailsByDate(
      allowedDateKeys: allowedDateKeys,
      dailyRecords: dailyRecords,
      sessions: sessions,
    );
    final selectedDate = _resolveReadingCalendarSelectedDate(
      currentMonthDays: currentMonthDays,
      detailsByDate: detailsByDate,
    );
    final selectedKey = _dateKeyFor(selectedDate);
    final selectedDetail = detailsByDate[selectedKey];
    const weekLabels = ['一', '二', '三', '四', '五', '六', '日'];
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '阅读日历',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${month.monthLabel} · 查看当月每天的阅读分布与摘要',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final label in weekLabels)
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final week in month.weeks)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    for (final day in week.days)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _buildReadingCalendarDayCell(
                            day: day,
                            detail: detailsByDate[_dateKeyFor(day.day)],
                            selected:
                                day.isInCurrentMonth &&
                                _dateKeyFor(day.day) == selectedKey,
                            onTap:
                                day.isInCurrentMonth
                                    ? () {
                                      setState(() {
                                        _selectedCalendarDate = day.day;
                                      });
                                    }
                                    : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            _buildReadingCalendarDetailCard(
              date: selectedDate,
              detail: selectedDetail,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyActivityCard({
    required ReadingRecordsPeriodRange periodRange,
    required List<ReadingRecordDay> dailyRecords,
    required List<ReadingRecordSession> sessions,
  }) {
    final start = periodRange.start;
    final endExclusive = periodRange.endExclusive;
    if (start == null || endExclusive == null) {
      return _buildEmptyCard('当前周期下还没有可以展示的周活跃度。');
    }

    final weekDays = <DateTime>[
      for (var offset = 0; offset < 7; offset += 1)
        start.add(Duration(days: offset)),
    ];
    final allowedDateKeys = weekDays.map(_dateKeyFor).toSet();
    final detailsByDate = _buildReadingCalendarDetailsByDate(
      allowedDateKeys: allowedDateKeys,
      dailyRecords: dailyRecords,
      sessions: sessions,
    );
    final selectedDate = _resolveReadingCalendarSelectedDate(
      currentMonthDays: weekDays,
      detailsByDate: detailsByDate,
    );
    final selectedKey = _dateKeyFor(selectedDate);
    final selectedDetail = detailsByDate[selectedKey];
    const weekLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '周活跃度',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${periodRange.label} · 查看本周每天的阅读活跃分布与摘要',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var index = 0; index < weekLabels.length; index += 1)
                  Expanded(
                    child: Center(
                      child: Text(
                        weekLabels[index],
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final day in weekDays)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _buildReadingCalendarDayCell(
                        day: ReadingCalendarDistributionDay(
                          day: day,
                          isInCurrentMonth: true,
                          readMillis:
                              detailsByDate[_dateKeyFor(day)]?.readMillis ?? 0,
                        ),
                        detail: detailsByDate[_dateKeyFor(day)],
                        selected: _dateKeyFor(day) == selectedKey,
                        onTap: () {
                          setState(() {
                            _selectedCalendarDate = day;
                          });
                        },
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildReadingCalendarDetailCard(
              date: selectedDate,
              detail: selectedDetail,
            ),
          ],
        ),
      ),
    );
  }

  Map<String, _ReadingCalendarDayDetail> _buildReadingCalendarDetailsByDate({
    required Set<String> allowedDateKeys,
    required List<ReadingRecordDay> dailyRecords,
    required List<ReadingRecordSession> sessions,
  }) {
    final details = _statsPresenter.buildCalendarDetailsByDate(
      allowedDateKeys: allowedDateKeys,
      dailyRecords: dailyRecords,
      sessions: sessions,
    );
    return <String, _ReadingCalendarDayDetail>{
      for (final entry in details.entries)
        entry.key: _ReadingCalendarDayDetail(
          dateKey: entry.value.dateKey,
          readMillis: entry.value.readMillis,
          readChars: entry.value.readChars,
          sessionCount: entry.value.sessionCount,
          workCount: entry.value.workCount,
          books: entry.value.books
              .map(
                (item) => _ReadingCalendarBookDetail(
                  bookId: item.bookId,
                  title: item.title,
                  author: item.author,
                  coverUrl: item.coverUrl,
                  readMillis: item.readMillis,
                  readChars: item.readChars,
                  chapterTitle: item.chapterTitle,
                ),
              )
              .toList(growable: false),
        ),
    };
  }

  DateTime _resolveReadingCalendarSelectedDate({
    required List<DateTime> currentMonthDays,
    required Map<String, _ReadingCalendarDayDetail> detailsByDate,
  }) {
    final detailMap = <String, ReadingCalendarDayDetail>{
      for (final entry in detailsByDate.entries)
        entry.key: ReadingCalendarDayDetail(
          dateKey: entry.value.dateKey,
          readMillis: entry.value.readMillis,
          readChars: entry.value.readChars,
          sessionCount: entry.value.sessionCount,
          workCount: entry.value.workCount,
          books: entry.value.books
              .map(
                (item) => ReadingCalendarBookDetail(
                  bookId: item.bookId,
                  title: item.title,
                  author: item.author,
                  coverUrl: item.coverUrl,
                  readMillis: item.readMillis,
                  readChars: item.readChars,
                  chapterTitle: item.chapterTitle,
                ),
              )
              .toList(growable: false),
        ),
    };
    return _statsPresenter.resolveSelectedCalendarDate(
      candidateDays: currentMonthDays,
      detailsByDate: detailMap,
      selectedDate: _selectedCalendarDate,
    );
  }

  Widget _buildReadingCalendarDayCell({
    required ReadingCalendarDistributionDay day,
    required _ReadingCalendarDayDetail? detail,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasReading = (detail?.readMillis ?? 0) > 0;
    final backgroundColor =
        !day.isInCurrentMonth
            ? colorScheme.surfaceContainerLowest
            : hasReading
            ? colorScheme.primary.withValues(
              alpha: selected ? 0.2 : _readingCalendarFillOpacity(detail!),
            )
            : colorScheme.surfaceContainerLow;
    final foregroundColor =
        hasReading ? colorScheme.primary : colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: 62,
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withValues(alpha: 0.22),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Text(
                  '${day.day.day}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color:
                        day.isInCurrentMonth
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.45,
                            ),
                    fontWeight: hasReading ? FontWeight.w800 : FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child:
                    hasReading
                        ? Center(
                          child: Text(
                            _buildReadingCalendarBookSummary(detail!),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              color: colorScheme.onSurfaceVariant,
                              height: 1.15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                        : const SizedBox.shrink(),
              ),
              if (hasReading)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    _formatCompactDuration(detail!.readMillis),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: foregroundColor,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildReadingCalendarBookSummary(_ReadingCalendarDayDetail detail) {
    if (detail.books.isEmpty) {
      return detail.workCount > 1 ? '${detail.workCount}本书' : '1本书';
    }
    if (detail.workCount > 1) {
      return '${detail.workCount}本书';
    }
    return detail.books.first.title.trim();
  }

  double _readingCalendarFillOpacity(_ReadingCalendarDayDetail detail) {
    final minutes = detail.readMillis / Duration.millisecondsPerMinute;
    if (minutes >= 120) {
      return 0.34;
    }
    if (minutes >= 60) {
      return 0.26;
    }
    if (minutes >= 20) {
      return 0.18;
    }
    return 0.12;
  }

  Widget _buildReadingCalendarDetailCard({
    required DateTime date,
    required _ReadingCalendarDayDetail? detail,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateLabel = _formatCalendarDate(date);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (detail != null && detail.readMillis > 0)
                Text(
                  _formatDuration(detail.readMillis),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (detail == null || detail.readMillis <= 0)
            Text(
              '这一天还没有阅读记录。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCalendarDetailChip(
                  context,
                  icon: Icons.auto_stories_rounded,
                  text: '${detail.workCount} 本',
                ),
                _buildCalendarDetailChip(
                  context,
                  icon: Icons.schedule_rounded,
                  text: '${detail.sessionCount} 段',
                ),
                _buildCalendarDetailChip(
                  context,
                  icon: Icons.text_fields_rounded,
                  text: '${_formatReadChars(detail.readChars)} 字',
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final book in detail.books.take(3))
              Builder(
                builder: (context) {
                  final presentation = _resolvePresentation(
                    bookId: book.bookId,
                    sourceId: null,
                    detailUrl: null,
                    title: book.title,
                    author: book.author,
                    coverUrl: book.coverUrl,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCover(
                          realCoverUrl: presentation.realCoverUrl,
                          title: presentation.displayTitle,
                          author: presentation.displayAuthor,
                          bookId: book.bookId,
                          width: 28,
                          height: 40,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                presentation.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                book.chapterTitle?.trim().isNotEmpty == true
                                    ? '${_formatDuration(book.readMillis)} · ${book.chapterTitle}'
                                    : _formatDuration(book.readMillis),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarDetailChip(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionMonthMiniCard(
    ReadingCalendarDistributionMonth month, {
    required List<String> weekLabels,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 148,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            month.monthLabel,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final label in weekLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (final week in month.weeks)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  for (final day in week.days)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: _buildDistributionCalendarCell(
                          day,
                          compact: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _shouldShowDistributionLabel(int index, int totalCount) {
    if (_period == ReadingRecordsPeriod.month) {
      final dayNumber = index + 1;
      return dayNumber == 1 ||
          (dayNumber - 1) % 5 == 0 ||
          dayNumber == totalCount;
    }
    if (totalCount <= 7) {
      return true;
    }
    if (totalCount <= 12) {
      return index.isEven || index == totalCount - 1;
    }
    if (totalCount <= 24) {
      return index % 3 == 0 || index == totalCount - 1;
    }
    return index == 0 || index % 5 == 0 || index == totalCount - 1;
  }

  String _formatDistributionAxisValue(int millis) {
    if (millis <= 0) {
      return '0';
    }
    final minutes = millis ~/ Duration.millisecondsPerMinute;
    if (minutes < 60) {
      return '$minutes分';
    }
    final hours = minutes / 60;
    return hours >= 10
        ? '${hours.toStringAsFixed(0)}时'
        : '${hours.toStringAsFixed(1)}时';
  }

  Widget _buildDurationRankingSection(
    List<ReadingDurationRankingItem> rankings,
  ) {
    if (rankings.isEmpty) {
      return _buildEmptyCard('当前周期下还没有阅读时长排行。');
    }

    final colorScheme = Theme.of(context).colorScheme;
    final visibleItems = rankings.take(5).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeading('阅读时长排行榜', subtitle: '按当前周期阅读时长排序'),
        for (var index = 0; index < visibleItems.length; index++) ...[
          Builder(
            builder: (context) {
              final item = visibleItems[index];
              final presentation = _presentationService
                  .resolveRecordDisplayState(
                    record: item.record,
                    localBooksById: _localBooksById,
                    metadataOverridesByTargetKey: _metadataOverridesByTargetKey,
                  );
              return _buildRecordSurface(
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _openRecord(item.record),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(11, 9, 10, 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${index + 1}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildCover(
                          realCoverUrl: presentation.realCoverUrl,
                          title: presentation.displayTitle,
                          author: presentation.displayAuthor,
                          bookId: item.record.bookId,
                          sourceId: item.record.sourceId,
                          detailUrl: item.record.detailUrl,
                          width: 42,
                          height: 58,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                presentation.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '阅读字数 ${_formatReadChars(item.readChars)}'
                                '${item.readDays > 0 ? ' · ${item.readDays} 天' : ''}',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(item.readMillis),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (index < visibleItems.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildDistributionCalendarCell(
    ReadingCalendarDistributionDay day, {
    bool compact = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected =
        _period == ReadingRecordsPeriod.day &&
        _dateKeyFor(_periodAnchor) == day.dateKey;
    final backgroundColor =
        !day.isInCurrentMonth
            ? colorScheme.surfaceContainerLowest
            : day.hasReading
            ? Colors.red.shade500.withValues(
              alpha:
                  day.readMillis >= Duration.millisecondsPerHour ? 0.95 : 0.72,
            )
            : colorScheme.surfaceContainerLow;
    final foregroundColor =
        !day.isInCurrentMonth
            ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
            : day.hasReading
            ? Colors.white
            : colorScheme.onSurface;

    return Tooltip(
      message:
          day.hasReading
              ? '${day.dateKey}\n${_formatDuration(day.readMillis)}'
              : '${day.dateKey}\n无阅读记录',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap:
            day.isInCurrentMonth
                ? () => _setPeriod(ReadingRecordsPeriod.day, anchor: day.day)
                : null,
        child: AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(compact ? 6 : 10),
              border:
                  isSelected
                      ? Border.all(color: colorScheme.onSurface, width: 2)
                      : Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.24,
                        ),
                      ),
            ),
            child: Center(
              child: Text(
                '${day.day.day}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight:
                      day.hasReading ? FontWeight.w700 : FontWeight.w500,
                  fontSize: compact ? 10 : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _heatmapRangeLabel {
    return switch (_heatmapRangeMode) {
      _HeatmapRangeMode.threeMonths => '近 3 个月',
      _HeatmapRangeMode.sixMonths => '近 6 个月',
      _HeatmapRangeMode.oneYear => '近 1 年',
      _HeatmapRangeMode.all => '全部',
    };
  }

  Widget _buildHeatmapMenu<T>({
    required IconData icon,
    required String label,
    required List<PopupMenuEntry<T>> items,
    required ValueChanged<T> onSelected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuButton<T>(
      itemBuilder: (context) => items,
      onSelected: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.32),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarlierDataPlaceholderColumn() {
    return Column(
      children: List<Widget>.generate(7, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == 6 ? 0 : 4),
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildEarlierDataHint() {
    final characters = '更早数据已折叠'.split('');
    return SizedBox(
      width: 22,
      child: Padding(
        padding: const EdgeInsets.only(top: 2, left: 2),
        child: Column(
          children: [
            for (var index = 0; index < characters.length; index++) ...[
              Text(
                characters[index],
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              if (index < characters.length - 1) const SizedBox(height: 2),
            ],
          ],
        ),
      ),
    );
  }

  double _heatmapLeadingAreaWidth(bool showEarlierDataIndicator) {
    const weekdayLabelWidth = 18.0;
    const gapAfterWeekdayLabels = 12.0;
    if (!showEarlierDataIndicator) {
      return weekdayLabelWidth + gapAfterWeekdayLabels;
    }
    const placeholderWidth = 14.0;
    const gapBetweenPlaceholderAndHint = 8.0;
    const hintWidth = 22.0;
    const gapBeforeHeatmap = 12.0;
    return weekdayLabelWidth +
        gapAfterWeekdayLabels +
        placeholderWidth +
        gapBetweenPlaceholderAndHint +
        hintWidth +
        gapBeforeHeatmap;
  }

  double get _heatmapWeekColumnWidth => _kHeatmapCellSize;

  Widget _buildHeatmapCell({
    required DateTime day,
    required DailyHeatmapStat? stats,
    required int maxValue,
  }) {
    final dateKey = _dateKeyFor(day);
    final value = stats?.readMillis ?? 0;
    final normalized = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    final isSelected =
        _period == ReadingRecordsPeriod.day &&
        _dateKeyFor(_periodAnchor) == dateKey;
    final colorScheme = Theme.of(context).colorScheme;
    final fillColor =
        value <= 0
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primary.withValues(alpha: 0.18 + (normalized * 0.72));

    final tooltip =
        stats == null
            ? '$dateKey\n无阅读记录'
            : '$dateKey\n${stats.workCount} 本 · ${stats.sessionCount} 段 · ${_formatDuration(stats.readMillis)}';

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: () {
          final isSameSelectedDay =
              _period == ReadingRecordsPeriod.day &&
              _dateKeyFor(_periodAnchor) == dateKey;
          if (isSameSelectedDay) {
            _setPeriod(ReadingRecordsPeriod.all);
          } else {
            _setPeriod(ReadingRecordsPeriod.day, anchor: day);
          }
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(5),
            border:
                isSelected
                    ? Border.all(color: colorScheme.onSurface, width: 2)
                    : Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.18),
                    ),
          ),
          child: const SizedBox(
            width: _kHeatmapCellSize,
            height: _kHeatmapCellSize,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({required ReadingRecordsSummary summary}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.5),
            Theme.of(context).colorScheme.surfaceContainerLow,
            Theme.of(context).colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        summary.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (summary.coverRecords.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  _buildSummaryCoverStack(summary.coverRecords),
                ],
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final columns = AppLayout.readingRecordsMetricColumnsForWidth(
                  maxWidth,
                );
                final spacing = 8.0;
                final tileWidth = ((maxWidth - (spacing * (columns - 1))) /
                        columns)
                    .clamp(120.0, 220.0);

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    SizedBox(
                      width: tileWidth,
                      child: _buildMetricTile(
                        icon: Icons.auto_stories_rounded,
                        label: '阅读时长',
                        value: _formatDuration(summary.totalReadMillis),
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _buildMetricTile(
                        icon: Icons.calendar_month_rounded,
                        label: '阅读天数',
                        value: '${summary.totalDays} 天',
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _buildMetricTile(
                        icon: Icons.text_fields_rounded,
                        label: '阅读字数',
                        value: _formatReadChars(summary.totalReadChars),
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _buildMetricTile(
                        icon: Icons.speed_rounded,
                        label: '阅读速度',
                        value: _formatReadSpeed(summary.readCharsPerMinute),
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _buildMetricTile(
                        icon: Icons.import_contacts_rounded,
                        label: '在读书籍',
                        value: '${summary.readingBookCount} 本',
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _buildMetricTile(
                        icon: Icons.task_alt_rounded,
                        label: '读完书籍',
                        value: '${summary.completedBookCount} 本',
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _buildMetricTile(
                        icon: Icons.menu_book_rounded,
                        label: '累计读过',
                        value: '${summary.totalBooks} 本',
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _buildMetricTile(
                        icon: Icons.bookmarks_outlined,
                        label: '触达章节',
                        value: '${summary.chapterCount} 章',
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeading(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordSurface(Widget child) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: child,
    );
  }

  Widget _buildEmptyCard(String message) {
    return AppEmptyStateCard(
      icon: Icons.insights_rounded,
      title: '暂无统计数据',
      description: message,
      compact: true,
    );
  }

  Widget _buildSummaryCoverStack(List<ReadingRecord> records) {
    final visible = records.take(3).toList(growable: false);
    return SizedBox(
      width: 86,
      height: 78,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * 18,
              top: index * 4,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(10),
                child: _buildCover(
                  realCoverUrl: visible[index].coverUrl,
                  title: visible[index].bookTitle,
                  author: visible[index].bookAuthor,
                  bookId: visible[index].bookId,
                  sourceId: visible[index].sourceId,
                  detailUrl: visible[index].detailUrl,
                  width: 44,
                  height: 62,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCover({
    String? realCoverUrl,
    String? title,
    String? author,
    String? bookId,
    String? sourceId,
    String? detailUrl,
    double width = 54,
    double height = 74,
  }) {
    final presentation = _resolvePresentation(
      bookId: bookId ?? '',
      sourceId: sourceId,
      detailUrl: detailUrl,
      title: title,
      author: author,
      coverUrl: realCoverUrl,
    );
    return Consumer(
      builder: (context, ref, _) {
        final resolvedCover = resolveBookCover(
          realCoverUrl: presentation.displayCover,
          activeTheme: ref.watch(activeAdvancedThemeProvider).valueOrNull,
          galleries: ref.watch(coverGalleriesProvider).valueOrNull ?? const [],
          brightness: Theme.of(context).brightness,
          bookId: bookId,
          sourceId: sourceId,
          detailUrl: detailUrl,
        );
        return ResolvedBookCoverView(
          cover: resolvedCover,
          title: presentation.displayTitle,
          author: presentation.displayAuthor,
          width: width,
          height: height,
          borderRadius: BorderRadius.circular(10),
        );
      },
    );
  }

  BookDisplayState _resolvePresentation({
    required String bookId,
    required String? sourceId,
    required String? detailUrl,
    required String? title,
    String? author,
    String? intro,
    String? coverUrl,
  }) {
    return _presentationService.resolveSnapshotDisplayState(
      bookId: bookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
      title: title,
      author: author,
      intro: intro,
      coverUrl: coverUrl,
      localBooksById: _localBooksById,
      metadataOverridesByTargetKey: _metadataOverridesByTargetKey,
    );
  }

  DateTime _resolveHeatmapStartDate({
    required DateTime firstDate,
    required DateTime today,
  }) {
    final safeFirstDate = _stripDate(firstDate);
    final safeToday = _stripDate(today);
    return switch (_heatmapRangeMode) {
      _HeatmapRangeMode.threeMonths => _startOfWeek(
        safeToday.subtract(const Duration(days: 89)),
      ),
      _HeatmapRangeMode.sixMonths => _startOfWeek(
        safeToday.subtract(const Duration(days: 179)),
      ),
      _HeatmapRangeMode.oneYear => _startOfWeek(
        safeToday.subtract(const Duration(days: 364)),
      ),
      _HeatmapRangeMode.all => _startOfWeek(safeFirstDate),
    };
  }

  List<String> _buildHeatmapMonthLabels(List<List<DateTime>> weeks) {
    final labels = <String>[];
    DateTime? previousMonth;
    for (final week in weeks) {
      DateTime? weekMonth;
      for (final day in week) {
        if (day.day == 1) {
          weekMonth = DateTime(day.year, day.month);
          break;
        }
      }
      weekMonth ??= DateTime(week.first.year, week.first.month);
      if (previousMonth == null ||
          previousMonth.year != weekMonth.year ||
          previousMonth.month != weekMonth.month) {
        labels.add('${weekMonth.month}月');
        previousMonth = weekMonth;
      } else {
        labels.add('');
      }
    }
    return labels;
  }

  List<List<DateTime>> _buildHeatmapWeeks({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final weeks = <List<DateTime>>[];
    var cursor = startDate;
    while (!cursor.isAfter(endDate)) {
      weeks.add(
        List<DateTime>.generate(
          7,
          (index) => cursor.add(Duration(days: index)),
        ),
      );
      cursor = cursor.add(const Duration(days: 7));
    }
    return weeks;
  }

  DateTime _stripDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = _stripDate(date);
    final offset = normalized.weekday - DateTime.monday;
    return normalized.subtract(Duration(days: offset));
  }

  AppNavigationStyle _resolveEffectiveNavigationStyle() {
    return resolveAppNavigationStyle(
      ref.read(appNavigationStylePreferenceProvider),
      isWeb: false,
      platform: Theme.of(context).platform,
    );
  }

  String _formatDuration(int millis) {
    final safeMillis = millis < 0 ? 0 : millis;
    final minutes = safeMillis ~/ Duration.millisecondsPerMinute;
    if (minutes < 60) {
      return '$minutes 分钟';
    }
    final hours = minutes ~/ 60;
    final remainMinutes = minutes % 60;
    return remainMinutes == 0 ? '$hours 小时' : '$hours 小时 $remainMinutes 分钟';
  }

  String _formatReadChars(int chars) {
    final safe = chars < 0 ? 0 : chars;
    if (safe < 10000) {
      return '$safe';
    }
    final value = safe / 10000;
    return value >= 10
        ? '${value.toStringAsFixed(0)} 万'
        : '${value.toStringAsFixed(1)} 万';
  }

  String _formatReadSpeed(double charsPerMinute) {
    if (charsPerMinute <= 0) {
      return '0 字/分';
    }
    if (charsPerMinute < 10) {
      return '${charsPerMinute.toStringAsFixed(1)} 字/分';
    }
    return '${charsPerMinute.round()} 字/分';
  }

  String _formatCompactDuration(int millis) {
    final safeMillis = millis < 0 ? 0 : millis;
    final minutes = safeMillis ~/ Duration.millisecondsPerMinute;
    if (minutes < 60) {
      return '$minutes分';
    }
    final hours = minutes / 60;
    return hours >= 10
        ? '${hours.toStringAsFixed(0)}时'
        : '${hours.toStringAsFixed(1)}时';
  }

  String _formatCalendarDate(DateTime time) {
    const weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];
    final local = time.toLocal();
    return '${local.month}月${local.day}日 周${weekdayLabels[local.weekday - 1]}';
  }

  String _dateKeyFor(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

class _ReadingCalendarDayDetail {
  const _ReadingCalendarDayDetail({
    required this.dateKey,
    required this.readMillis,
    required this.readChars,
    required this.sessionCount,
    required this.workCount,
    required this.books,
  });

  final String dateKey;
  final int readMillis;
  final int readChars;
  final int sessionCount;
  final int workCount;
  final List<_ReadingCalendarBookDetail> books;
}

class _ReadingCalendarBookDetail {
  const _ReadingCalendarBookDetail({
    required this.bookId,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.readMillis,
    required this.readChars,
    required this.chapterTitle,
  });

  final String bookId;
  final String title;
  final String? author;
  final String? coverUrl;
  final int readMillis;
  final int readChars;
  final String? chapterTitle;
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 14,
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

class _DashedHorizontalLine extends StatelessWidget {
  const _DashedHorizontalLine({
    required this.color,
    this.dashWidth = 6,
    this.gapWidth = 4,
    this.strokeWidth = 1,
    this.height = 1,
  });

  final Color color;
  final double dashWidth;
  final double gapWidth;
  final double strokeWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _DashedHorizontalLinePainter(
          color: color,
          dashWidth: dashWidth,
          gapWidth: gapWidth,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _DashedHorizontalLinePainter extends CustomPainter {
  const _DashedHorizontalLinePainter({
    required this.color,
    required this.dashWidth,
    required this.gapWidth,
    required this.strokeWidth,
  });

  final Color color;
  final double dashWidth;
  final double gapWidth;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final y = size.height / 2;
    double x = 0;
    while (x < size.width) {
      final end = math.min(x + dashWidth, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x = end + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedHorizontalLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.gapWidth != gapWidth ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
