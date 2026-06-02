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
import 'widgets/home_dashboard_layouts.dart';
import 'widgets/home_metric_widgets.dart';

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
  static const double _kContinueReadingCardWidth = 108;
  static const double _kContinueReadingCardHeight = 212;
  static const double _kContinueReadingCardCoverWidth = 92;
  static const double _kContinueReadingCardCoverHeight = 132;

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
  bool _showCheckInSuccessTag = false;
  bool _isCheckInButtonPressed = false;

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
    final metrics = AppAdaptiveMetrics.of(context);
    final desktopLike = AppLayout.isMediumUp(context);
    final topInset =
        desktopLike ? 0.0 : MediaQuery.paddingOf(context).top + kToolbarHeight;
    final desktopContentMaxWidth = AppLayout.pageContentMaxWidth(
      context,
      maxWidth: AppLayout.screenWidth(context) >= 1600 ? 1480 : 1320,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar:
          desktopLike
              ? null
              : AppBar(
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
                  maxWidth:
                      desktopLike
                          ? desktopContentMaxWidth
                          : AppLayout.pageContentMaxWidth(
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
                          : _buildMobileDashboard(metrics),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDashboard(AppAdaptiveMetrics metrics) {
    return HomeMobileDashboardLayout(
      metrics: metrics,
      checkInSummary: _buildCheckInSummarySection(),
      sectionHeader: _buildSectionHeader(context, title: '继续阅读'),
      continueReading: _buildContinueReadingSectionBlock(),
      readingGoal: _buildReadingGoalSection(),
    );
  }

  Widget _buildDesktopDashboard(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return HomeDesktopDashboardLayout(
      metrics: metrics,
      continueReadingPanel: _buildDesktopContinueReadingPanel(context),
      readingSummary: _buildReadingSummarySection(),
    );
  }

  Widget _buildDesktopContinueReadingPanel(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return _buildSurface(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          metrics.cardPadding + 2,
          metrics.cardPadding,
          metrics.cardPadding + 2,
          metrics.cardPadding + 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              context,
              title: '继续阅读',
              actionLabel: '书架',
              onAction: () => context.go('/bookshelf'),
            ),
            SizedBox(height: metrics.contentGap),
            _buildContinueReadingSectionBlock(desktopProminent: true),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingSummarySection() {
    return _buildReadingSummaryStream(
      builder:
          (summary, records) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCheckInCard(summary),
              SizedBox(height: AppAdaptiveMetrics.of(context).sectionGap),
              _buildGoalCard(summary, records),
            ],
          ),
    );
  }

  Widget _buildCheckInSummarySection() {
    return _buildReadingSummaryStream(
      builder: (summary, _) => _buildCheckInCard(summary),
    );
  }

  Widget _buildReadingGoalSection() {
    return _buildReadingSummaryStream(
      builder: (summary, records) => _buildGoalCard(summary, records),
    );
  }

  Widget _buildReadingSummaryStream({
    required Widget Function(
      _HomeReadingSummary summary,
      List<ReadingRecord> records,
    )
    builder,
  }) {
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
              child: KeyedSubtree(
                key: ValueKey<String>(
                  'home_summary_${records.length}_${dailyRecords.length}',
                ),
                child: builder(summary, records),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContinueReadingSectionBlock({bool desktopProminent = false}) {
    return StreamBuilder<List<ReadingRecord>>(
      stream: _readingRecordService.watchLatestRecords(),
      builder: (context, snapshot) {
        final records = snapshot.data ?? const <ReadingRecord>[];
        return AppAnimatedSwitcher(
          child: KeyedSubtree(
            key: ValueKey<String>('continue_reading_${records.length}'),
            child: _buildContinueReadingSection(
              records,
              desktopProminent: desktopProminent,
            ),
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
    final todayReadMinutes =
        Duration(milliseconds: summary.todayReadMillis).inMinutes;
    final metrics = AppAdaptiveMetrics.of(context);
    final canCheckIn =
        !_isEngagementLoading && !_isSubmittingCheckIn && !checkedInToday;

    return _buildSurface(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color:
              checkedInToday
                  ? colorScheme.primaryContainer.withValues(alpha: 0.12)
                  : colorScheme.surface.withValues(alpha: 0.0),
          borderRadius: BorderRadius.circular(metrics.cardRadius + 2),
        ),
        child: Padding(
          padding: EdgeInsets.all(metrics.cardPadding + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCheckInStagger(
                index: 0,
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: checkedInToday ? 1 : 0.86,
                        ),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.8,
                                end: 1.0,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          checkedInToday
                              ? Icons.check_rounded
                              : Icons.check_circle_outline_rounded,
                          key: ValueKey<bool>(checkedInToday),
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.12),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              checkedInToday ? '今日已打卡' : '今日未打卡',
                              key: ValueKey<bool>(checkedInToday),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            checkedInToday ? '保持节奏，继续阅读' : '阅读满 5 分钟即可打卡',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(
                              begin: 0.9,
                              end: 1,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child:
                          _showCheckInSuccessTag
                              ? Container(
                                key: const ValueKey<String>('checkin_success'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '+1 连续天',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              )
                              : const SizedBox(
                                key: ValueKey<String>('checkin_success_empty'),
                              ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: metrics.contentGap),
              _buildCheckInStagger(
                index: 1,
                child: Row(
                  children: [
                    Expanded(
                      child: HomeAnimatedMetricPill(
                        label: '连续打卡',
                        value: streakDays,
                        formatter: (value) => '$value 天',
                      ),
                    ),
                    SizedBox(width: metrics.contentGap),
                    Expanded(
                      child: HomeMetricPill(
                        label: '本周打卡',
                        value: '$weekCheckInCount / 7',
                      ),
                    ),
                    SizedBox(width: metrics.contentGap),
                    Expanded(
                      child: HomeAnimatedMetricPill(
                        label: '今日阅读',
                        value: todayReadMinutes,
                        formatter: _formatCheckInReadFromMinutes,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: metrics.contentGap),
              _buildCheckInStagger(
                index: 2,
                child: SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTapDown:
                        canCheckIn
                            ? (_) => setState(() {
                              _isCheckInButtonPressed = true;
                            })
                            : null,
                    onTapUp:
                        canCheckIn
                            ? (_) => setState(() {
                              _isCheckInButtonPressed = false;
                            })
                            : null,
                    onTapCancel:
                        canCheckIn
                            ? () => setState(() {
                              _isCheckInButtonPressed = false;
                            })
                            : null,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 170),
                      curve: Curves.easeOutCubic,
                      scale: canCheckIn && _isCheckInButtonPressed ? 0.98 : 1.0,
                      child: FilledButton(
                        onPressed: canCheckIn ? _handleCheckInToday : null,
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
                                      : (_isEngagementLoading
                                          ? '加载中...'
                                          : '今日打卡'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
            final contentWidth = (constraints.maxWidth - 8).clamp(0.0, 320.0);
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
                              painter: HomeReadingGoalArcPainter(
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

  Widget _buildContinueReadingSection(
    List<ReadingRecord> records, {
    bool desktopProminent = false,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    if (records.isEmpty) {
      final action = FilledButton.icon(
        onPressed: () => context.go('/bookshelf'),
        icon: const Icon(Icons.library_books_outlined),
        label: const Text('前往书架'),
      );
      return _buildSurface(
        child: Padding(
          padding: EdgeInsets.all(desktopProminent ? 28 : 18),
          child: SizedBox(
            width: double.infinity,
            height: desktopProminent ? 420 : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.72),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),
                SizedBox(height: metrics.sectionGap),
                Text(
                  '还没有继续阅读记录',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: metrics.contentGap),
                Text(
                  '首页已经预留好了继续阅读区块。等你开始阅读后，最近在读内容、累计阅读时长和入口都会自动出现在这里。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.55,
                  ),
                ),
                if (desktopProminent)
                  const Spacer()
                else
                  SizedBox(height: metrics.sectionGap),
                action,
              ],
            ),
          ),
        ),
      );
    }

    final visible = records.take(6).toList(growable: false);
    if (!desktopProminent) {
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

    return Column(
      children: [
        if (visible.isNotEmpty)
          _buildFeaturedContinueReadingCard(visible.first),
        if (visible.length > 1) ...[
          SizedBox(height: metrics.sectionGap),
          SizedBox(
            height: _kContinueReadingCardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: visible.length - 1,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final record = visible[index + 1];
                return SizedBox(
                  width: _kContinueReadingCardWidth,
                  child: _buildContinueReadingCard(record),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFeaturedContinueReadingCard(ReadingRecord record) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayState = _bookPresentationResolver.resolveReadingRecord(
      record: record,
    );
    final metrics = AppAdaptiveMetrics.of(context);
    final authorText =
        displayState.displayAuthor?.trim().isNotEmpty == true
            ? displayState.displayAuthor!
            : '继续阅读';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(metrics.cardRadius + 6),
        onTap: () => unawaited(_openRecord(record)),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
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
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.16),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ResolvedBookCoverView(
                      cover: cover,
                      title: displayState.displayTitle,
                      author: displayState.displayAuthor,
                      width: 168,
                      height: 232,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  );
                },
              ),
              SizedBox(width: metrics.sectionGap),
              Expanded(
                child: SizedBox(
                  height: 232,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayState.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.18,
                        ),
                      ),
                      SizedBox(height: metrics.contentGap * 0.55),
                      Text(
                        authorText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: metrics.contentGap),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.42,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '累计 ${_formatMinutes(record.totalReadMillis)}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '继续回到上次阅读位置，保持今天的阅读节奏。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: metrics.contentGap),
                      FilledButton(
                        onPressed: () => unawaited(_openRecord(record)),
                        child: const Text('继续阅读'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
        borderRadius: BorderRadius.circular(12),
        onTap: () => unawaited(_openRecord(record)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
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
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.16),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ResolvedBookCoverView(
                      cover: cover,
                      title: displayState.displayTitle,
                      author: displayState.displayAuthor,
                      width: _kContinueReadingCardCoverWidth,
                      height: _kContinueReadingCardCoverHeight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayState.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _buildCheckInStagger({required int index, required Widget child}) {
    final begin = (index * 0.08).clamp(0.0, 0.24);
    final end = (begin + 0.56).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, value, child) {
        final translateY = (1 - value) * 10;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: child,
          ),
        );
      },
    );
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
      _isCheckInButtonPressed = false;
    });

    try {
      final updated = await _engagementService.checkInToday();
      if (!mounted) {
        return;
      }
      setState(() {
        _engagementState = updated;
        _showCheckInSuccessTag = true;
      });
      Future<void>.delayed(const Duration(milliseconds: 980), () {
        if (!mounted || !_showCheckInSuccessTag) {
          return;
        }
        setState(() {
          _showCheckInSuccessTag = false;
        });
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

  String _formatCheckInReadFromMinutes(int value) {
    final totalMinutes = math.max(0, value);
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours <= 0) {
      return '${totalMinutes}m';
    }
    return '${hours}h${minutes.toString().padLeft(2, '0')}m';
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
