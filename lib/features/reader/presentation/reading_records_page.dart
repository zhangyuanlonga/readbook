import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reading_record_day.dart';
import '../application/reader_preferences_service.dart';
import '../application/reading_record_service.dart';

enum _ReadingRecordsView { latest, daily }

class ReadingRecordsPage extends StatefulWidget {
  const ReadingRecordsPage({super.key});

  @override
  State<ReadingRecordsPage> createState() => _ReadingRecordsPageState();
}

class _ReadingRecordsPageState extends State<ReadingRecordsPage> {
  final ReadingRecordService _readingRecordService = ReadingRecordService();
  final ReaderPreferencesService _preferencesService =
      ReaderPreferencesService();
  final TextEditingController _searchController = TextEditingController();

  String _searchKeyword = '';
  _ReadingRecordsView _view = _ReadingRecordsView.latest;

  @override
  void initState() {
    super.initState();
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

    final route =
        Uri(
          path: '/book/${record.bookId}',
          queryParameters: <String, String>{
            'sourceId': record.sourceId,
            'detailUrl': record.detailUrl,
            'title': record.bookTitle,
          },
        ).toString();
    context.push(route);
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
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  12,
                  horizontal,
                  12 + bottomSafe,
                ),
                children: [
                  _buildControlsCard(),
                  const SizedBox(height: 12),
                  StreamBuilder<int>(
                    stream: _readingRecordService.watchTotalReadMillis(),
                    builder: (context, snapshot) {
                      return _buildSummaryCard(snapshot.data ?? 0);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_view == _ReadingRecordsView.latest)
                    StreamBuilder<List<ReadingRecord>>(
                      stream: _readingRecordService.watchLatestRecords(
                        query: _searchKeyword,
                      ),
                      builder: (context, snapshot) {
                        final records =
                            snapshot.data ?? const <ReadingRecord>[];
                        return _buildLatestSection(records);
                      },
                    )
                  else
                    StreamBuilder<List<ReadingRecordDay>>(
                      stream: _readingRecordService.watchDailyRecords(
                        query: _searchKeyword,
                      ),
                      builder: (context, snapshot) {
                        final days =
                            snapshot.data ?? const <ReadingRecordDay>[];
                        return _buildDailySection(days);
                      },
                    ),
                ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(int totalReadMillis) {
    final hours = totalReadMillis ~/ Duration.millisecondsPerHour;
    final minutes =
        (totalReadMillis % Duration.millisecondsPerHour) ~/
        Duration.millisecondsPerMinute;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.auto_stories_rounded),
        title: const Text('累计阅读时长'),
        subtitle: Text('$hours 小时 $minutes 分钟'),
      ),
    );
  }

  Widget _buildLatestSection(List<ReadingRecord> records) {
    if (records.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(20), child: Text('还没有阅读记录。')),
      );
    }

    return Column(
      children: [
        for (final record in records) ...[
          Card(
            child: ListTile(
              onTap: () => _openRecord(record),
              title: Text(record.bookTitle),
              subtitle: Text(
                '${record.bookAuthor?.trim().isNotEmpty == true ? record.bookAuthor!.trim() : '未知作者'}\n'
                '最近阅读：${record.lastChapterTitle ?? '未知章节'} · ${_formatDateTime(record.lastReadAt)}',
              ),
              isThreeLine: true,
              trailing: Text(_formatDuration(record.totalReadMillis)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildDailySection(List<ReadingRecordDay> days) {
    if (days.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('还没有按天汇总的阅读记录。'),
        ),
      );
    }

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
            return Card(
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
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.bookTitle),
                                  Text(
                                    item.bookAuthor?.trim().isNotEmpty == true
                                        ? item.bookAuthor!.trim()
                                        : '未知作者',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(_formatDuration(item.readMillis)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  String _formatDuration(int millis) {
    final minutes = millis ~/ Duration.millisecondsPerMinute;
    if (minutes < 60) {
      return '$minutes 分钟';
    }
    final hours = minutes ~/ 60;
    final remainMinutes = minutes % 60;
    return remainMinutes == 0 ? '$hours 小时' : '$hours 小时 $remainMinutes 分钟';
  }

  String _formatDateTime(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}
