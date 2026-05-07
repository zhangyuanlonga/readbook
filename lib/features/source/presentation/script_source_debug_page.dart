import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/app_empty_state_card.dart';
import '../../../core/errors/app_exception.dart';
import '../../../runtime/host/appread_browser_runtime.dart';
import '../../../runtime/session/source_session.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../../runtime/sources/source_result_models.dart' as runtime_models;
import '../../../runtime/sources/source_script_compiler.dart';
import '../../mine/application/advanced_theme_provider.dart';
import '../application/source_runtime_facade.dart';
import '../application/source_check_service.dart';
import '../providers.dart';

part 'script_source_debug_page_run.dart';

class ScriptSourceDebugPage extends StatefulWidget {
  const ScriptSourceDebugPage({
    super.key,
    required this.sourceCode,
    this.sourceId,
    this.title,
    this.initialKeyword,
    this.autoRunOnInit = false,
  });

  final String sourceCode;
  final String? sourceId;
  final String? title;
  final String? initialKeyword;
  final bool autoRunOnInit;

  bool get useInstalledSourceFlow => sourceId?.trim().isNotEmpty == true;

  @override
  State<ScriptSourceDebugPage> createState() => _ScriptSourceDebugPageState();
}

class _ScriptSourceDebugPageState extends State<ScriptSourceDebugPage> {
  late final SourceRuntimeFacade _sourceRuntimeFacade;
  final SourceScriptDebugService _draftDebugService = SourceScriptDebugService(
    browserRuntime: AppReadBrowserRuntime(),
  );
  final SourceSession _draftSession = SourceSession(
    sourceId: '__script_debug__',
  );
  late final TextEditingController _keywordController = TextEditingController(
    text:
        widget.initialKeyword?.trim().isNotEmpty == true
            ? widget.initialKeyword!.trim()
            : SourceCheckService.defaultCheckKeyword,
  );

  SourceCheckLevel _selectedLevel = SourceCheckLevel.searchOnly;
  bool _isRunning = false;
  _RunReport? _report;

