import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/navigation/app_navigation_style_provider.dart';
import '../../../app/navigation/mobile_bottom_navigation_inset.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reading_record_day.dart';
import '../application/home_engagement_service.dart';
import '../../book/application/book_metadata_presentation_resolver.dart';
import '../../mine/application/advanced_theme_provider.dart';
import '../../mine/application/cover_gallery_provider.dart';
import '../../reader/application/reader_entry_route_resolver.dart';
import '../../reader/application/reader_preferences_service.dart';
import '../../reader/application/reading_record_service.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({
    super.key,
    ReadingRecordService? readingRecordService,
    ReaderPreferencesService? preferencesService,
    HomeEngagementService? engagementService,
  }) : _readingRecordService = readingRecordService,
       _preferencesService = preferencesService,
       _engagementService = engagementService;

  final ReadingRecordService? _readingRecordService;
  final ReaderPreferencesService? _preferencesService;
  final HomeEngagementService? _engagementService;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with AutomaticKeepAliveClientMixin<HomePage> {
  static const double _kContinueReadingCardWidth = 104;
  static const double _kContinueReadingCardHeight = 184;
  static const double _kContinueReadingCardCoverSize = 86;

  late final ReadingRecordService _readingRecordService;
  late final ReaderPreferencesService _preferencesService;
  late final HomeEngagementService _engagementService;
  final ReaderEntryRouteResolver _readerEntryRouteResolver =
      const ReaderEntryRouteResolver();
  final BookDisplayStateResolver _bookPresentationResolver =
      const BookDisplayStateResolver();

  HomeEngagementState _engagementState = const HomeEngagementState();
  bool _isEngagementLoading = true;
  bool _isSubmittingCheckIn = false;
  _RankingDimension _selectedRankingDimension = _RankingDimension.hot;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _readingRecordService =
        widget._readingRecordService ?? ReadingRecordService();
    _preferencesService =
        widget._preferencesService ?? ReaderPreferencesService();
    _engagementService = widget._engagementService ?? HomeEngagementService();
    unawaited(_loadEngagementState());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.watch(activeAdvancedThemeProvider);
    final backdrop = resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      ref.watch(activeAdvancedThemeProvider).valueOrNull,
    );
    final platform = Theme.of(context).platform;
    final navigationStyle = resolveAppNavigationStyle(
      ref.watch(appNavigationStylePreferenceProvider),
      isWeb: false,
      platform: platform,
    );
    final showLabels = ref.watch(appNavigationLabelVisibilityProvider);
    final standardNavigationAppearance = ref.watch(
      appStandardNavigationBarAppearanceProvider,
    );
    final bottomInset = mobileBottomNavigationBodyInset(
      context,
      style: navigationStyle,
      showNavigationLabels: showLabels,
      standardAppearance: standardNavigationAppearance,
    );
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final metrics = AppAdaptiveMetrics.of(context);
    final desktopLike = AppLayout.isMediumUp(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('首页'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      body: DecoratedBox(
        decoration: buildAdvancedThemeBackdropDecoration(backdrop),
        child: SizedBox.expand(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AppLayout.pageContentMaxWidth(
                    context,
                    maxWidth: 980,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    metrics.pagePadding,
                    topInset + metrics.contentGap,
                    metrics.pagePadding,
                    bottomInset + metrics.sectionGap,
                  ),
                  child:
                      desktopLike
                          ? _buildDesktopDashboard(context)
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppFadeSlideTransition(
                                child: _buildReadingSummarySection(),
                              ),
                              SizedBox(height: metrics.sectionGap),
                              AppFadeSlideTransition(
                                delay: const Duration(milliseconds: 56),
                                child: _buildSectionHeader(
                                  context,
                                  title: '继续阅读',
                                  actionLabel: '查看统计',
                                  onAction: () => context.push('/stats'),
                                ),
                              ),
                              SizedBox(height: metrics.contentGap),
                              AppFadeSlideTransition(
                                delay: const Duration(milliseconds: 84),
                                child: _buildContinueReadingSectionBlock(),
                              ),
                              SizedBox(height: metrics.sectionGap),
                              AppFadeSlideTransition(
                                delay: const Duration(milliseconds: 112),
                                child: _buildSectionHeader(
                                  context,
                                  title: '排行',
                                ),
                              ),
                              SizedBox(height: metrics.contentGap),
                              AppFadeSlideTransition(
                                delay: const Duration(milliseconds: 140),
                                child: _buildRankingPreviewSection(context),
                              ),
                            ],
                          ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopDashboard(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFadeSlideTransition(child: _buildDesktopOverviewToolbar(context)),
        SizedBox(height: metrics.sectionGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppFadeSlideTransition(
                    delay: const Duration(milliseconds: 56),
                    child: _buildSectionHeader(
                      context,
                      title: '继续阅读',
                      actionLabel: '查看统计',
                      onAction: () => context.push('/stats'),
                    ),
                  ),
                  SizedBox(height: metrics.contentGap),
                  AppFadeSlideTransition(
                    delay: const Duration(milliseconds: 84),
                    child: _buildContinueReadingSectionBlock(),
                  ),
                  SizedBox(height: metrics.sectionGap),
                  AppFadeSlideTransition(
                    delay: const Duration(milliseconds: 112),
                    child: _buildSectionHeader(context, title: '排行'),
                  ),
                  SizedBox(height: metrics.contentGap),
                  AppFadeSlideTransition(
                    delay: const Duration(milliseconds: 140),
                    child: _buildRankingPreviewSection(context),
                  ),
                ],
              ),
            ),
            SizedBox(width: metrics.sectionGap),
            Expanded(
              flex: 4,
              child: AppFadeSlideTransition(
                delay: const Duration(milliseconds: 96),
                child: _buildReadingSummarySection(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopOverviewToolbar(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return _buildSurface(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: metrics.cardPadding + 2,
          vertical: metrics.cardPadding,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '阅读概览',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: () => context.go('/bookshelf'),
              icon: const Icon(Icons.library_books_outlined),
              label: const Text('书架'),
            ),
            SizedBox(width: metrics.contentGap * 0.6),
            FilledButton.icon(
              onPressed: () => context.push('/stats'),
              icon: const Icon(Icons.query_stats_rounded),
              label: const Text('阅读统计'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onSurface,
                foregroundColor: colorScheme.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingSummarySection() {
    return StreamBuilder<List<ReadingRecord>>(
      stream: _readingRecordService.watchLatestRecords(),
      builder: (context, recordsSnapshot) {
        final records = recordsSnapshot.data ?? const <ReadingRecord>[];
        return StreamBuilder<List<ReadingRecordDay>>(
          stream: _readingRecordService.watchDailyRecords(),
          builder: (context, daysSnapshot) {
            final dailyRecords =
                daysSnapshot.data ?? const <ReadingRecordDay>[];
            final summary = _buildSummary(
              records: records,
              dailyRecords: dailyRecords,
            );
            return AppAnimatedSwitcher(
              child: Column(
                key: ValueKey<String>(
                  'home_summary_${records.length}_${dailyRecords.length}',
                ),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCheckInCard(summary),
                  SizedBox(height: AppAdaptiveMetrics.of(context).sectionGap),
                  _buildGoalCard(summary, records),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContinueReadingSectionBlock() {
    return StreamBuilder<List<ReadingRecord>>(
      stream: _readingRecordService.watchLatestRecords(),
      builder: (context, snapshot) {
        final records = snapshot.data ?? const <ReadingRecord>[];
        return AppAnimatedSwitcher(
          child: KeyedSubtree(
            key: ValueKey<String>('continue_reading_${records.length}'),
            child: _buildContinueReadingSection(records),
          ),
        );
      },
    );
  }

  Widget _buildCheckInCard(_HomeReadingSummary summary) {
    final colorScheme = Theme.of(context).colorScheme;
    final checkedInToday = _engagementState.isCheckedInOn(DateTime.now());
    final streakDays = _engagementState.streakDays();
    final weekCheckInCount = _engagementState.recentCheckInCount(7);
    final metrics = AppAdaptiveMetrics.of(context);

    return _buildSurface(
      child: Padding(
        padding: EdgeInsets.all(metrics.cardPadding + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.86),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    checkedInToday
                        ? Icons.check_rounded
                        : Icons.check_circle_outline_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkedInToday ? '今日已打卡' : '今日未打卡',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: metrics.contentGap),
            Row(
              children: [
                Expanded(
                  child: _MetricPill(label: '连续打卡', value: '$streakDays 天'),
                ),
                SizedBox(width: metrics.contentGap),
                Expanded(
                  child: _MetricPill(
                    label: '本周打卡',
                    value: '$weekCheckInCount / 7',
                  ),
                ),
                SizedBox(width: metrics.contentGap),
                Expanded(
                  child: _MetricPill(
                    label: '今日阅读',
                    value: _formatMinutes(summary.todayReadMillis),
                  ),
                ),
              ],
            ),
            SizedBox(height: metrics.contentGap),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    _isEngagementLoading ||
                            _isSubmittingCheckIn ||
                            checkedInToday
                        ? null
                        : _handleCheckInToday,
                style: FilledButton.styleFrom(
                  minimumSize: Size.fromHeight(
                    metrics.isCompactDensity ? 44 : 52,
                  ),
                  shape: const StadiumBorder(),
                  backgroundColor:
                      checkedInToday
                          ? colorScheme.surfaceContainerHighest
                          : colorScheme.onSurface,
                  foregroundColor:
                      checkedInToday
                          ? colorScheme.onSurface
                          : colorScheme.surface,
                ),
                child:
                    _isSubmittingCheckIn
                        ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color:
                                checkedInToday
                                    ? colorScheme.onSurface
                                    : colorScheme.surface,
                          ),
                        )
                        : Text(
                          checkedInToday
                              ? '今日已打卡'
                              : (_isEngagementLoading ? '加载中...' : '今日打卡'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(
    _HomeReadingSummary summary,
    List<ReadingRecord> records,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final goalMinutes = _engagementState.dailyGoalMinutes;
    final goalMillis = goalMinutes * Duration.millisecondsPerMinute;
    final progress =
        goalMillis <= 0
            ? 0.0
            : (summary.todayReadMillis / goalMillis).clamp(0.0, 1.0);
    final metrics = AppAdaptiveMetrics.of(context);
    final chartHeight = metrics.isCompactDensity ? 250.0 : 294.0;
    final arcHeight = metrics.isCompactDensity ? 192.0 : 230.0;

    const primaryActionLabel = '探索书架';

    return _buildSurface(
      child: Padding(
        padding: EdgeInsets.all(metrics.cardPadding + 2),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = math.min(constraints.maxWidth - 8, 320.0);
            return Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: Text(
                          '阅读目标',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: _buildSectionIconButton(
                          context,
                          icon: Icons.tune_rounded,
                          tooltip: '设置阅读目标',
                          onTap: _showGoalSettingsSheet,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: metrics.contentGap),
                Text(
                  '找一本好书，设定一个目标，养成每天阅读的习惯。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                SizedBox(height: metrics.contentGap * 0.2),
                SizedBox(
                  width: contentWidth,
                  height: chartHeight,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: metrics.isCompactDensity ? 34 : 36,
                        child: SizedBox(
                          height: arcHeight,
                          child: ClipRect(
                            child: CustomPaint(
                              painter: _ReadingGoalArcPainter(
                                progress: progress,
                                trackColor: colorScheme.outlineVariant
                                    .withValues(alpha: 0.16),
                                progressColor: const Color(0xFF8BC0FF),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: metrics.isCompactDensity ? 58 : 66,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '今日阅读进度',
                              textAlign: TextAlign.center,
                              style: Theme.of(
                                context,
                              ).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: metrics.isCompactDensity ? 14 : 15,
                                letterSpacing: 0,
                                height: 1.0,
                              ),
                            ),
                            SizedBox(height: metrics.contentGap * 0.6),
                            Text(
                              _formatGoalClock(summary.todayReadMillis),
                              textAlign: TextAlign.center,
                              style: Theme.of(
                                context,
                              ).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w400,
                                fontSize: metrics.isCompactDensity ? 26 : 30,
                                letterSpacing: 0,
                                height: 0.9,
                              ),
                            ),
                            SizedBox(height: metrics.contentGap * 0.4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '（目标 ${_formatGoalTarget(goalMinutes)}）',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 1),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: colorScheme.outlineVariant,
                                  size: 18,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Align(
                          child: SizedBox(
                            width: contentWidth,
                            child: FilledButton(
                              onPressed: () => context.go('/bookshelf'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                                shape: const StadiumBorder(),
                                backgroundColor: colorScheme.onSurface,
                                foregroundColor: colorScheme.surface,
                              ),
                              child: Text(
                                primaryActionLabel,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContinueReadingSection(List<ReadingRecord> records) {
    if (records.isEmpty) {
      return _buildSurface(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            '还没有阅读记录。首页已经预留好了继续阅读区块，等你开始阅读后这里会自动填充。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ),
      );
    }

    final visible = records.take(6).toList(growable: false);
    return SizedBox(
      height: _kContinueReadingCardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final record = visible[index];
          return SizedBox(
            width: _kContinueReadingCardWidth,
            child: _buildContinueReadingCard(record),
          );
        },
      ),
    );
  }

  Widget _buildContinueReadingCard(ReadingRecord record) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayState = _bookPresentationResolver.resolveReadingRecord(
      record: record,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => unawaited(_openRecord(record)),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.32),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final cover = resolveBookCover(
                    realCoverUrl: displayState.displayCover,
                    activeTheme:
                        ref.watch(activeAdvancedThemeProvider).valueOrNull,
                    galleries:
                        ref.watch(coverGalleriesProvider).valueOrNull ??
                        const [],
                    brightness: theme.brightness,
                    bookId: record.bookId,
                    sourceId: record.sourceId,
                    detailUrl: record.detailUrl,
                  );
                  return ResolvedBookCoverView(
                    cover: cover,
                    title: displayState.displayTitle,
                    author: displayState.displayAuthor,
                    width: _kContinueReadingCardCoverSize,
                    height: _kContinueReadingCardCoverSize,
                    borderRadius: BorderRadius.circular(14),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                displayState.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayState.displayAuthor?.trim().isNotEmpty == true
                    ? displayState.displayAuthor!
                    : '继续阅读',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '累计 ${_formatMinutes(record.totalReadMillis)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankingPreviewSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final items = _rankingItemsFor(_selectedRankingDimension);

    return _buildSurface(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final dimension in _RankingDimension.values) ...[
                    _RankingChip(
                      label: dimension.label,
                      selected: dimension == _selectedRankingDimension,
                      onTap: () {
                        setState(() {
                          _selectedRankingDimension = dimension;
                        });
                      },
                    ),
                    if (dimension != _RankingDimension.values.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < items.length; index++)
              _RankingListTile(
                rank: index + 1,
                title: items[index].title,
                subtitle: items[index].subtitle,
                trailing: items[index].trailing,
                badgeColor:
                    index == 0
                        ? const Color(0xFFFFC95B)
                        : (index == 1
                            ? const Color(0xFFD8DFEA)
                            : const Color(0xFFE9EEF6)),
                textColor: colorScheme.onSurface,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }

  Widget _buildSectionIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        splashRadius: 18,
        color: Theme.of(context).colorScheme.onSurface,
        icon: Icon(icon, size: 20),
      ),
    );
  }

  Widget _buildSurface({required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(metrics.cardRadius + 6),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  _HomeReadingSummary _buildSummary({
    required List<ReadingRecord> records,
    required List<ReadingRecordDay> dailyRecords,
  }) {
    final todayKey = _dateKeyFor(DateTime.now());
    final todayReadMillis = dailyRecords
        .where((item) => item.dateKey == todayKey)
        .fold<int>(0, (sum, item) => sum + item.readMillis);

    final uniqueDateKeys = dailyRecords
      .map((item) => item.dateKey.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false)..sort();

    final readingStreakDays = _calculateReadingStreakDays(uniqueDateKeys);
    final weekReadMillis = dailyRecords
        .where((item) {
          final date = DateTime.tryParse(item.dateKey)?.toLocal();
          if (date == null) {
            return false;
          }
          final diff = DateUtils.dateOnly(
            DateTime.now(),
          ).difference(DateUtils.dateOnly(date));
          return diff.inDays >= 0 && diff.inDays < 7;
        })
        .fold<int>(0, (sum, item) => sum + item.readMillis);

    return _HomeReadingSummary(
      todayReadMillis: todayReadMillis,
      readingStreakDays: readingStreakDays,
      weekReadMillis: weekReadMillis,
      totalBooks: records.length,
      activeDays: uniqueDateKeys.length,
    );
  }

  int _calculateReadingStreakDays(List<String> sortedDateKeys) {
    if (sortedDateKeys.isEmpty) {
      return 0;
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final uniqueDates = sortedDateKeys
      .map(DateTime.tryParse)
      .whereType<DateTime>()
      .map(DateUtils.dateOnly)
      .toSet()
      .toList(growable: false)..sort((a, b) => b.compareTo(a));

    if (uniqueDates.isEmpty) {
      return 0;
    }

    final first = uniqueDates.first;
    final firstDiff = today.difference(first).inDays;
    if (firstDiff > 1) {
      return 0;
    }

    var streak = 0;
    var cursor = first;
    for (final date in uniqueDates) {
      if (DateUtils.isSameDay(date, cursor)) {
        streak += 1;
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      break;
    }
    return streak;
  }

  Future<void> _loadEngagementState() async {
    final state = await _engagementService.loadState();
    if (!mounted) {
      return;
    }
    setState(() {
      _engagementState = state;
      _isEngagementLoading = false;
    });
  }

  Future<void> _handleCheckInToday() async {
    if (_isSubmittingCheckIn ||
        _engagementState.isCheckedInOn(DateTime.now())) {
      return;
    }

    setState(() {
      _isSubmittingCheckIn = true;
    });

    try {
      final updated = await _engagementService.checkInToday();
      if (!mounted) {
        return;
      }
      setState(() {
        _engagementState = updated;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('今日打卡已完成')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingCheckIn = false;
        });
      }
    }
  }

  Future<void> _showGoalSettingsSheet() async {
    var draftMinutes = _engagementState.dailyGoalMinutes;
    await showAdaptiveActionSurface<void>(
      context: context,
      maxWidth: 460,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '每日阅读目标',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '设置你每天想完成的阅读时长，首页半圆会按分钟/天实时更新进度。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '$draftMinutes 分钟/天',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Slider(
                  value: draftMinutes.toDouble(),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  label: '$draftMinutes 分钟/天',
                  onChanged: (value) {
                    setSheetState(() {
                      draftMinutes = value.round();
                    });
                  },
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final preset in [5, 10, 15, 30, 45, 60])
                      ChoiceChip(
                        label: Text('$preset 分钟/天'),
                        selected: draftMinutes == preset,
                        onSelected: (_) {
                          setSheetState(() {
                            draftMinutes = preset;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final updated = await _engagementService
                          .saveDailyGoalMinutes(draftMinutes);
                      if (!mounted || !sheetContext.mounted) {
                        return;
                      }
                      setState(() {
                        _engagementState = updated;
                      });
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('保存目标'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatGoalClock(int millis) {
    final totalMinutes = Duration(milliseconds: millis).inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}';
  }

  String _formatGoalTarget(int goalMinutes) {
    if (goalMinutes >= 60) {
      final hours = goalMinutes ~/ 60;
      final minutes = goalMinutes % 60;
      if (minutes == 0) {
        return '$hours 小时';
      }
      return '$hours 小时 $minutes 分钟';
    }
    return '$goalMinutes 分钟';
  }

  String _dateKeyFor(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  String _formatMinutes(int millis) {
    final totalMinutes = Duration(milliseconds: millis).inMinutes;
    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      if (minutes == 0) {
        return '$hours 小时';
      }
      return '$hours 小时 $minutes 分';
    }
    return '$totalMinutes 分钟';
  }

  List<_RankingItemData> _rankingItemsFor(_RankingDimension dimension) {
    return switch (dimension) {
      _RankingDimension.hot => const <_RankingItemData>[
        _RankingItemData(
          title: '诡秘之主',
          subtitle: '24 小时热度上升最快',
          trailing: '热度 98',
        ),
        _RankingItemData(
          title: '道诡异仙',
          subtitle: '今日讨论度持续走高',
          trailing: '热度 94',
        ),
        _RankingItemData(
          title: '宿命之环',
          subtitle: '最近新增收藏表现活跃',
          trailing: '热度 91',
        ),
      ],
      _RankingDimension.checkIn => const <_RankingItemData>[
        _RankingItemData(
          title: '晨读俱乐部',
          subtitle: '今日打卡人数最多',
          trailing: '1,286 人',
        ),
        _RankingItemData(title: '晚安书房', subtitle: '七日打卡完成率最高', trailing: '92%'),
        _RankingItemData(
          title: '周末读书会',
          subtitle: '本周新增打卡人数增长快',
          trailing: '+218',
        ),
      ],
      _RankingDimension.duration => const <_RankingItemData>[
        _RankingItemData(
          title: '今日时长冠军',
          subtitle: '连续阅读最久的作品',
          trailing: '6 小时',
        ),
        _RankingItemData(
          title: '地煞七十二变',
          subtitle: '读者平均停留时长很高',
          trailing: '4.8 小时',
        ),
        _RankingItemData(
          title: '赤心巡天',
          subtitle: '周内累计阅读时长稳定',
          trailing: '4.2 小时',
        ),
      ],
      _RankingDimension.streak => const <_RankingItemData>[
        _RankingItemData(
          title: '三十日连读榜首',
          subtitle: '连续阅读天数最高',
          trailing: '30 天',
        ),
        _RankingItemData(
          title: '深夜书桌',
          subtitle: '近两周连续阅读表现稳定',
          trailing: '18 天',
        ),
        _RankingItemData(
          title: '清晨阅读者',
          subtitle: '最近七天每天都有阅读',
          trailing: '7 天',
        ),
      ],
    };
  }

  Future<void> _openRecord(ReadingRecord record) async {
    final progress = await _preferencesService.loadProgress(record.bookId);
    if (!mounted) {
      return;
    }

    final chapterId =
        progress?.chapterId.trim().isNotEmpty == true
            ? progress!.chapterId
            : (record.lastChapterId?.trim().isNotEmpty == true
                ? record.lastChapterId!
                : '');
    final chapterUrl =
        progress?.chapterUrl.trim().isNotEmpty == true
            ? progress!.chapterUrl
            : (record.lastChapterUrl?.trim().isNotEmpty == true
                ? record.lastChapterUrl!
                : '');
    final chapterTitle =
        progress?.chapterTitle.trim().isNotEmpty == true
            ? progress!.chapterTitle
            : (record.lastChapterTitle?.trim().isNotEmpty == true
                ? record.lastChapterTitle!
                : record.bookTitle);
    final chapterIndex = progress?.chapterIndex ?? record.lastChapterIndex;

    if (chapterId.isNotEmpty && chapterUrl.isNotEmpty) {
      context.push(
        _readerEntryRouteResolver.buildChapterRoute(
          bookId: record.bookId,
          chapterId: chapterId,
          chapterUrl: chapterUrl,
          chapterTitle: chapterTitle,
          sourceId: record.sourceId,
          detailUrl: record.detailUrl,
          chapterIndex: chapterIndex,
        ),
      );
      return;
    }

    context.push(
      _readerEntryRouteResolver.buildChapterRoute(
        bookId: record.bookId,
        chapterId: chapterId.isNotEmpty ? chapterId : 'bootstrap',
        chapterUrl: chapterUrl.isNotEmpty ? chapterUrl : null,
        chapterTitle: chapterTitle,
        sourceId: record.sourceId,
        detailUrl: record.detailUrl,
        chapterIndex: chapterIndex,
        openRouteKind: 'home_continue_reading_fallback',
      ),
    );
  }
}

class _HomeReadingSummary {
  const _HomeReadingSummary({
    required this.todayReadMillis,
    required this.readingStreakDays,
    required this.weekReadMillis,
    required this.totalBooks,
    required this.activeDays,
  });

  final int todayReadMillis;
  final int readingStreakDays;
  final int weekReadMillis;
  final int totalBooks;
  final int activeDays;
}

enum _RankingDimension {
  hot('热读榜'),
  checkIn('打卡榜'),
  duration('时长榜'),
  streak('连读榜');

  const _RankingDimension(this.label);

  final String label;
}

class _RankingItemData {
  const _RankingItemData({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String trailing;
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.contentGap,
        vertical: metrics.isCompactDensity ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(metrics.cardRadius + 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _RankingChip extends StatelessWidget {
  const _RankingChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color:
                selected
                    ? colorScheme.onSurface
                    : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? colorScheme.surface : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _RankingListTile extends StatelessWidget {
  const _RankingListTile({
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.badgeColor,
    required this.textColor,
  });

  final int rank;
  final String title;
  final String subtitle;
  final String trailing;
  final Color badgeColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.22),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 2,
          ),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF2A2A2A),
              ),
            ),
          ),
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Text(
            trailing,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadingGoalArcPainter extends CustomPainter {
  const _ReadingGoalArcPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 12.0;
    final clampedProgress = progress.clamp(0.0, 1.0);
    final radius = math.min((size.width - strokeWidth) / 2, size.height - 8);
    final center = Offset(size.width / 2, size.height + radius - 188);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint =
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
    final progressPaint =
        Paint()
          ..color = progressColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);
    if (clampedProgress > 0) {
      canvas.drawArc(
        rect,
        math.pi,
        math.pi * clampedProgress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReadingGoalArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}
