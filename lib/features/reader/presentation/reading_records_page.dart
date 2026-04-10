import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/widgets/disk_cached_cover_image.dart';
import '../../../app/widgets/text_cover_placeholder.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reading_book_status.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reading_record_day.dart';
import '../../../domain/entities/reading_record_session.dart';
import '../../book/presentation/book_detail_route.dart';
import '../application/reading_book_status_service.dart';
import '../application/reader_entry_route_resolver.dart';
import '../application/reader_preferences_service.dart';
import '../application/reading_records_query_service.dart';
import '../application/reading_record_service.dart';
import '../application/reader_system_settings_service.dart';

enum _HeatmapMetricMode { duration, sessionCount, workCount }

enum _HeatmapRangeMode { threeMonths, sixMonths, oneYear, all }

enum _ReadingRecordQuickAction {
  merge,
  markReading,
  markCompleted,
  clearStatus,
}

class ReadingRecordsPage extends StatefulWidget {
  const ReadingRecordsPage({
    super.key,
    ReadingRecordService? readingRecordService,
    ReaderPreferencesService? preferencesService,
    ReaderSystemSettingsService? readerSystemSettingsService,
  }) : _readingRecordService = readingRecordService,
       _preferencesService = preferencesService,
       _readerSystemSettingsService = readerSystemSettingsService;

  final ReadingRecordService? _readingRecordService;
  final ReaderPreferencesService? _preferencesService;
  final ReaderSystemSettingsService? _readerSystemSettingsService;

  @override
  State<ReadingRecordsPage> createState() => _ReadingRecordsPageState();
}

class _ReadingRecordsPageState extends State<ReadingRecordsPage> {
  late final ReadingRecordService _readingRecordService;
  final ReadingRecordsQueryService _readingRecordsQueryService =
      const ReadingRecordsQueryService();
  final ReaderEntryRouteResolver _readerEntryRouteResolver =
      const ReaderEntryRouteResolver();
  late final ReaderPreferencesService _preferencesService;
  late final ReaderSystemSettingsService _readerSystemSettingsService;
  late final ReadingBookStatusService _readingBookStatusService;
  late final Stream<bool> _readRecordEnabledStream;

  ReadingRecordsPeriod _period = ReadingRecordsPeriod.day;
  DateTime _periodAnchor = DateTime.now();
  _HeatmapMetricMode _heatmapMode = _HeatmapMetricMode.duration;
  _HeatmapRangeMode _heatmapRangeMode = _HeatmapRangeMode.threeMonths;
  bool _skipDeleteConfirmForThisPage = false;