  @override
  void initState() {
    super.initState();
    _sourceRuntimeFacade = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(sourceRuntimeFacadeProvider);
    if (widget.autoRunOnInit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _runInspection();
      });
    }
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  void _updateDebugPageState(VoidCallback mutation) {
    if (!mounted) {
      return;
    }
    setState(mutation);
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        title: Text(
          widget.title?.trim().isNotEmpty == true ? widget.title! : '书源调试',
        ),
        actions: [
          TextButton.icon(
            onPressed: _isRunning ? null : _runInspection,
            icon:
                _isRunning
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(_isRunning ? '执行中' : '重新执行'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final activeTheme =
              ref.watch(activeAdvancedThemeProvider).valueOrNull;
          final backdrop = resolveAdvancedThemeBackdrop(
            Theme.of(context).colorScheme,
            activeTheme,
          );
          final horizontal = AppSpacing.pageHorizontal(context);
          final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
          final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
          final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
          return DecoratedBox(
            decoration: buildAdvancedThemeBackdropDecoration(backdrop),
            child: SafeArea(
              top: false,
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
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          topInset + 12,
                          horizontal,
                          16 + bottomSafe + keyboardInset,
                        ),
                        children: [
                          _DebugInputCard(
                            controller: _keywordController,
                            selectedLevel: _selectedLevel,
                            isRunning: _isRunning,
                            mode:
                                widget.useInstalledSourceFlow
                                    ? _DebugMode.installedSource
                                    : _DebugMode.draft,
                            onLevelChanged: (value) {
                              setState(() {
                                _selectedLevel = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          _SummaryCard(report: report),
                          const SizedBox(height: 12),
                          if (_isRunning && report == null)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 36),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (report == null)
                            const _EmptyState()
                          else
                            ...report.stages.map(
                              (stage) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _StageCard(
                                  stage: stage,
                                  formatJson: _formatJson,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _DebugMode { installedSource, draft }

enum _StageOutcome { success, empty, invalid, failed }

class _RunReport {
  const _RunReport({
    required this.mode,
    required this.keyword,
    required this.level,
    required this.sourceName,
    required this.summary,
    required this.stages,
  });

  final _DebugMode mode;
  final String keyword;
  final SourceCheckLevel level;
  final String sourceName;
  final _RunSummary summary;
  final List<_StageReport> stages;
}

class _RunSummary {
  const _RunSummary({
    required this.status,
    required this.stepReached,
    required this.message,
    required this.duration,
    required this.needsBrowser,
  });

  final SourceCheckStatus status;
  final SourceCheckStep stepReached;
  final String message;
  final Duration duration;
  final bool needsBrowser;
}

class _StageReport {
  const _StageReport({
    required this.step,
    required this.title,
    required this.outcome,
    required this.summary,
    required this.highlights,
    required this.payload,
    required this.entries,
    required this.rawLogs,
    required this.rawTraces,
    this.book,
    this.chapter,
  });

  final SourceCheckStep step;
  final String title;
  final _StageOutcome outcome;
  final String summary;
  final List<String> highlights;
  final Object? payload;
  final List<_TimelineEntry> entries;
  final List<Map<String, Object?>> rawLogs;
  final List<Map<String, Object?>> rawTraces;
  final runtime_models.Book? book;
  final runtime_models.Chapter? chapter;

  bool get isSuccess => outcome == _StageOutcome.success;
}

class _TimelineEntry {
  const _TimelineEntry({
    required this.offset,
    required this.message,
    this.detail,
    this.isError = false,
  });

  final Duration offset;
  final String message;
  final String? detail;
  final bool isError;
}

class _DraftStageSemantic {
  const _DraftStageSemantic._({
    required this.kind,
    required this.summary,
    this.highlights = const <String>[],
    this.extraEntries = const <_TimelineEntry>[],
  });

  final _StageOutcome kind;
  final String summary;
  final List<String> highlights;
  final List<_TimelineEntry> extraEntries;

  factory _DraftStageSemantic.success({
    required String summary,
    required List<String> highlights,
    List<_TimelineEntry> extraEntries = const <_TimelineEntry>[],
  }) {
    return _DraftStageSemantic._(
      kind: _StageOutcome.success,
      summary: summary,
      highlights: highlights,
      extraEntries: extraEntries,
    );
  }

  factory _DraftStageSemantic.empty(String summary) {
    return _DraftStageSemantic._(kind: _StageOutcome.empty, summary: summary);
  }

  factory _DraftStageSemantic.invalid(String summary) {
    return _DraftStageSemantic._(kind: _StageOutcome.invalid, summary: summary);
  }
}

class _DebugInputCard extends StatelessWidget {
  const _DebugInputCard({
    required this.controller,
    required this.selectedLevel,
    required this.isRunning,
    required this.mode,
    required this.onLevelChanged,
  });

  final TextEditingController controller;
  final SourceCheckLevel selectedLevel;
  final bool isRunning;
  final _DebugMode mode;
  final ValueChanged<SourceCheckLevel> onLevelChanged;

  @override
  Widget build(BuildContext context) {
    final modeLabel = switch (mode) {
      _DebugMode.installedSource => '标准检测模式',
      _DebugMode.draft => '草稿调试模式',
    };
    final helperText = switch (mode) {
      _DebugMode.installedSource => '执行逻辑会尽量贴近书源列表里的单源检测，顶部结论与外部检测保持同一心智。',
      _DebugMode.draft => '当前是草稿调试模式，会执行当前编辑中的脚本内容；结果不代表已安装书源的正式检测结论。',
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '调试参数',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Chip(label: Text(modeLabel)),
                    ],
                  ),
                ),
                _CopyCardButton(
                  text: _buildInputCardCopyText(
                    controller: controller,
                    selectedLevel: selectedLevel,
                    mode: mode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              helperText,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              enabled: !isRunning,
              decoration: const InputDecoration(
                labelText: '调试关键词',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SourceCheckLevel>(
              initialValue: selectedLevel,
              decoration: const InputDecoration(
                labelText: '检测级别',
                border: OutlineInputBorder(),
              ),
              items: SourceCheckLevel.values
                  .map(
                    (level) => DropdownMenuItem<SourceCheckLevel>(
                      value: level,
                      child: Text(_checkLevelLabel(level)),
                    ),
                  )
                  .toList(growable: false),
              onChanged:
                  isRunning
                      ? null
                      : (value) {
                        if (value != null) {
                          onLevelChanged(value);
                        }
                      },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report});

  final _RunReport? report;

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '调试结论',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const _CopyCardButton(
                    text: '输入关键词后执行调试，页面会先给出标准结论，再展开详细日志和阶段输出。',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '输入关键词后执行调试，页面会先给出标准结论，再展开详细日志和阶段输出。',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    final summary = report!.summary;
    final statusColor = switch (summary.status) {
      SourceCheckStatus.healthy => const Color(0xFF2E9B57),
      SourceCheckStatus.warning => const Color(0xFFB97A00),
      SourceCheckStatus.failed => const Color(0xFFD64545),
      SourceCheckStatus.skipped => const Color(0xFF6A7381),
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _checkStatusLabel(summary.status),
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _CopyCardButton(text: _buildSummaryCardCopyText(report!)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _SummaryChip(label: '关键词 ${report!.keyword}'),
                _SummaryChip(label: '级别 ${_checkLevelLabel(report!.level)}'),
                _SummaryChip(
                  label: '步骤 ${_checkStepLabel(summary.stepReached)}',
                ),
                _SummaryChip(label: '耗时 ${_formatDuration(summary.duration)}'),
                if (summary.needsBrowser) const _SummaryChip(label: '存在浏览器风险'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              summary.message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.stage, required this.formatJson});

  final _StageReport stage;
  final String Function(Object? value) formatJson;

  @override
  Widget build(BuildContext context) {
    final accent = switch (stage.outcome) {
      _StageOutcome.success => const Color(0xFF2E9B57),
      _StageOutcome.empty => const Color(0xFFE09A00),
      _StageOutcome.invalid => const Color(0xFFD27A00),
      _StageOutcome.failed => const Color(0xFFD64545),
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${stage.title} · ${_stageOutcomeLabel(stage.outcome)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                _CopyCardButton(
                  text: _buildStageCardCopyText(stage, formatJson),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              stage.summary,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            if (stage.highlights.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stage.highlights
                    .map((item) => _SummaryChip(label: item))
                    .toList(growable: false),
              ),
            ],
            if (stage.entries.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                '执行时间线',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: stage.entries
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TimelineRow(entry: entry),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('原始输出'),
              children: [_CodeLikeBlock(text: formatJson(stage.payload))],
            ),
            if (stage.rawLogs.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text('结构化日志 (${stage.rawLogs.length})'),
                children: [_CodeLikeBlock(text: formatJson(stage.rawLogs))],
              ),
            if (stage.rawTraces.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text('结构化轨迹 (${stage.rawTraces.length})'),
                children: [_CodeLikeBlock(text: formatJson(stage.rawTraces))],
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry});

  final _TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final detail = entry.detail?.trim() ?? '';
    final messageColor =
        entry.isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.onSurface;
    final mono = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.45);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '[${_formatOffset(entry.offset)}] ${entry.message}',
          style: mono?.copyWith(
            color: messageColor,
            fontWeight: entry.isError ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        if (detail.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Text(
              detail,
              style: mono?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _CodeLikeBlock extends StatelessWidget {
  const _CodeLikeBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.45),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  static const String _message =
      '还没有调试结果。\n\n建议先执行一次检测，页面会给出标准结论，并把搜索、详情、目录、正文的详细过程按时间线展示出来。';

  @override
  Widget build(BuildContext context) {
    return AppEmptyStateCard(
      icon: Icons.playlist_add_check_circle_outlined,
      title: '阶段明细',
      description: _message,
      centered: false,
      trailing: const _CopyCardButton(text: _message),
    );
  }
}

class _CopyCardButton extends StatelessWidget {
  const _CopyCardButton({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '复制',
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.content_copy_rounded, size: 18),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('已复制')));
      },
    );
  }
}

String _buildInputCardCopyText({
  required TextEditingController controller,
  required SourceCheckLevel selectedLevel,
  required _DebugMode mode,
}) {
  final modeLabel = switch (mode) {
    _DebugMode.installedSource => '标准检测模式',
    _DebugMode.draft => '草稿调试模式',
  };
  return [
    '调试参数',
    '模式：$modeLabel',
    '关键词：${controller.text.trim()}',
    '检测级别：${_checkLevelLabel(selectedLevel)}',
  ].join('\n');
}

String _buildSummaryCardCopyText(_RunReport report) {
  final summary = report.summary;
  return [
    '调试结论',
    '书源：${report.sourceName}',
    '关键词：${report.keyword}',
    '级别：${_checkLevelLabel(report.level)}',
    '状态：${_checkStatusLabel(summary.status)}',
    '步骤：${_checkStepLabel(summary.stepReached)}',
    '耗时：${_formatDuration(summary.duration)}',
    '浏览器风险：${summary.needsBrowser ? '是' : '否'}',
    '',
    summary.message,
  ].join('\n');
}

String _buildStageCardCopyText(
  _StageReport stage,
  String Function(Object? value) formatJson,
) {
  final buffer =
      StringBuffer()
        ..writeln('${stage.title} · ${_stageOutcomeLabel(stage.outcome)}')
        ..writeln(stage.summary);

  if (stage.highlights.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('亮点')
      ..writeln(stage.highlights.map((item) => '- $item').join('\n'));
  }

  if (stage.entries.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('执行时间线');
    for (final entry in stage.entries) {
      buffer.writeln('[${_formatOffset(entry.offset)}] ${entry.message}');
      final detail = entry.detail?.trim() ?? '';
      if (detail.isNotEmpty) {
        buffer.writeln('  $detail');
      }
    }
  }

  buffer
    ..writeln()
    ..writeln('原始输出')
    ..writeln(formatJson(stage.payload));

  if (stage.rawLogs.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('结构化日志')
      ..writeln(formatJson(stage.rawLogs));
  }

  if (stage.rawTraces.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('结构化轨迹')
      ..writeln(formatJson(stage.rawTraces));
  }

  return buffer.toString().trimRight();
}

String _checkLevelLabel(SourceCheckLevel level) {
  return switch (level) {
    SourceCheckLevel.searchOnly => '仅搜索',
    SourceCheckLevel.searchAndDetail => '搜索 + 详情',
    SourceCheckLevel.fullReadPath => '完整阅读链路',
  };
}

String _checkStatusLabel(SourceCheckStatus status) {
  return switch (status) {
    SourceCheckStatus.healthy => '检测通过',
    SourceCheckStatus.warning => '可用但有风险',
    SourceCheckStatus.failed => '检测失败',
    SourceCheckStatus.skipped => '已跳过',
  };
}

String _checkStepLabel(SourceCheckStep step) {
  return switch (step) {
    SourceCheckStep.none => '未开始',
    SourceCheckStep.search => '搜索',
    SourceCheckStep.detail => '详情',
    SourceCheckStep.chapters => '目录',
    SourceCheckStep.content => '正文',
  };
}

String _stageOutcomeLabel(_StageOutcome outcome) {
  return switch (outcome) {
    _StageOutcome.success => '成功',
    _StageOutcome.empty => '空结果',
    _StageOutcome.invalid => '结构异常',
    _StageOutcome.failed => '失败',
  };
}

String _formatDuration(Duration duration) {
  if (duration.inSeconds >= 1) {
    return '${duration.inMilliseconds / 1000}s';
  }
  return '${duration.inMilliseconds} ms';
}

String _formatOffset(Duration duration) {
  final totalMillis = duration.inMilliseconds.clamp(0, 359999999);
  final minutes = totalMillis ~/ 60000;
  final seconds = (totalMillis % 60000) ~/ 1000;
  final millis = totalMillis % 1000;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}.'
      '${millis.toString().padLeft(3, '0')}';
}
