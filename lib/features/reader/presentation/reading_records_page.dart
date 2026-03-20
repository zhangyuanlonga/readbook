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

class ReadingRecordsPage extends StatefulWidget {
  const ReadingRecordsPage({super.key});

  @override
  State<ReadingRecordsPage> createState() => _ReadingRecordsPageState();
}

class _ReadingRecordsPageState extends State<ReadingRecordsPage> {
  final ReadingRecordService _readingRecordService = ReadingRecordService();
  final ReaderPreferencesService _preferencesService =
      ReaderPreferencesService();
  final ReaderSystemSettingsService _readerSystemSettingsService =
      ReaderSystemSettingsService();
  final TextEditingController _searchController = TextEditingController();
  late final Future<bool> _readRecordEnabledFuture;

  String _searchKeyword = '';
  String? _selectedDateKey;
  _ReadingRecordsView _view = _ReadingRecordsView.latest;
  _HeatmapMetricMode _heatmapMode = _HeatmapMetricMode.duration;

  @override
  void initState() {
    super.initState();
    _readRecordEnabledFuture =
        _readerSystemSettingsService.loadReadRecordEnabled();
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
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _mergeRecord(ReadingRecord target) async {
    final candidates = await _readingRecordService.getMergeCandidates(target);
    if (!mounted) {
      return;
    }
    if (candidates.isEmpty) {
      _showMessage('没有可合并的同标题阅读记录。');
      return;
    }

    final selected = await showDialog<List<ReadingRecord>>(
      context: context,
      builder: (dialogContext) {
        final selectedBookIds = <String>{
          for (final item in candidates) item.bookId,
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
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 320,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final item in candidates)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: selectedBookIds.contains(item.bookId),
                                onChanged: (checked) {
                                  setDialogState(() {
                                    if (checked ?? false) {
                                      selectedBookIds.add(item.bookId);
                                    } else {
                                      selectedBookIds.remove(item.bookId);
                                    }
                                  });
                                },
                                title: Text(
                                  item.bookAuthor?.trim().isNotEmpty == true
                                      ? item.bookAuthor!.trim()
                                      : '未知作者',
                                ),
                                subtitle: Text(
                                  '${_formatDuration(item.totalReadMillis)} · ${_formatDateTime(item.lastReadAt)}',
                                ),
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
                        .where((item) => selectedBookIds.contains(item.bookId))
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

    await _readingRecordService.mergeRecords(target: target, sources: selected);
    if (!mounted) {
      return;
    }
    _showMessage('已合并 ${selected.length} 条阅读记录。');
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

    return Scaffold(
      appBar: AppBar(title: const Text('阅读记录')),
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
                              const SizedBox(height: 12),
                              _buildHeatmapCard(dailyRecords),
                              const SizedBox(height: 12),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
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
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<_ReadingRecordsView>(
              segments: const [
                ButtonSegment(
                  value: _ReadingRecordsView.latest,
                  icon: Icon(Icons.schedule_rounded),
                  label: Text('最近阅读'),
                ),
                ButtonSegment(
                  value: _ReadingRecordsView.daily,
                  icon: Icon(Icons.calendar_today_rounded),
                  label: Text('按天汇总'),
                ),
                ButtonSegment(
                  value: _ReadingRecordsView.timeline,
                  icon: Icon(Icons.timeline_rounded),
                  label: Text('时间线'),
                ),
              ],
              selected: <_ReadingRecordsView>{_view},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) {
                  return;
                }
                setState(() {
                  _view = selection.first;
                });
              },
            ),
            if (_selectedDateKey != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '已按 $_selectedDateKey 过滤',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
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
            const SizedBox(height: 12),
            FutureBuilder<bool>(
              future: _readRecordEnabledFuture,
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? true;
                final colorScheme = Theme.of(context).colorScheme;
                final backgroundColor =
                    enabled
                        ? colorScheme.surfaceContainerHighest
                        : colorScheme.tertiaryContainer;
                final foregroundColor =
                    enabled
                        ? colorScheme.onSurface
                        : colorScheme.onTertiaryContainer;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        enabled
                            ? Icons.history_toggle_off_rounded
                            : Icons.pause_circle_outline_rounded,
                        size: 18,
                        color:
                            enabled
                                ? colorScheme.primary
                                : colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          enabled ? '阅读记录正在自动累计。' : '阅读记录已关闭，当前不会继续新增记录。',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: foregroundColor, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapCard(List<ReadingRecordDay> allDays) {
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
    final startDate = _startOfWeek(
      today.subtract(
        Duration(
          days: math.max(0, today.difference(firstDate).inDays).clamp(0, 364),
        ),
      ),
    );
    final weeks = _buildHeatmapWeeks(startDate: startDate, endDate: today);
    final maxValue = statsByDate.values.fold<int>(
      0,
      (current, item) => math.max(
        current,
        _heatmapMode == _HeatmapMetricMode.duration
            ? item.readMillis
            : item.bookCount,
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '阅读热力图',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '点击某一天可过滤下方列表。',
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
                ChoiceChip(
                  label: const Text('按时长'),
                  selected: _heatmapMode == _HeatmapMetricMode.duration,
                  onSelected: (_) {
                    setState(() {
                      _heatmapMode = _HeatmapMetricMode.duration;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('按本数'),
                  selected: _heatmapMode == _HeatmapMetricMode.count,
                  onSelected: (_) {
                    setState(() {
                      _heatmapMode = _HeatmapMetricMode.count;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      children: const [
                        _WeekdayLabel('一'),
                        SizedBox(height: 4),
                        _WeekdayLabel('二'),
                        SizedBox(height: 4),
                        _WeekdayLabel('三'),
                        SizedBox(height: 4),
                        _WeekdayLabel('四'),
                        SizedBox(height: 4),
                        _WeekdayLabel('五'),
                        SizedBox(height: 4),
                        _WeekdayLabel('六'),
                        SizedBox(height: 4),
                        _WeekdayLabel('日'),
                      ],
                    ),
                  ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapCell({
    required DateTime day,
    required _DailyHeatmapStat? stats,
    required int maxValue,
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
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(5),
            border:
                isSelected
                    ? Border.all(color: colorScheme.primary, width: 1.5)
                    : Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.25),
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
              await _readingRecordService.deleteRecord(record);
              if (mounted) {
                _showMessage('已删除《${record.bookTitle}》的阅读记录。');
              }
              return true;
            },
            child: Card(
              child: ListTile(
                onTap: () => _openRecord(record),
                leading: _buildCover(record.coverUrl),
                title: Text(record.bookTitle),
                subtitle: Text(
                  '${record.bookAuthor?.trim().isNotEmpty == true ? record.bookAuthor!.trim() : '未知作者'}\n'
                  '最近阅读：${record.lastChapterTitle ?? '未知章节'} · ${_formatDateTime(record.lastReadAt)}\n'
                  '累计字数：${_formatReadChars(record.totalReadChars)}',
                ),
                isThreeLine: true,
                trailing: SizedBox(
                  width: 76,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatDuration(record.totalReadMillis),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      IconButton(
                        tooltip: '合并记录',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => unawaited(_mergeRecord(record)),
                        icon: const Icon(Icons.merge_type_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
      children: grouped.entries
          .map((entry) {
            final total = entry.value.fold<int>(
              0,
              (sum, item) => sum + item.readMillis,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.key} · ${_formatDuration(total)}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final item in entry.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
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
                              await _readingRecordService.deleteDayRecord(item);
                              if (mounted) {
                                _showMessage(
                                  '已删除《${item.bookTitle}》在 ${item.dateKey} 的阅读记录。',
                                );
                              }
                              return true;
                            },
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
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
                                  horizontal: 4,
                                  vertical: 6,
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
                                            item.bookAuthor
                                                        ?.trim()
                                                        .isNotEmpty ==
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
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDuration(item.readMillis),
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.labelMedium,
                                    ),
                                  ],
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
      children: grouped.entries
          .map((entry) {
            final total = entry.value.fold<int>(
              0,
              (sum, item) => sum + item.durationMillis,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.key} · ${_formatDuration(total)}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final session in entry.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
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
                              await _readingRecordService.deleteSession(
                                session,
                              );
                              if (mounted) {
                                _showMessage('已删除一条阅读会话。');
                              }
                              return true;
                            },
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _openSessionRecord(session),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
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
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                          ),
                                          Text(
                                            '阅读字数 ${_formatReadChars(session.readChars)}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelSmall?.copyWith(
                                              color:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDuration(session.durationMillis),
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.labelMedium,
                                    ),
                                  ],
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
          })
          .toList(growable: false),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(20), child: Text(message)),
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
