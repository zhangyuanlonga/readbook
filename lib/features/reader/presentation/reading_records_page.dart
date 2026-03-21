import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/widgets/disk_cached_cover_image.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reading_record_day.dart';
import '../../../domain/entities/reading_record_session.dart';
import '../application/reader_preferences_service.dart';
import '../application/reading_record_service.dart';
import '../application/reader_system_settings_service.dart';

enum _ReadingRecordsView { latest, daily, timeline }

enum _HeatmapMetricMode { duration, count }

enum _HeatmapRangeMode { threeMonths, sixMonths, oneYear, all }

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
  final TextEditingController _searchController = TextEditingController();
  late final ReadingRecordService _readingRecordService;
  late final ReaderPreferencesService _preferencesService;
  late final ReaderSystemSettingsService _readerSystemSettingsService;
  late final Stream<bool> _readRecordEnabledStream;

  String _searchKeyword = '';
  String? _selectedDateKey;
  _ReadingRecordsView _view = _ReadingRecordsView.latest;
  _HeatmapMetricMode _heatmapMode = _HeatmapMetricMode.duration;
  _HeatmapRangeMode _heatmapRangeMode = _HeatmapRangeMode.threeMonths;
  bool _skipDeleteConfirmForThisPage = false;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _readingRecordService =
        widget._readingRecordService ?? ReadingRecordService();
    _preferencesService =
        widget._preferencesService ?? ReaderPreferencesService();
    _readerSystemSettingsService =
        widget._readerSystemSettingsService ?? ReaderSystemSettingsService();
    _readRecordEnabledStream =
        _readerSystemSettingsService.watchReadRecordEnabled();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final keyword = _searchController.text.trim();
    if (keyword == _searchKeyword) {
      return;
    }
    setState(() {
      _searchKeyword = keyword;
    });
  }

  void _cycleView() {
    setState(() {
      _view = switch (_view) {
        _ReadingRecordsView.latest => _ReadingRecordsView.daily,
        _ReadingRecordsView.daily => _ReadingRecordsView.timeline,
        _ReadingRecordsView.timeline => _ReadingRecordsView.latest,
      };
    });
  }

  IconData get _viewCycleIcon {
    return switch (_view) {
      _ReadingRecordsView.latest => Icons.calendar_today_rounded,
      _ReadingRecordsView.daily => Icons.timeline_rounded,
      _ReadingRecordsView.timeline => Icons.schedule_rounded,
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
      final route =
          Uri(
            path: '/reader/${record.bookId}/$chapterId',
            queryParameters: <String, String>{
              'chapterUrl': chapterUrl,
              'chapterTitle': chapterTitle,
              'sourceId': record.sourceId,
              'detailUrl': record.detailUrl,
              if (chapterIndex != null) 'chapterIndex': chapterIndex.toString(),
            },
          ).toString();
      context.push(route);
      return;
    }

    context.push(
      Uri(
        path: '/book/${record.bookId}',
        queryParameters: <String, String>{
          'sourceId': record.sourceId,
          'detailUrl': record.detailUrl,
          'title': record.bookTitle,
        },
      ).toString(),
    );
  }

  Future<void> _openSessionRecord(ReadingRecordSession session) async {
    final chapterId = session.chapterId?.trim() ?? '';
    final chapterUrl = session.chapterUrl?.trim() ?? '';
    final chapterTitle = session.chapterTitle?.trim();

    if (chapterId.isNotEmpty && chapterUrl.isNotEmpty) {
      final route =
          Uri(
            path: '/reader/${session.bookId}/$chapterId',
            queryParameters: <String, String>{
              'chapterUrl': chapterUrl,
              'chapterTitle':
                  chapterTitle?.isNotEmpty == true
                      ? chapterTitle!
                      : session.bookTitle,
              'sourceId': session.sourceId,
              'detailUrl': session.detailUrl,
              if (session.chapterIndex != null)
                'chapterIndex': session.chapterIndex.toString(),
            },
          ).toString();
      context.push(route);
      return;
    }

    context.push(
      Uri(
        path: '/book/${session.bookId}',
        queryParameters: <String, String>{
          'sourceId': session.sourceId,
          'detailUrl': session.detailUrl,
          'title': session.bookTitle,
        },
      ).toString(),
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

  Future<void> _openHeatmapSheet() async {
    final heightFactor = AppLayout.sheetHeightFactor(
      context,
      compact: 0.78,
      regular: 0.72,
      large: 0.66,
    );
    final horizontal = AppSpacing.pageHorizontal(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        final maxSheetHeight =
            MediaQuery.sizeOf(sheetContext).height * heightFactor;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: StatefulBuilder(
            builder: (context, sheetSetState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  4,
                  horizontal,
                  12 + bottomInset,
                ),
                child: StreamBuilder<List<ReadingRecordDay>>(
                  stream: _readingRecordService.watchDailyRecords(
                    query: _searchKeyword,
                  ),
                  builder: (context, snapshot) {
                    final dailyRecords =
                        snapshot.data ?? const <ReadingRecordDay>[];
                    return SingleChildScrollView(
                      child: SizedBox(
                        width: double.infinity,
                        child: _buildHeatmapCard(
                          dailyRecords,
                          inSheet: true,
                          sheetSetState: sheetSetState,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
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
                width: 420,
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
            width: 420,
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

  String get _viewLabel {
    return switch (_view) {
      _ReadingRecordsView.latest => '最近阅读',
      _ReadingRecordsView.daily => '按天汇总',
      _ReadingRecordsView.timeline => '时间线',
    };
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('阅读记录'),
            Text(
              _viewLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '切换视图',
            onPressed: _cycleView,
            icon: Icon(_viewCycleIcon),
          ),
          IconButton(
            tooltip: '热力图',
            onPressed: _openHeatmapSheet,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
          IconButton(
            tooltip: _showSearch ? '收起搜索' : '搜索',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                }
              });
            },
            icon: Icon(
              _showSearch ? Icons.close_rounded : Icons.search_rounded,
            ),
          ),
        ],
      ),
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
                stream: _readingRecordService.watchLatestRecords(
                  query: _searchKeyword,
                ),
                builder: (context, latestSnapshot) {
                  final latestRecords =
                      latestSnapshot.data ?? const <ReadingRecord>[];
                  return StreamBuilder<List<ReadingRecordDay>>(
                    stream: _readingRecordService.watchDailyRecords(
                      query: _searchKeyword,
                    ),
                    builder: (context, dailySnapshot) {
                      final dailyRecords =
                          dailySnapshot.data ?? const <ReadingRecordDay>[];
                      return StreamBuilder<List<ReadingRecordSession>>(
                        stream: _readingRecordService.watchSessions(
                          query: _searchKeyword,
                        ),
                        builder: (context, sessionSnapshot) {
                          final sessions =
                              sessionSnapshot.data ??
                              const <ReadingRecordSession>[];
                          final filteredLatest = _filterLatestRecords(
                            latestRecords,
                            dailyRecords,
                          );
                          final filteredDays = _filterDailyRecords(
                            dailyRecords,
                          );
                          final filteredSessions = _mergeTimelineSessions(
                            _filterSessions(sessions),
                          );

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
                                latestRecords: latestRecords,
                                filteredLatestRecords: filteredLatest,
                                filteredDailyRecords: filteredDays,
                                filteredSessions: filteredSessions,
                              ),
                              const SizedBox(height: 12),
                              _buildActiveSection(
                                latestRecords: filteredLatest,
                                dailyRecords: filteredDays,
                                allLatestRecords: latestRecords,
                                sessions: filteredSessions,
                              ),
                            ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child:
              !_showSearch
                  ? const SizedBox.shrink()
                  : Container(
                    key: const ValueKey('reading_record_search'),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '搜索书名或作者',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon:
                            _searchKeyword.isEmpty
                                ? null
                                : IconButton(
                                  tooltip: '清空',
                                  onPressed: _searchController.clear,
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
        ),
        Row(
          children: [
            _buildViewPill(icon: Icons.schedule_rounded, label: _viewLabel),
            if (_searchKeyword.isNotEmpty) ...[
              const SizedBox(width: 8),
              _buildViewPill(
                icon: Icons.search_rounded,
                label: '搜索“$_searchKeyword”',
              ),
            ],
          ],
        ),
        if (_selectedDateKey != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildViewPill(
                  icon: Icons.event_available_rounded,
                  label: '已按 $_selectedDateKey 过滤',
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedDateKey = null;
                  });
                },
                child: const Text('清除'),
              ),
            ],
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
    bool inSheet = false,
    StateSetter? sheetSetState,
  }) {
    if (allDays.isEmpty) {
      return _buildEmptyCard('还没有可以展示的阅读热力图。');
    }

    final statsByDate = _buildHeatmapStats(allDays);
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
    final maxValue = statsByDate.values.fold<int>(
      0,
      (current, item) => math.max(
        current,
        _heatmapMode == _HeatmapMetricMode.duration
            ? item.readMillis
            : item.bookCount,
      ),
    );

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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_selectedDateKey != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDateKey = null;
                    });
                    sheetSetState?.call(() {});
                  },
                  child: const Text('清除'),
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
                    value: _HeatmapMetricMode.count,
                    child: Text('按次数'),
                  ),
                ],
                onSelected: (value) {
                  setState(() {
                    _heatmapMode = value;
                  });
                  sheetSetState?.call(() {});
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
                  sheetSetState?.call(() {});
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
                                  sheetSetState: sheetSetState,
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
            '点击某一天可筛选下方阅读记录。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (inSheet) {
      return content;
    }
    return Card(child: content);
  }

  String get _heatmapModeLabel {
    return switch (_heatmapMode) {
      _HeatmapMetricMode.duration => '按时长',
      _HeatmapMetricMode.count => '按次数',
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
    required _DailyHeatmapStat? stats,
    required int maxValue,
    StateSetter? sheetSetState,
  }) {
    final dateKey = _dateKeyFor(day);
    final value =
        stats == null
            ? 0
            : _heatmapMode == _HeatmapMetricMode.duration
            ? stats.readMillis
            : stats.bookCount;
    final normalized = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    final isSelected = _selectedDateKey == dateKey;
    final colorScheme = Theme.of(context).colorScheme;
    final fillColor =
        value <= 0
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primary.withValues(alpha: 0.18 + (normalized * 0.72));

    final tooltip =
        stats == null
            ? '$dateKey\n无阅读记录'
            : '$dateKey\n${stats.bookCount} 本 · ${_formatDuration(stats.readMillis)}';

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: () {
          setState(() {
            _selectedDateKey = _selectedDateKey == dateKey ? null : dateKey;
          });
          sheetSetState?.call(() {});
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

  Widget _buildSummaryCard({
    required List<ReadingRecord> latestRecords,
    required List<ReadingRecord> filteredLatestRecords,
    required List<ReadingRecordDay> filteredDailyRecords,
    required List<ReadingRecordSession> filteredSessions,
  }) {
    final selectedDateKey = _selectedDateKey;
    final recordsForSummary =
        selectedDateKey == null ? latestRecords : filteredLatestRecords;
    final totalBooks =
        selectedDateKey == null
            ? recordsForSummary.length
            : filteredDailyRecords.map((item) => item.bookId).toSet().length;
    final totalReadMillis =
        selectedDateKey == null
            ? recordsForSummary.fold<int>(
              0,
              (sum, item) => sum + item.totalReadMillis,
            )
            : filteredDailyRecords.fold<int>(
              0,
              (sum, item) => sum + item.readMillis,
            );
    final totalReadChars =
        selectedDateKey == null
            ? recordsForSummary.fold<int>(
              0,
              (sum, item) => sum + item.totalReadChars,
            )
            : filteredDailyRecords.fold<int>(
              0,
              (sum, item) => sum + item.readChars,
            );
    final sessionCount = filteredSessions.length;
    final chapterCount =
        filteredSessions
            .map(_chapterDimensionKey)
            .whereType<String>()
            .toSet()
            .length;
    final title = selectedDateKey == null ? '累计阅读成就' : '$selectedDateKey 阅读概览';
    final subtitle =
        selectedDateKey == null
            ? (_searchKeyword.isEmpty
                ? '当前查看：$_viewLabel'
                : '当前查看：$_viewLabel · 搜索“$_searchKeyword”')
            : '当前查看：$_viewLabel · 已按日期过滤';

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
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (recordsForSummary.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  _buildSummaryCoverStack(recordsForSummary),
                ],
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final columns = maxWidth >= 620 ? 3 : 2;
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
                        icon: Icons.menu_book_rounded,
                        label: selectedDateKey == null ? '记录书籍' : '当日书籍',
                        value: '$totalBooks 本',
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _buildMetricTile(
                        icon: Icons.auto_stories_rounded,
                        label: selectedDateKey == null ? '累计时长' : '当日时长',
                        value: _formatDuration(totalReadMillis),
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _buildMetricTile(
                        icon: Icons.text_fields_rounded,
                        label: selectedDateKey == null ? '累计字数' : '当日字数',
                        value: _formatReadChars(totalReadChars),
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _buildMetricTile(
                        icon: Icons.timeline_rounded,
                        label: selectedDateKey == null ? '阅读会话' : '当日会话',
                        value: '$sessionCount 段',
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: _buildMetricTile(
                        icon: Icons.bookmarks_outlined,
                        label: selectedDateKey == null ? '触达章节' : '当日章节',
                        value: '$chapterCount 章',
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

  Widget _buildViewPill({required IconData icon, required String label}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
    required List<ReadingRecordDay> dailyRecords,
    required List<ReadingRecord> allLatestRecords,
    required List<ReadingRecordSession> sessions,
  }) {
    return switch (_view) {
      _ReadingRecordsView.latest => _buildLatestSection(latestRecords),
      _ReadingRecordsView.daily => _buildDailySection(
        dailyRecords,
        allLatestRecords: allLatestRecords,
      ),
      _ReadingRecordsView.timeline => _buildTimelineSection(sessions),
    };
  }

  Widget _buildLatestSection(List<ReadingRecord> records) {
    if (records.isEmpty) {
      return _buildEmptyCard(
        _selectedDateKey == null ? '还没有阅读记录。' : '选中的日期下没有最近阅读记录。',
      );
    }

    return Column(
      children: [
        _buildSectionHeading('最近阅读', subtitle: '按最后阅读时间排序'),
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
                      _buildCover(record.coverUrl),
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
                        width: 84,
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
                            _buildCompactTrailingAction(
                              tooltip: '合并记录',
                              icon: Icons.merge_type_rounded,
                              onTap: () => unawaited(_mergeRecord(record)),
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

  Widget _buildDailySection(
    List<ReadingRecordDay> days, {
    required List<ReadingRecord> allLatestRecords,
  }) {
    if (days.isEmpty) {
      return _buildEmptyCard(
        _selectedDateKey == null ? '还没有按天汇总的阅读记录。' : '选中的日期下没有按天汇总记录。',
      );
    }

    final latestByBookId = <String, ReadingRecord>{
      for (final record in allLatestRecords) record.bookId: record,
    };
    final grouped = <String, List<ReadingRecordDay>>{};
    for (final day in days) {
      grouped.putIfAbsent(day.dateKey, () => <ReadingRecordDay>[]).add(day);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries
          .map((entry) {
            final total = entry.value.fold<int>(
              0,
              (sum, item) => sum + item.readMillis,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeading(
                    entry.key,
                    subtitle: _formatDuration(total),
                  ),
                  for (final item in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Dismissible(
                        key: ValueKey(
                          'reading_day_${item.bookId}_${item.dateKey}',
                        ),
                        direction: DismissDirection.endToStart,
                        background: _buildDismissibleDeleteBackground(),
                        confirmDismiss: (_) async {
                          final confirmed = await _confirmDelete(
                            title: '删除当日记录',
                            message:
                                '将删除《${item.bookTitle}》在 ${item.dateKey} 的阅读记录。',
                          );
                          if (!confirmed) {
                            return false;
                          }
                          final snapshot = await _readingRecordService
                              .deleteDayRecordWithSnapshot(item);
                          if (snapshot == null) {
                            return false;
                          }
                          if (mounted) {
                            unawaited(
                              _showUndoSnackBar(
                                message:
                                    '已删除《${item.bookTitle}》在 ${item.dateKey} 的阅读记录。',
                                onUndo:
                                    () => _readingRecordService
                                        .restoreDeletedDayRecord(snapshot),
                              ),
                            );
                          }
                          return true;
                        },
                        child: _buildRecordSurface(
                          InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              final latest = latestByBookId[item.bookId];
                              if (latest != null) {
                                unawaited(_openRecord(latest));
                                return;
                              }
                              context.push('/book/${item.bookId}');
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  _buildCover(
                                    item.coverUrl,
                                    width: 42,
                                    height: 58,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item.bookTitle),
                                        Text(
                                          item.bookAuthor?.trim().isNotEmpty ==
                                                  true
                                              ? item.bookAuthor!.trim()
                                              : '未知作者',
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                        ),
                                        Text(
                                          '阅读字数 ${_formatReadChars(item.readChars)}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelSmall?.copyWith(
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
                                  Text(
                                    _formatDuration(item.readMillis),
                                    style:
                                        Theme.of(context).textTheme.labelMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildTimelineSection(List<ReadingRecordSession> sessions) {
    if (sessions.isEmpty) {
      return _buildEmptyCard(
        _selectedDateKey == null ? '还没有时间线阅读记录。' : '选中的日期下没有时间线阅读记录。',
      );
    }

    final grouped = <String, List<ReadingRecordSession>>{};
    for (final session in sessions) {
      final dateKey = _dateKeyFor(session.endAt);
      grouped.putIfAbsent(dateKey, () => <ReadingRecordSession>[]).add(session);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries
          .map((entry) {
            final total = entry.value.fold<int>(
              0,
              (sum, item) => sum + item.durationMillis,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeading(
                    entry.key,
                    subtitle: _formatDuration(total),
                  ),
                  for (final session in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Dismissible(
                        key: ValueKey('reading_session_${session.id}'),
                        direction: DismissDirection.endToStart,
                        background: _buildDismissibleDeleteBackground(),
                        confirmDismiss: (_) async {
                          final confirmed = await _confirmDelete(
                            title: '删除阅读会话',
                            message:
                                '将删除《${session.bookTitle}》的一条阅读会话，并自动重算统计。',
                          );
                          if (!confirmed) {
                            return false;
                          }
                          final snapshot = await _readingRecordService
                              .deleteSessionWithSnapshot(session);
                          if (snapshot == null) {
                            return false;
                          }
                          if (mounted) {
                            unawaited(
                              _showUndoSnackBar(
                                message: '已删除一条阅读会话。',
                                onUndo:
                                    () => _readingRecordService
                                        .restoreDeletedSession(snapshot),
                              ),
                            );
                          }
                          return true;
                        },
                        child: _buildRecordSurface(
                          InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _openSessionRecord(session),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCover(
                                    session.coverUrl,
                                    width: 42,
                                    height: 58,
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatTime(session.startAt),
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.labelLarge,
                                      ),
                                      Text(
                                        _formatTime(session.endAt),
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(session.bookTitle),
                                        Text(
                                          session.bookAuthor
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true
                                              ? session.bookAuthor!.trim()
                                              : '未知作者',
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _timelineSubtitle(session),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelSmall?.copyWith(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        Text(
                                          '阅读字数 ${_formatReadChars(session.readChars)}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelSmall?.copyWith(
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
                                  Text(
                                    _formatDuration(session.durationMillis),
                                    style:
                                        Theme.of(context).textTheme.labelMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          })
          .toList(growable: false),
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
    double width = 54,
    double height = 74,
  }) {
    final uri = Uri.tryParse(coverUrl ?? '');
    if (uri == null || !uri.hasScheme) {
      return _buildCoverFallback(width: width, height: height);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DiskCachedCoverImage(
        imageUrl: coverUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        fallback: _buildCoverFallback(width: width, height: height),
      ),
    );
  }

  Widget _buildCoverFallback({required double width, required double height}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.menu_book_outlined,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  List<ReadingRecord> _filterLatestRecords(
    List<ReadingRecord> latestRecords,
    List<ReadingRecordDay> allDays,
  ) {
    final selectedDateKey = _selectedDateKey;
    if (selectedDateKey == null) {
      return latestRecords;
    }
    final bookIds =
        allDays
            .where((item) => item.dateKey == selectedDateKey)
            .map((item) => item.bookId)
            .toSet();
    return latestRecords
        .where((item) => bookIds.contains(item.bookId))
        .toList(growable: false);
  }

  List<ReadingRecordDay> _filterDailyRecords(List<ReadingRecordDay> allDays) {
    final selectedDateKey = _selectedDateKey;
    if (selectedDateKey == null) {
      return allDays;
    }
    return allDays
        .where((item) => item.dateKey == selectedDateKey)
        .toList(growable: false);
  }

  List<ReadingRecordSession> _filterSessions(
    List<ReadingRecordSession> sessions,
  ) {
    final selectedDateKey = _selectedDateKey;
    if (selectedDateKey == null) {
      return sessions;
    }
    return sessions
        .where((item) => _dateKeyFor(item.endAt) == selectedDateKey)
        .toList(growable: false);
  }

  List<ReadingRecordSession> _mergeTimelineSessions(
    List<ReadingRecordSession> sessions,
  ) {
    if (sessions.length <= 1) {
      return sessions;
    }

    final sorted = List<ReadingRecordSession>.from(sessions)
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final merged = <ReadingRecordSession>[];
    const gapLimit = Duration(minutes: 20);

    for (final session in sorted) {
      if (merged.isEmpty) {
        merged.add(session);
        continue;
      }

      final last = merged.last;
      final sameBook = last.bookId == session.bookId;
      final sameDate = _dateKeyFor(last.endAt) == _dateKeyFor(session.endAt);
      final closeEnough =
          session.startAt.difference(last.endAt) <= gapLimit &&
          !session.startAt.isBefore(last.endAt);

      if (!sameBook || !sameDate || !closeEnough) {
        merged.add(session);
        continue;
      }

      merged[merged.length - 1] = ReadingRecordSession(
        id: last.id,
        bookId: last.bookId,
        sourceId: last.sourceId,
        detailUrl: last.detailUrl,
        bookTitle: last.bookTitle,
        bookAuthor: last.bookAuthor,
        coverUrl: last.coverUrl,
        chapterId: session.chapterId ?? last.chapterId,
        chapterTitle: session.chapterTitle ?? last.chapterTitle,
        chapterIndex: session.chapterIndex ?? last.chapterIndex,
        chapterUrl: session.chapterUrl ?? last.chapterUrl,
        startAt: last.startAt,
        endAt: session.endAt.isAfter(last.endAt) ? session.endAt : last.endAt,
        durationMillis:
            (last.durationMillis < 0 ? 0 : last.durationMillis) +
            (session.durationMillis < 0 ? 0 : session.durationMillis),
        readChars:
            (last.readChars < 0 ? 0 : last.readChars) +
            (session.readChars < 0 ? 0 : session.readChars),
        startPositionRatio: last.startPositionRatio,
        endPositionRatio: session.endPositionRatio,
      );
    }

    return merged.reversed.toList(growable: false);
  }

  String? _chapterDimensionKey(ReadingRecordSession session) {
    final chapterIndex = session.chapterIndex;
    if (chapterIndex != null && chapterIndex >= 0) {
      return '${session.bookId}#$chapterIndex';
    }
    final chapterTitle = session.chapterTitle?.trim();
    if (chapterTitle != null && chapterTitle.isNotEmpty) {
      return '${session.bookId}@$chapterTitle';
    }
    return null;
  }

  Map<String, _DailyHeatmapStat> _buildHeatmapStats(
    List<ReadingRecordDay> allDays,
  ) {
    final result = <String, _DailyHeatmapStat>{};
    for (final item in allDays) {
      final current = result[item.dateKey];
      result[item.dateKey] = _DailyHeatmapStat(
        bookCount: (current?.bookCount ?? 0) + 1,
        readMillis: (current?.readMillis ?? 0) + item.readMillis,
      );
    }
    return result;
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
      final weekMonth = DateTime(week.first.year, week.first.month);
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

  String _timelineSubtitle(ReadingRecordSession session) {
    final chapterTitle = session.chapterTitle?.trim();
    if (chapterTitle != null && chapterTitle.isNotEmpty) {
      return chapterTitle;
    }
    final chapterIndex = session.chapterIndex;
    if (chapterIndex != null && chapterIndex >= 0) {
      return '第 ${chapterIndex + 1} 章';
    }
    return '未记录章节信息';
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

  String _formatDateTime(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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

class _DailyHeatmapStat {
  const _DailyHeatmapStat({required this.bookCount, required this.readMillis});

  final int bookCount;
  final int readMillis;
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
