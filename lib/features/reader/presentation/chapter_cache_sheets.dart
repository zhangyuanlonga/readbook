import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/entities/chapter.dart';
import '../application/chapter_cache_service.dart';

class ChapterCacheEntryPoint {
  const ChapterCacheEntryPoint._(this.name);

  final String name;

  static const ChapterCacheEntryPoint detail = ChapterCacheEntryPoint._(
    'detail',
  );
  static const ChapterCacheEntryPoint reader = ChapterCacheEntryPoint._(
    'reader',
  );
}

Future<void> showChapterCacheFlow({
  required BuildContext context,
  required String bookId,
  required String sourceId,
  required List<Chapter> chapters,
  required int initialStartIndex,
  required int initialEndIndex,
  required ChapterCacheEntryPoint entryPoint,
  String? bookTitle,
}) async {
  if (chapters.isEmpty) {
    return;
  }

  final total = chapters.length;
  final start = initialStartIndex.clamp(0, total - 1);
  final end = initialEndIndex.clamp(0, total - 1);

  final range = await showModalBottomSheet<_ChapterCacheRange>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return _ChapterCacheRangeSheet(
        totalChapters: total,
        chapters: chapters,
        initialStartIndex: start,
        initialEndIndex: end,
        bookTitle: bookTitle,
      );
    },
  );

  if (range == null) {
    return;
  }

  if (!context.mounted) {
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _ChapterCacheProgressSheet(
        bookId: bookId,
        sourceId: sourceId,
        chapters: chapters,
        startIndex: range.startIndex,
        endIndex: range.endIndex,
        entryPoint: entryPoint,
        bookTitle: bookTitle,
      );
    },
  );
}

class _ChapterCacheRange {
  const _ChapterCacheRange({required this.startIndex, required this.endIndex});

  final int startIndex;
  final int endIndex;
}

class _ChapterCacheRangeSheet extends StatefulWidget {
  const _ChapterCacheRangeSheet({
    required this.totalChapters,
    required this.chapters,
    required this.initialStartIndex,
    required this.initialEndIndex,
    this.bookTitle,
  });

  final int totalChapters;
  final List<Chapter> chapters;
  final int initialStartIndex;
  final int initialEndIndex;
  final String? bookTitle;

  @override
  State<_ChapterCacheRangeSheet> createState() =>
      _ChapterCacheRangeSheetState();
}

class _ChapterCacheRangeSheetState extends State<_ChapterCacheRangeSheet> {
  late int _startIndex;
  late int _endIndex;

