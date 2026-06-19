import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/layout/app_adaptive.dart';
import '../../../../app/widgets/foundation/foundation.dart';
import '../../application/private_book_source_service.dart';

enum _SourceTestMode {
  main('主链路', <String>['domain', 'search', 'info', 'toc', 'content']),
  discovery('发现', <String>['domain', 'discovery', 'info', 'toc', 'content']),
  custom('自定义', <String>['domain', 'search']);

  const _SourceTestMode(this.label, this.items);

  final String label;
  final List<String> items;
}

class PrivateBookSourceTestConfig {
  const PrivateBookSourceTestConfig({
    required this.keyword,
    required this.timeoutMs,
    required this.checkItems,
  });

  final String keyword;
  final int timeoutMs;
  final List<String> checkItems;
}

class PrivateBookSourceTestConfigSheet extends StatefulWidget {
  const PrivateBookSourceTestConfigSheet({super.key, required this.item});

  final PrivateBookSourceItem item;

  @override
  State<PrivateBookSourceTestConfigSheet> createState() =>
      PrivateBookSourceTestConfigSheetState();
}

class PrivateBookSourceTestConfigSheetState
    extends State<PrivateBookSourceTestConfigSheet> {
  final TextEditingController _keywordController = TextEditingController();
  _SourceTestMode _mode = _SourceTestMode.main;
  int _timeoutMs = 30000;
  late Set<String> _checkItems = _SourceTestMode.main.items.toSet();

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = AppAdaptiveMetrics.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.pagePadding,
        metrics.contentGap,
        metrics.pagePadding,
        bottomInset + metrics.sectionGap,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('检测书源', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                widget.item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              SegmentedButton<_SourceTestMode>(
                segments: const <ButtonSegment<_SourceTestMode>>[
                  ButtonSegment(
                    value: _SourceTestMode.main,
                    label: Text('主链路'),
                    icon: Icon(Icons.route_outlined),
                  ),
                  ButtonSegment(
                    value: _SourceTestMode.discovery,
                    label: Text('发现'),
                    icon: Icon(Icons.explore_outlined),
                  ),
                  ButtonSegment(
                    value: _SourceTestMode.custom,
                    label: Text('自定义'),
                    icon: Icon(Icons.tune_rounded),
                  ),
                ],
                selected: <_SourceTestMode>{_mode},
                onSelectionChanged: (values) {
                  final value = values.first;
                  setState(() {
                    _mode = value;
                    if (value != _SourceTestMode.custom) {
                      _checkItems = value.items.toSet();
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _keywordController,
                decoration: const InputDecoration(
                  labelText: '检测关键字',
                  hintText: '为空时使用书源内置关键字',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 14),
              AppDropdownField<int>(
                value: _timeoutMs,
                labelText: '超时',
                leadingIcon: const Icon(Icons.timer_outlined),
                options: const [
                  AppDropdownOption(value: 12000, label: '12 秒'),
                  AppDropdownOption(value: 30000, label: '30 秒'),
                  AppDropdownOption(value: 60000, label: '60 秒'),
                  AppDropdownOption(value: 90000, label: '90 秒'),
                ],
                onSelected: (value) {
                  if (value != null) {
                    setState(() => _timeoutMs = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              Text('检测过程', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final item in const <String>[
                    'domain',
                    'search',
                    'discovery',
                    'info',
                    'toc',
                    'content',
                  ])
                    FilterChip(
                      label: Text(_checkItemLabel(item)),
                      selected: _checkItems.contains(item),
                      onSelected:
                          _mode == _SourceTestMode.custom
                              ? (selected) {
                                setState(() {
                                  if (selected) {
                                    _checkItems.add(item);
                                  } else {
                                    _checkItems.remove(item);
                                  }
                                });
                              }
                              : null,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed:
                        _checkItems.isEmpty
                            ? null
                            : () => Navigator.of(context).pop(
                              PrivateBookSourceTestConfig(
                                keyword: _keywordController.text.trim(),
                                timeoutMs: _timeoutMs,
                                checkItems: _orderedCheckItems(_checkItems),
                              ),
                            ),
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('开始检测'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PrivateBookSourceCheckReportSheet extends StatelessWidget {
  const PrivateBookSourceCheckReportSheet({super.key, required this.report});

  final SourceCheckReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    final summary = report.summary;
    final title = summary.valid ? '检测通过' : '检测失败';
    final summaryMessage = summary.message.trim();
    final showSummaryMessage =
        summaryMessage.isNotEmpty && summaryMessage != title;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.pagePadding,
        metrics.contentGap,
        metrics.pagePadding,
        metrics.sectionGap,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  summary.valid
                      ? Icons.check_circle_rounded
                      : Icons.error_rounded,
                  color:
                      summary.valid ? colorScheme.primary : colorScheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                if (summary.sourceName.isNotEmpty) summary.sourceName,
                if (summary.mode.isNotEmpty) summary.mode,
                if (summary.keyword.isNotEmpty) '关键字 ${summary.keyword}',
                if (summary.elapsedMs > 0) _formatDurationMs(summary.elapsedMs),
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (showSummaryMessage) ...<Widget>[
              const SizedBox(height: 10),
              Text(summaryMessage, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 14),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child:
                    report.logs.isEmpty
                        ? _SourceCheckEmptyLogSummary(
                          message:
                              summaryMessage.isNotEmpty
                                  ? summaryMessage
                                  : '检测报告日志为空，请复制原始结果继续定位。',
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: report.logs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            return _SourceCheckLogRow(
                              entry: report.logs[index],
                            );
                          },
                        ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed:
                      report.copyText.trim().isEmpty
                          ? null
                          : () {
                            Clipboard.setData(
                              ClipboardData(text: report.copyText),
                            );
                            AppFeedback.showSnackBar(
                              context,
                              message: '检测日志已复制',
                              tone: AppFeedbackTone.success,
                              useHaptics: false,
                            );
                          },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('复制日志'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceCheckLogRow extends StatelessWidget {
  const _SourceCheckLogRow({required this.entry});

  final SourceCheckLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = switch (entry.level) {
      'success' => colorScheme.primary,
      'error' => colorScheme.error,
      'muted' => colorScheme.onSurfaceVariant,
      _ => colorScheme.onSurface,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          entry.direction == 'in' ? '<-' : '->',
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                entry.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (entry.details.isNotEmpty)
                _SourceCheckLogDetails(details: entry.details),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '[${_formatLogTime(entry.timeMs)}]',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SourceCheckEmptyLogSummary extends StatelessWidget {
  const _SourceCheckEmptyLogSummary({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = colorScheme.error;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.warning_amber_rounded, color: color, size: 34),
            const SizedBox(height: 10),
            Text(
              '检测报告日志为空',
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceCheckLogDetails extends StatelessWidget {
  const _SourceCheckLogDetails({required this.details});

  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final pendingCompact = <_SourceCheckDetail>[];
    void flushCompact() {
      if (pendingCompact.isEmpty) {
        return;
      }
      children.add(_SourceCheckCompactDetails(items: List.of(pendingCompact)));
      pendingCompact.clear();
    }

    for (final raw in details) {
      final detail = _SourceCheckDetail.parse(raw);
      if (detail.isCompact) {
        pendingCompact.add(detail);
      } else {
        flushCompact();
        children.add(_SourceCheckLongDetail(detail: detail));
      }
    }
    flushCompact();

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .expand((child) => <Widget>[child, const SizedBox(height: 5)])
            .take(children.length * 2 - 1)
            .toList(growable: false),
      ),
    );
  }
}

class _SourceCheckCompactDetails extends StatelessWidget {
  const _SourceCheckCompactDetails({required this.items});

  final List<_SourceCheckDetail> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth >= 280 ? 14.0 : 8.0;
        final itemWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: 4,
          children: <Widget>[
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _SourceCheckInfoText(item: item, maxLines: 1),
              ),
          ],
        );
      },
    );
  }
}

class _SourceCheckLongDetail extends StatelessWidget {
  const _SourceCheckLongDetail({required this.detail});

  final _SourceCheckDetail detail;

  @override
  Widget build(BuildContext context) {
    return _SourceCheckInfoText(item: detail, maxLines: 4);
  }
}

class _SourceCheckInfoText extends StatelessWidget {
  const _SourceCheckInfoText({required this.item, required this.maxLines});

  final _SourceCheckDetail item;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    if (item.label.isEmpty) {
      return Text(
        item.value,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: labelStyle,
      );
    }
    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: labelStyle,
        children: <InlineSpan>[
          TextSpan(text: '${item.label}：'),
          TextSpan(text: item.value, style: valueStyle),
        ],
      ),
    );
  }
}

class _SourceCheckDetail {
  const _SourceCheckDetail({
    required this.label,
    required this.value,
    required this.isCompact,
  });

  final String label;
  final String value;
  final bool isCompact;

  factory _SourceCheckDetail.parse(String raw) {
    final text = raw.trim();
    final separator = _firstDetailSeparator(text);
    if (separator <= 0) {
      return _SourceCheckDetail(
        label: '',
        value: text,
        isCompact: _isCompactDetail('', text),
      );
    }
    final label = text.substring(0, separator).trim();
    final value = text.substring(separator + 1).trim();
    return _SourceCheckDetail(
      label: label,
      value: value,
      isCompact: _isCompactDetail(label, value),
    );
  }
}

int _firstDetailSeparator(String value) {
  final chinese = value.indexOf('：');
  final ascii = value.indexOf(':');
  if (chinese < 0) {
    return ascii;
  }
  if (ascii < 0) {
    return chinese;
  }
  return chinese < ascii ? chinese : ascii;
}

bool _isCompactDetail(String label, String value) {
  final lowerValue = value.toLowerCase();
  final lowerLabel = label.toLowerCase();
  if (value.contains('\n') ||
      lowerValue.contains('http://') ||
      lowerValue.contains('https://') ||
      lowerValue.startsWith('{') ||
      lowerValue.startsWith('[') ||
      lowerLabel.contains('url') ||
      label.contains('地址') ||
      label.contains('请求体') ||
      lowerLabel == 'body') {
    return false;
  }
  return value.runes.length <= 18;
}

String _checkItemLabel(String value) {
  return switch (value) {
    'domain' => '域名',
    'search' => '搜索',
    'discovery' => '发现',
    'info' => '详情',
    'toc' => '目录',
    'content' => '正文',
    _ => value,
  };
}

List<String> _orderedCheckItems(Set<String> values) {
  return const <String>[
    'domain',
    'search',
    'discovery',
    'info',
    'toc',
    'content',
  ].where(values.contains).toList(growable: false);
}

String _formatDurationMs(int value) {
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)} 秒';
  }
  return '$value ms';
}

String _formatLogTime(int value) {
  final minutes = value ~/ 60000;
  final seconds = (value % 60000) ~/ 1000;
  final millis = value % 1000;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
}