  @override
  void initState() {
    super.initState();
    _readingRecordService =
        widget._readingRecordService ?? ReadingRecordService();
    _preferencesService =
        widget._preferencesService ?? ReaderPreferencesService();
    _readerSystemSettingsService =
        widget._readerSystemSettingsService ?? ReaderSystemSettingsService();
    _readingBookStatusService = ReadingBookStatusService();
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
    });
  }

  void _movePeriod(int offset) {
    if (_period == ReadingRecordsPeriod.all) {
      return;
    }
    setState(() {
      _periodAnchor = _shiftPeriodAnchor(_periodAnchor, offset);
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
        return DateTime(
          normalized.year,
          normalized.month + offset,
          normalized.day,
        );
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
      final route = _readerEntryRouteResolver.buildChapterRoute(
        bookId: record.bookId,
        chapterId: chapterId,
        chapterUrl: chapterUrl,
        chapterTitle: chapterTitle,
        sourceId: record.sourceId,
        detailUrl: record.detailUrl,
        chapterIndex: chapterIndex,
      );
      context.push(route);
      return;
    }

    context.push(
      buildBookDetailRoute(
        bookId: record.bookId,
        sourceId: record.sourceId,
        detailUrl: record.detailUrl,
        title: record.bookTitle,
      ),
    );
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    if (_skipDeleteConfirmForThisPage) {
      return true;
    }

    final result = await showDialog<_DeleteConfirmResult>(
      context: context,
      builder: (dialogContext) {
        var skipConfirm = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap:
                        () => setDialogState(() {
                          skipConfirm = !skipConfirm;
                        }),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: skipConfirm,
                          onChanged:
                              (value) => setDialogState(() {
                                skipConfirm = value ?? false;
                              }),
                        ),
                        const Flexible(child: Text('本次不再确认')),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      () => Navigator.of(
                        dialogContext,
                      ).pop(const _DeleteConfirmResult(confirmed: false)),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed:
                      () => Navigator.of(dialogContext).pop(
                        _DeleteConfirmResult(
                          confirmed: true,
                          skipConfirmForThisPage: skipConfirm,
                        ),
                      ),
                  child: const Text('删除'),
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted || result == null) {
      return false;
    }
    if (result.skipConfirmForThisPage) {
      setState(() {
        _skipDeleteConfirmForThisPage = true;
      });
    }
    return result.confirmed;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showUndoSnackBar({
    required String message,
    required Future<void> Function() onUndo,
  }) async {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: '撤销', onPressed: () {}),
      ),
    );
    final reason = await controller.closed;
    if (!mounted || reason != SnackBarClosedReason.action) {
      return;
    }
    await onUndo();
    if (!mounted) {
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('已撤销。')));
  }

  Future<void> _applyQuickAction(
    _ReadingRecordQuickAction action,
    ReadingRecord record,
  ) async {
    switch (action) {
      case _ReadingRecordQuickAction.merge:
        await _mergeRecord(record);
        return;
      case _ReadingRecordQuickAction.markReading:
        await _readingBookStatusService.setManualStatus(
          record: record,
          override: ReadingBookStatusOverride.reading,
        );
        if (!mounted) {
          return;
        }
        _showMessage('已将《${record.bookTitle}》标记为在读。');
        return;
      case _ReadingRecordQuickAction.markCompleted:
        await _readingBookStatusService.setManualStatus(
          record: record,
          override: ReadingBookStatusOverride.completed,
        );
        if (!mounted) {
          return;
        }
        _showMessage('已将《${record.bookTitle}》标记为读完。');
        return;
      case _ReadingRecordQuickAction.clearStatus:
        await _readingBookStatusService.clearManualStatus(record.bookId);
        if (!mounted) {
          return;
        }
        _showMessage('已清除《${record.bookTitle}》的手动状态。');
        return;
    }
  }

  Future<void> _mergeRecord(ReadingRecord target) async {
    final result = await _readingRecordService.getMergeCandidates(target);
    if (!mounted) {
      return;
    }
    final candidates = result.candidates;
    if (candidates.isEmpty) {
      final blockedSuffix =
          result.blockedCount > 0
              ? ' 已自动过滤 ${result.blockedCount} 条作者不一致的同标题记录。'
              : '';
      _showMessage('没有可合并的低风险阅读记录。$blockedSuffix');
      return;
    }

    final selected = await showDialog<List<ReadingRecordMergeCandidate>>(
      context: context,
      builder: (dialogContext) {
        final selectedBookIds = <String>{
          for (final item in candidates) item.record.bookId,
        };
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('合并阅读记录'),
              content: SizedBox(
                width: AppLayout.dialogMaxWidth(context, maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('将以下《${target.bookTitle}》记录合并到当前条目：'),
                    if (result.blockedCount > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '已自动过滤 ${result.blockedCount} 条作者明显不一致的同标题记录，避免误并。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 320,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final item in candidates)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: selectedBookIds.contains(
                                  item.record.bookId,
                                ),
                                onChanged: (checked) {
                                  setDialogState(() {
                                    if (checked ?? false) {
                                      selectedBookIds.add(item.record.bookId);
                                    } else {
                                      selectedBookIds.remove(
                                        item.record.bookId,
                                      );
                                    }
                                  });
                                },
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.record.bookAuthor
                                                    ?.trim()
                                                    .isNotEmpty ==
                                                true
                                            ? item.record.bookAuthor!.trim()
                                            : '未知作者',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildMergeRiskChip(item.risk),
                                  ],
                                ),
                                subtitle: Text(
                                  '${_formatDuration(item.record.totalReadMillis)} · ${_formatDateTime(item.record.lastReadAt)}\n${item.hint}',
                                ),
                                isThreeLine: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final selectedItems = candidates
                        .where(
                          (item) =>
                              selectedBookIds.contains(item.record.bookId),
                        )
                        .toList(growable: false);
                    Navigator.of(dialogContext).pop(selectedItems);
                  },
                  child: const Text('合并'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || selected == null || selected.isEmpty) {
      return;
    }

    final reviewCandidates = selected
        .where((item) => item.requiresExtraConfirmation)
        .toList(growable: false);
    if (reviewCandidates.isNotEmpty) {
      final confirmed = await _confirmMergeRisk(
        target: target,
        reviewCandidates: reviewCandidates,
      );
      if (!mounted || !confirmed) {
        return;
      }
    }

    await _readingRecordService.mergeRecords(
      target: target,
      sources: selected.map((item) => item.record).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    _showMessage('已合并 ${selected.length} 条阅读记录。');
  }

  Future<bool> _confirmMergeRisk({
    required ReadingRecord target,
    required List<ReadingRecordMergeCandidate> reviewCandidates,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('合并前确认'),
          content: SizedBox(
            width: AppLayout.dialogMaxWidth(dialogContext, maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('以下候选需要你再确认一次，避免把同标题但不是同一本书的记录合并到《${target.bookTitle}》。'),
                const SizedBox(height: 12),
                for (final item in reviewCandidates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '• ${item.record.bookAuthor?.trim().isNotEmpty == true ? item.record.bookAuthor!.trim() : '未知作者'} · ${item.hint}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('继续合并'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: LayoutBuilder(
        builder: (context, _) {
          final maxWidth = AppLayout.pageContentMaxWidth(
            context,
            maxWidth: AppLayout.settingsContentMaxWidth,
          );
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: StreamBuilder<List<ReadingRecord>>(
                stream: _readingRecordService.watchLatestRecords(),
                builder: (context, latestSnapshot) {
                  final latestRecords =
                      latestSnapshot.data ?? const <ReadingRecord>[];
                  return StreamBuilder<List<ReadingRecordDay>>(
                    stream: _readingRecordService.watchDailyRecords(),
                    builder: (context, dailySnapshot) {
                      final dailyRecords =
                          dailySnapshot.data ?? const <ReadingRecordDay>[];
                      return StreamBuilder<List<ReadingRecordSession>>(
                        stream: _readingRecordService.watchSessions(),
                        builder: (context, sessionSnapshot) {
                          final sessions =
                              sessionSnapshot.data ??
                              const <ReadingRecordSession>[];
                          return StreamBuilder<List<LocalBook>>(
                            stream: _readingBookStatusService.watchLocalBooks(),
                            builder: (context, localBooksSnapshot) {
                              final localBooks =
                                  localBooksSnapshot.data ??
                                  const <LocalBook>[];
                              return StreamBuilder<
                                List<ReadingBookStatusEntry>
                              >(
                                stream:
                                    _readingBookStatusService
                                        .watchManualStatuses(),
                                builder: (context, statusSnapshot) {
                                  final manualStatuses =
                                      statusSnapshot.data ??
                                      const <ReadingBookStatusEntry>[];
                                  final resolvedStatusesByBookId =
                                      _readingBookStatusService.resolveStatuses(
                                        latestRecords: latestRecords,
                                        localBooks: localBooks,
                                        manualStatuses: manualStatuses,
                                      );
                                  final queryView = _readingRecordsQueryService
                                      .buildQueryView(
                                        latestRecords: latestRecords,
                                        dailyRecords: dailyRecords,
                                        sessions: sessions,
                                        period: _period,
                                        anchor: _periodAnchor,
                                        resolvedStatusesByBookId:
                                            resolvedStatusesByBookId,
                                      );
                                  final showRanking =
                                      _period == ReadingRecordsPeriod.day;
                                  final showHeatmap =
                                      _period != ReadingRecordsPeriod.day;

                                  return ListView(
                                    padding: EdgeInsets.fromLTRB(
                                      horizontal,
                                      12,
                                      horizontal,
                                      12 + bottomSafe,
                                    ),
                                    children: [
                                      _buildControlsCard(),
                                      const SizedBox(height: 8),
                                      _buildSummaryCard(
                                        summary: queryView.summary,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildSectionHeading(
                                        queryView.distribution.title,
                                        subtitle: '当前周期内的阅读时长变化',
                                      ),
                                      _buildDurationDistributionCard(
                                        queryView.distribution,
                                      ),
                                      if (showRanking) ...[
                                        const SizedBox(height: 12),
                                        _buildDurationRankingSection(
                                          queryView.rankings,
                                          resolvedStatusesByBookId:
                                              resolvedStatusesByBookId,
                                        ),
                                      ],
                                      if (showHeatmap) ...[
                                        const SizedBox(height: 12),
                                        _buildSectionHeading(
                                          '阅读热力图',
                                          subtitle: '查看阅读活跃分布',
                                        ),
                                        _buildHeatmapCard(
                                          dailyRecords,
                                          sessions: sessions,
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      _buildActiveSection(
                                        latestRecords:
                                            queryView.filteredLatestRecords,
                                        resolvedStatusesByBookId:
                                            resolvedStatusesByBookId,
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlsCard() {
    final currentPeriodRange = _currentPeriodRange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final period in ReadingRecordsPeriod.values)
              ChoiceChip(
                label: Text(_periodLabel(period)),
                selected: _period == period,
                onSelected: (_) => _setPeriod(period),
              ),
          ],
        ),
        if (_period != ReadingRecordsPeriod.all) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
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
        const SizedBox(height: 8),
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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(14),
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

  Widget _buildHeatmapCard(
    List<ReadingRecordDay> allDays, {
    required List<ReadingRecordSession> sessions,
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
    final startDate = _resolveHeatmapStartDate(
      firstDate: firstDate,
      today: today,
    );
    final showEarlierDataIndicator = _heatmapRangeMode != _HeatmapRangeMode.all;
    final weeks = _buildHeatmapWeeks(startDate: startDate, endDate: today);
    final monthLabels = _buildHeatmapMonthLabels(weeks);
    final visibleDateKeys = <String>{};
    for (final week in weeks) {
      for (final day in week) {
        if (day.isBefore(startDate) || day.isAfter(today)) {
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
      final value =
          _heatmapMode == _HeatmapMetricMode.duration
              ? item.readMillis
              : _heatmapMode == _HeatmapMetricMode.sessionCount
              ? item.sessionCount
              : item.workCount;
      return math.max(current, value);
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
                  '活跃分布',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (_period != ReadingRecordsPeriod.all)
                TextButton(
                  onPressed: () {
                    _setPeriod(ReadingRecordsPeriod.all);
                  },
                  child: const Text('重置'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '颜色越深，表示当天阅读更多。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_dateKeyFor(startDate)} 至 ${_dateKeyFor(today)}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeatmapMenu<_HeatmapMetricMode>(
                icon: Icons.auto_graph_rounded,
                label: _heatmapModeLabel,
                items: const [
                  PopupMenuItem(
                    value: _HeatmapMetricMode.duration,
                    child: Text('按时长'),
                  ),
                  PopupMenuItem(
                    value: _HeatmapMetricMode.sessionCount,
                    child: Text('按会话数'),
                  ),
                  PopupMenuItem(
                    value: _HeatmapMetricMode.workCount,
                    child: Text('按作品数'),
                  ),
                ],
                onSelected: (value) {
                  setState(() {
                    _heatmapMode = value;
                  });
                },
              ),
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
                  PopupMenuItem(
                    value: _HeatmapRangeMode.all,
                    child: Text('全部'),
                  ),
                ],
                onSelected: (value) {
                  setState(() {
                    _heatmapRangeMode = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                          padding: const EdgeInsets.only(right: 4),
                          child: SizedBox(
                            width: 28,
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
                              overflow: TextOverflow.clip,
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
                        padding: const EdgeInsets.only(right: 4),
                        child: Column(
                          children: [
                            for (final day in week)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
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
    ReadingDurationDistribution distribution,
  ) {
    if (distribution.weeks.isEmpty) {
      return _buildEmptyCard('当前周期下还没有可以展示的阅读时间分布。');
    }

    final colorScheme = Theme.of(context).colorScheme;
    const weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
              '阅读时间分布',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${distribution.monthLabel} · 有阅读的日期会高亮显示。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final label in weekLabels)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          label,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            for (final week in distribution.weeks)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    for (final day in week.days)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _buildDistributionCalendarCell(day),
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

  Widget _buildDurationRankingSection(
    List<ReadingDurationRankingItem> rankings, {
    required Map<String, ReadingBookResolvedStatus> resolvedStatusesByBookId,
  }) {
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
          _buildRecordSurface(
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openRecord(visibleItems[index].record),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
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
                      visibleItems[index].record.coverUrl,
                      title: visibleItems[index].record.bookTitle,
                      author: visibleItems[index].record.bookAuthor,
                      width: 42,
                      height: 58,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visibleItems[index].record.bookTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (resolvedStatusesByBookId[visibleItems[index]
                                  .record
                                  .bookId] !=
                              null) ...[
                            const SizedBox(height: 6),
                            _buildStatusChip(
                              resolvedStatusesByBookId[visibleItems[index]
                                  .record
                                  .bookId]!,
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            '阅读字数 ${_formatReadChars(visibleItems[index].readChars)}'
                            '${visibleItems[index].readDays > 0 ? ' · ${visibleItems[index].readDays} 天' : ''}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(visibleItems[index].readMillis),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (index < visibleItems.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildDistributionCalendarCell(ReadingCalendarDistributionDay day) {
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
              borderRadius: BorderRadius.circular(10),
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _heatmapModeLabel {
    return switch (_heatmapMode) {
      _HeatmapMetricMode.duration => '按时长',
      _HeatmapMetricMode.sessionCount => '按会话数',
      _HeatmapMetricMode.workCount => '按作品数',
    };
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
    final characters = '没有更早数据'.split('');
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

  Widget _buildHeatmapCell({
    required DateTime day,
    required DailyHeatmapStat? stats,
    required int maxValue,
  }) {
    final dateKey = _dateKeyFor(day);
    final value =
        stats == null
            ? 0
            : _heatmapMode == _HeatmapMetricMode.duration
            ? stats.readMillis
            : _heatmapMode == _HeatmapMetricMode.sessionCount
            ? stats.sessionCount
            : stats.workCount;
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
          child: const SizedBox(width: 14, height: 14),
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
        padding: const EdgeInsets.all(16),
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
                      const SizedBox(height: 6),
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
                  const SizedBox(width: 12),
                  _buildSummaryCoverStack(summary.coverRecords),
                ],
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final columns = AppLayout.readingRecordsMetricColumnsForWidth(
                  maxWidth,
                );
                final spacing = 12.0;
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeading(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
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
            const SizedBox(width: 8),
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

  Widget _buildActiveSection({
    required List<ReadingRecord> latestRecords,
    required Map<String, ReadingBookResolvedStatus> resolvedStatusesByBookId,
  }) {
    return _buildLatestSection(
      latestRecords,
      resolvedStatusesByBookId: resolvedStatusesByBookId,
    );
  }

  Widget _buildLatestSection(
    List<ReadingRecord> records, {
    required Map<String, ReadingBookResolvedStatus> resolvedStatusesByBookId,
  }) {
    if (records.isEmpty) {
      return _buildEmptyCard(
        _period == ReadingRecordsPeriod.all ? '还没有阅读记录。' : '当前周期下没有阅读记录。',
      );
    }

    return Column(
      children: [
        _buildSectionHeading('阅读记录', subtitle: '按阅读时间整理'),
        for (final record in records) ...[
          Dismissible(
            key: ValueKey('reading_record_${record.bookId}'),
            direction: DismissDirection.endToStart,
            background: _buildDismissibleDeleteBackground(),
            confirmDismiss: (_) async {
              final confirmed = await _confirmDelete(
                title: '删除阅读记录',
                message: '将删除《${record.bookTitle}》的全部阅读记录，包括按天汇总和时间线。',
              );
              if (!confirmed) {
                return false;
              }
              final snapshot = await _readingRecordService
                  .deleteRecordWithSnapshot(record);
              if (snapshot == null) {
                return false;
              }
              if (mounted) {
                unawaited(
                  _showUndoSnackBar(
                    message: '已删除《${record.bookTitle}》的阅读记录。',
                    onUndo:
                        () => _readingRecordService.restoreDeletedRecord(
                          snapshot,
                        ),
                  ),
                );
              }
              return true;
            },
            child: _buildRecordSurface(
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openRecord(record),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCover(
                        record.coverUrl,
                        title: record.bookTitle,
                        author: record.bookAuthor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.bookTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            if (resolvedStatusesByBookId[record.bookId] !=
                                null) ...[
                              const SizedBox(height: 6),
                              _buildStatusChip(
                                resolvedStatusesByBookId[record.bookId]!,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              '最后阅读：${_formatDateTime(record.lastReadAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '累计字数：${_formatReadChars(record.totalReadChars)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 96,
                        height: 74,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                _formatDurationCompact(record.totalReadMillis),
                                maxLines: 1,
                                softWrap: false,
                                textAlign: TextAlign.right,
                                style: Theme.of(
                                  context,
                                ).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _buildCompactTrailingAction(
                                  tooltip: '合并记录',
                                  icon: Icons.merge_type_rounded,
                                  onTap: () => unawaited(_mergeRecord(record)),
                                ),
                                const SizedBox(width: 6),
                                _buildRecordQuickActionMenu(record),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(padding: const EdgeInsets.all(20), child: Text(message)),
      ),
    );
  }

  Widget _buildCompactTrailingAction({
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: colorScheme.primaryContainer.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: SizedBox(
              width: 30,
              height: 30,
              child: Center(
                child: Icon(
                  icon,
                  size: 18,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordQuickActionMenu(ReadingRecord record) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuButton<_ReadingRecordQuickAction>(
      tooltip: '更多操作',
      onSelected: (action) => unawaited(_applyQuickAction(action, record)),
      itemBuilder:
          (context) => const [
            PopupMenuItem(
              value: _ReadingRecordQuickAction.markReading,
              child: Text('标记为在读'),
            ),
            PopupMenuItem(
              value: _ReadingRecordQuickAction.markCompleted,
              child: Text('标记为读完'),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: _ReadingRecordQuickAction.clearStatus,
              child: Text('清除手动状态'),
            ),
          ],
      child: Semantics(
        button: true,
        label: '更多操作',
        child: Material(
          color: colorScheme.primaryContainer.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(10),
          child: const SizedBox(
            width: 30,
            height: 30,
            child: Icon(Icons.more_horiz_rounded, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(ReadingBookResolvedStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (status.kind) {
      ReadingBookStatusKind.reading => (
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
        Icons.import_contacts_rounded,
      ),
      ReadingBookStatusKind.completed => (
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
        Icons.task_alt_rounded,
      ),
    };

    final label = status.isManual ? '${status.label} · 手动' : status.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
                  visible[index].coverUrl,
                  title: visible[index].bookTitle,
                  author: visible[index].bookAuthor,
                  width: 44,
                  height: 62,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDismissibleDeleteBackground() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline_rounded, color: colorScheme.error),
          const SizedBox(height: 4),
          Text(
            '删除',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMergeRiskChip(ReadingRecordMergeRisk risk) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, background, foreground) = switch (risk) {
      ReadingRecordMergeRisk.safe => (
        '低风险',
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      ReadingRecordMergeRisk.review => (
        '需确认',
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
      ),
      ReadingRecordMergeRisk.blocked => (
        '已过滤',
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildCover(
    String? coverUrl, {
    String? title,
    String? author,
    double width = 54,
    double height = 74,
  }) {
    final uri = Uri.tryParse(coverUrl ?? '');
    if (uri == null || !uri.hasScheme) {
      return _buildCoverFallback(
        title: title,
        author: author,
        width: width,
        height: height,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DiskCachedCoverImage(
        imageUrl: coverUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        fallback: _buildCoverFallback(
          title: title,
          author: author,
          width: width,
          height: height,
        ),
      ),
    );
  }

  Widget _buildCoverFallback({
    String? title,
    String? author,
    required double width,
    required double height,
  }) {
    return TextCoverPlaceholder(
      title: title,
      author: author,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(10),
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

  String _formatDurationCompact(int millis) {
    return _formatDuration(millis).replaceAll(' ', '');
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

  String _formatDateTime(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  String _dateKeyFor(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

class _DeleteConfirmResult {
  const _DeleteConfirmResult({
    required this.confirmed,
    this.skipConfirmForThisPage = false,
  });

  final bool confirmed;
  final bool skipConfirmForThisPage;
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