  @override
  void initState() {
    super.initState();
    _startIndex = widget.initialStartIndex;
    _endIndex = widget.initialEndIndex;
    if (_startIndex > _endIndex) {
      final tmp = _startIndex;
      _startIndex = _endIndex;
      _endIndex = tmp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = widget.bookTitle?.trim();

    final selectedCount = _endIndex - _startIndex + 1;
    final startLabel = _chapterLabel(_startIndex);
    final endLabel = _chapterLabel(_endIndex);

    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 10,
        bottom: 18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '缓存章节',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (title != null && title.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$startLabel - $endLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$selectedCount 章',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  RangeSlider(
                    min: 0,
                    max: max(0, widget.totalChapters - 1).toDouble(),
                    values: RangeValues(
                      _startIndex.toDouble(),
                      _endIndex.toDouble(),
                    ),
                    labels: RangeLabels(startLabel, endLabel),
                    onChanged: (values) {
                      setState(() {
                        final newStart = values.start.round().clamp(
                          0,
                          widget.totalChapters - 1,
                        );
                        final newEnd = values.end.round().clamp(
                          0,
                          widget.totalChapters - 1,
                        );
                        _startIndex = min(newStart, newEnd);
                        _endIndex = max(newStart, newEnd);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStepper(
                          label: '起始',
                          value: _startIndex,
                          minValue: 0,
                          maxValue: _endIndex,
                          onChanged: (value) {
                            setState(() {
                              _startIndex = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStepper(
                          label: '结束',
                          value: _endIndex,
                          minValue: _startIndex,
                          maxValue: widget.totalChapters - 1,
                          onChanged: (value) {
                            setState(() {
                              _endIndex = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      _ChapterCacheRange(
                        startIndex: _startIndex,
                        endIndex: _endIndex,
                      ),
                    );
                  },
                  child: const Text('开始缓存'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepper({
    required String label,
    required int value,
    required int minValue,
    required int maxValue,
    required ValueChanged<int> onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      value <= minValue ? null : () => onChanged(value - 1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Expanded(
                  child: Text(
                    _chapterLabel(value),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      value >= maxValue ? null : () => onChanged(value + 1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _chapterLabel(int index) {
    final chapterNumber = index + 1;
    final title = widget.chapters[index].title.trim();
    if (title.isEmpty) {
      return '第 $chapterNumber 章';
    }
    return '第 $chapterNumber 章 $title';
  }
}

class _ChapterCacheProgressSheet extends StatefulWidget {
  const _ChapterCacheProgressSheet({
    required this.bookId,
    required this.sourceId,
    required this.chapters,
    required this.startIndex,
    required this.endIndex,
    required this.entryPoint,
    this.bookTitle,
  });

  final String bookId;
  final String sourceId;
  final List<Chapter> chapters;
  final int startIndex;
  final int endIndex;
  final ChapterCacheEntryPoint entryPoint;
  final String? bookTitle;

  @override
  State<_ChapterCacheProgressSheet> createState() =>
      _ChapterCacheProgressSheetState();
}

class _ChapterCacheProgressSheetState
    extends State<_ChapterCacheProgressSheet> {
  final ChapterCacheService _service = ChapterCacheService();
  final ChapterCacheCancellationToken _token = ChapterCacheCancellationToken();

  StreamSubscription<ChapterCacheProgress>? _subscription;
  ChapterCacheProgress? _progress;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _subscription = _service
        .cacheRange(
          bookId: widget.bookId,
          sourceId: widget.sourceId,
          chapters: widget.chapters,
          startIndex: widget.startIndex,
          endIndex: widget.endIndex,
          cancellationToken: _token,
        )
        .listen((progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _progress = progress;
          });
        });
  }

  @override
  void dispose() {
    _token.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = widget.bookTitle?.trim();

    final progress = _progress;
    final done = progress?.done ?? 0;
    final total =
        progress?.total ?? max(0, widget.endIndex - widget.startIndex + 1);
    final failed = progress?.failed ?? 0;

    final ratio = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

    final statusText = _buildStatusText(progress);
    final canClose =
        progress?.isCompleted == true || progress?.isCancelled == true;

    return PopScope(
      canPop: canClose,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '正在缓存',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (title != null && title.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            value: canClose ? 1 : ratio,
                            strokeWidth: 2.4,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            statusText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: canClose ? 1 : ratio,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '进度: $done/$total  ·  失败: $failed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (progress?.currentChapterTitle?.trim().isNotEmpty ==
                        true)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          progress!.currentChapterTitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        canClose
                            ? null
                            : () {
                              setState(() {
                                _token.cancel();
                              });
                            },
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('停止'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        canClose && !_closing
                            ? () {
                              setState(() {
                                _closing = true;
                              });
                              Navigator.of(context).pop();
                            }
                            : null,
                    child: Text(canClose ? '完成' : '缓存中...'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.entryPoint == ChapterCacheEntryPoint.reader
                  ? '提示：可在阅读页继续阅读，缓存将在当前窗口进行。'
                  : '提示：缓存过程会持续占用网络，建议在 Wi-Fi 下使用。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildStatusText(ChapterCacheProgress? progress) {
    if (progress == null) {
      return '准备中...';
    }

    if (progress.isCancelled) {
      return '已停止';
    }

    if (progress.isCompleted) {
      if (progress.failed > 0) {
        return '缓存完成（部分失败）';
      }
      return '缓存完成';
    }

    return '缓存中...';
  }
}
