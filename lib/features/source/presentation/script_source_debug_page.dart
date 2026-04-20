import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../runtime/host/appread_browser_runtime.dart';
import '../../../runtime/session/source_session.dart';
import '../../../runtime/sources/source_script_compiler.dart';

class ScriptSourceDebugPage extends StatefulWidget {
  const ScriptSourceDebugPage({
    super.key,
    required this.sourceCode,
    this.title,
    this.initialKeyword,
    this.autoRunOnInit = false,
  });

  final String sourceCode;
  final String? title;
  final String? initialKeyword;
  final bool autoRunOnInit;

  @override
  State<ScriptSourceDebugPage> createState() => _ScriptSourceDebugPageState();
}

class _ScriptSourceDebugPageState extends State<ScriptSourceDebugPage> {
  final SourceScriptDebugService _debugService = SourceScriptDebugService(
    browserRuntime: AppReadBrowserRuntime(),
  );
  final SourceSession _session = SourceSession(sourceId: '__script_debug__');
  late final TextEditingController _keywordController = TextEditingController(
    text:
        widget.initialKeyword?.trim().isNotEmpty == true
            ? widget.initialKeyword!.trim()
            : '斗罗大陆',
  );

  bool _isRunning = false;
  int _runningStageIndex = -1;
  Duration? _lastRunDuration;
  final List<_StageResult> _stageResults = <_StageResult>[];

  @override
  void initState() {
    super.initState();
    if (widget.autoRunOnInit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _runPipeline();
      });
    }
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  List<_DebugStageSpec> _buildStages(String keyword) {
    final encodedKeyword = jsonEncode(keyword);
    return <_DebugStageSpec>[
      _DebugStageSpec(
        index: 0,
        kind: _DebugStageKind.search,
        shortLabel: '搜索',
        title: '搜索结果',
        command: '''
const keyword = $encodedKeyword;
const books = await source.search(ctx, keyword);
console.log('search result', books);
return books;
''',
      ),
      _DebugStageSpec(
        index: 1,
        kind: _DebugStageKind.detail,
        shortLabel: '详情',
        title: '详情结果',
        command: '''
const keyword = $encodedKeyword;
const books = await source.search(ctx, keyword);
const first = books?.[0];
console.log('search first', first);
if (!first) return null;
const detail = await source.detail(ctx, first);
console.log('detail result', detail);
return detail;
''',
      ),
      _DebugStageSpec(
        index: 2,
        kind: _DebugStageKind.chapters,
        shortLabel: '目录',
        title: '目录结果',
        command: '''
const keyword = $encodedKeyword;
const books = await source.search(ctx, keyword);
const first = books?.[0];
if (!first) return null;
const detail = await source.detail(ctx, first);
const chapters = await source.chapters(ctx, detail);
console.log('chapters result', chapters);
return chapters;
''',
      ),
      _DebugStageSpec(
        index: 3,
        kind: _DebugStageKind.content,
        shortLabel: '正文',
        title: '正文结果',
        command: '''
const keyword = $encodedKeyword;
const books = await source.search(ctx, keyword);
const first = books?.[0];
if (!first) return null;
const detail = await source.detail(ctx, first);
const chapters = await source.chapters(ctx, detail);
const chapter = chapters?.[0];
if (!chapter) return null;
const content = await source.content(ctx, detail, chapter);
console.log('content result', content);
return content;
''',
      ),
    ];
  }

  Future<void> _runPipeline() async {
    final keyword = _keywordController.text.trim();
    if (_isRunning) {
      return;
    }
    if (keyword.isEmpty) {
      _showTransientMessage('请先填写调试关键词。');
      return;
    }

    final stages = _buildStages(keyword);
    final pipelineStopwatch = Stopwatch()..start();

    setState(() {
      _isRunning = true;
      _runningStageIndex = 0;
      _lastRunDuration = null;
      _stageResults.clear();
      _session.clear();
      _session.clearCookies();
    });

    final nextStageResults = <_StageResult>[];
    var traceOffset = 0;
    var shouldContinue = true;
    String? stopReason;

    for (final stage in stages) {
      if (!shouldContinue) {
        nextStageResults.add(
          _StageResult.skipped(
            stage: stage,
            summary: stopReason ?? '前一阶段未通过，后续阶段已跳过。',
          ),
        );
        if (mounted) {
          setState(() {
            _stageResults
              ..clear()
              ..addAll(nextStageResults);
          });
        }
        continue;
      }

      if (mounted) {
        setState(() {
          _runningStageIndex = stage.index;
        });
      }

      final stageStopwatch = Stopwatch()..start();
      final result = await _debugService.evaluate(
        sourceCode: widget.sourceCode,
        command: stage.command,
        session: _session,
      );
      stageStopwatch.stop();

      final cumulativeTraces = result.debugTraces;
      final stageTraces = cumulativeTraces
          .skip(traceOffset)
          .map((trace) => Map<String, Object?>.from(trace))
          .toList(growable: false);
      traceOffset = cumulativeTraces.length;

      final analyzed = _analyzeStage(
        stage: stage,
        payload: result.result,
        errorText: result.errorText,
        logs: result.logs,
        stageTraces: stageTraces,
        duration: stageStopwatch.elapsed,
      );

      nextStageResults.add(analyzed);
      if (analyzed.outcome != _StageOutcome.success) {
        shouldContinue = false;
        stopReason = '${stage.shortLabel}阶段未通过：${analyzed.summary}';
      }

      if (mounted) {
        setState(() {
          _stageResults
            ..clear()
            ..addAll(nextStageResults);
        });
      }
    }

    pipelineStopwatch.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _isRunning = false;
      _runningStageIndex = -1;
      _lastRunDuration = pipelineStopwatch.elapsed;
    });
  }

  _StageResult _analyzeStage({
    required _DebugStageSpec stage,
    required Object? payload,
    required String? errorText,
    required List<SourceScriptDebugLogEntry> logs,
    required List<Map<String, Object?>> stageTraces,
    required Duration duration,
  }) {
    if (errorText != null && errorText.trim().isNotEmpty) {
      return _StageResult(
        stage: stage,
        outcome: _StageOutcome.failed,
        summary: '执行抛出异常，阶段未完成。',
        highlights: _buildCommonHighlights(duration, stageTraces, logs),
        payload: payload,
        errorText: errorText,
        logs: logs,
        stageTraces: stageTraces,
        duration: duration,
      );
    }

    return switch (stage.kind) {
      _DebugStageKind.search => _analyzeSearchStage(
        stage: stage,
        payload: payload,
        logs: logs,
        stageTraces: stageTraces,
        duration: duration,
      ),
      _DebugStageKind.detail => _analyzeDetailStage(
        stage: stage,
        payload: payload,
        logs: logs,
        stageTraces: stageTraces,
        duration: duration,
      ),
      _DebugStageKind.chapters => _analyzeChaptersStage(
        stage: stage,
        payload: payload,
        logs: logs,
        stageTraces: stageTraces,
        duration: duration,
      ),
      _DebugStageKind.content => _analyzeContentStage(
        stage: stage,
        payload: payload,
        logs: logs,
        stageTraces: stageTraces,
        duration: duration,
      ),
    };
  }

  _StageResult _analyzeSearchStage({
    required _DebugStageSpec stage,
    required Object? payload,
    required List<SourceScriptDebugLogEntry> logs,
    required List<Map<String, Object?>> stageTraces,
    required Duration duration,
  }) {
    if (payload is! List) {
      return _invalidStage(
        stage: stage,
        payload: payload,
        logs: logs,
        stageTraces: stageTraces,
        duration: duration,
        summary: '搜索结果不是列表结构。',
      );
    }
    if (payload.isEmpty) {
      return _emptyStage(
        stage: stage,
        payload: payload,
        logs: logs,
        stageTraces: stageTraces,
        duration: duration,
        summary: '搜索已执行，但没有返回任何书籍。',
      );
    }

    final firstBook = _asMap(payload.first);
    final firstTitle = _readString(firstBook?['title']);
    final firstAuthor = _readString(firstBook?['author']);
    if (firstBook == null || firstTitle.isEmpty) {
      return _invalidStage(
        stage: stage,
        payload: payload,
        logs: logs,
        stageTraces: stageTraces,
        duration: duration,
        summary: '搜索结果缺少书籍标题，结构不符合预期。',
      );
    }

    return _successStage(
      stage: stage,
      payload: payload,
      logs: logs,
      stageTraces: stageTraces,
      duration: duration,
      summary: '搜索返回 ${payload.length} 本书，已拿到可继续调试的首条结果。',
      highlights: <String>[
        '结果数 ${payload.length}',
        '首本《$firstTitle》',
        if (firstAuthor.isNotEmpty) '作者 $firstAuthor',
        ..._buildCommonHighlights(duration, stageTraces, logs),
      ],
    );
  }

  _StageResult _analyzeDetailStage({
    required _DebugStageSpec stage,
    required Object? payload,
    required List<SourceScriptDebugLogEntry> logs,
    required List<Map<String, Object?>> stageTraces,
    required Duration duration,
  }) {
    final detail = _asMap(payload);
    if (payload == null) {
      return _emptyStage(
        stage: stage,
        payload: payload,
        logs: logs,
        stageTraces: stageTraces,
        duration: duration,
        summary: '详情阶段返回空结果。',
      );
    }
    if (detail == null) {
      return _invalidStage(
        stage: stage,
        payload: payload,
        logs: logs,
        stageTraces: stageTraces,
        duration: duration,
        summary: '详情结果不是对象结构。',
      );
    }

    final title = _readString(detail['title']);
    final author = _readString(detail['author']);
    final detailUrl = _readString(detail['detailUrl']);
    final latestChapter = _readString(detail['latestChapter']);
    if (title.isEmpty) {
      return _invalidStage(
        stage: stage,
        payload: payload,
        logs: logs,
        stageTraces: stageTraces,
        duration: duration,
        summary: '详情结果缺少标题。',
      );
    }

    return _successStage(
      stage: stage,
      payload: payload,
      logs: logs,
      stageTraces: stageTraces,
      duration: duration,
      summary: '详情页数据可用，已拿到书籍关键信息。',
      highlights: <String>[
        '书名《$title》',
        if (author.isNotEmpty) '作者 $author',
        if (latestChapter.isNotEmpty) '最新章节 $latestChapter',
        if (detailUrl.isNotEmpty) '详情链接已返回',
        ..._buildCommonHighlights(duration, stageTraces, logs),
      ],
    );
  }

  _StageResult _analyzeChaptersStage({
    required _DebugStageSpec stage,
    required Object? payload,
    required List<SourceScriptDebugLogEntry> logs,
    required List<Map<String, Object?>> stageTraces,
    required Duration duration,
  }) {
    if (payload is! List) {
      return _invalidStage(
        stage: stage,
        payload: payload,
        logs: logs,
        stageTraces: stageTraces,
        duration: duration,
        summary: '目录结果不是列表结构。',
      );
    }
    if (payload.isEmpty) {
      return _emptyStage(
        stage: stage,
        payload: payload,
        logs: logs,
        stageTraces: stageTraces,
        duration: duration,
        summary: '目录阶段返回空列表。',
      );
    }

    final firstChapter = _asMap(payload.first);
    final lastChapter = _asMap(payload.last);
    final firstTitle = _readString(firstChapter?['title']);
    final lastTitle = _readString(lastChapter?['title']);
    if (firstChapter == null || firstTitle.isEmpty) {
      return _invalidStage(
        stage: stage,
        payload: payload,
        logs: logs,
        stageTraces: stageTraces,
        duration: duration,
        summary: '目录项缺少标题，结构不符合预期。',
      );
    }

    return _successStage(
      stage: stage,
      payload: payload,
      logs: logs,
      stageTraces: stageTraces,
      duration: duration,
      summary: '目录可用，已拿到章节列表。',
      highlights: <String>[
        '章节数 ${payload.length}',
        '首章 $firstTitle',
        if (lastTitle.isNotEmpty && lastTitle != firstTitle) '末章 $lastTitle',
        ..._buildCommonHighlights(duration, stageTraces, logs),
      ],
    );
  }

  _StageResult _analyzeContentStage({
    required _DebugStageSpec stage,
    required Object? payload,
    required List<SourceScriptDebugLogEntry> logs,
    required List<Map<String, Object?>> stageTraces,
    required Duration duration,
  }) {
    final content = _asMap(payload);
    if (payload == null) {
      return _emptyStage(
        stage: stage,
        payload: payload,
        logs: logs,
        stageTraces: stageTraces,
        duration: duration,
        summary: '正文阶段返回空结果。',
      );
    }
    if (content == null) {
      return _invalidStage(
        stage: stage,
        payload: payload,
        logs: logs,
        stageTraces: stageTraces,
        duration: duration,
        summary: '正文结果不是对象结构。',
      );
    }

    final title = _readString(content['title']);
    final text = _readString(content['content']);
    final images = _asList(content['images']);
    if (text.isEmpty && images.isEmpty) {
      return _emptyStage(
        stage: stage,
        payload: payload,
        logs: logs,
        stageTraces: stageTraces,
        duration: duration,
        summary: '正文阶段没有返回文字，也没有返回图片。',
      );
    }

    return _successStage(
      stage: stage,
      payload: payload,
      logs: logs,
      stageTraces: stageTraces,
      duration: duration,
      summary: '正文内容可读，最终链路已跑通。',
      highlights: <String>[
        if (title.isNotEmpty) '标题 $title',
        if (text.isNotEmpty) '正文 ${text.runes.length} 字',
        if (images.isNotEmpty) '图片 ${images.length} 张',
        ..._buildCommonHighlights(duration, stageTraces, logs),
      ],
    );
  }

  _StageResult _successStage({
    required _DebugStageSpec stage,
    required Object? payload,
    required List<SourceScriptDebugLogEntry> logs,
    required List<Map<String, Object?>> stageTraces,
    required Duration duration,
    required String summary,
    required List<String> highlights,
  }) {
    return _StageResult(
      stage: stage,
      outcome: _StageOutcome.success,
      summary: summary,
      highlights: highlights,
      payload: payload,
      errorText: null,
      logs: logs,
      stageTraces: stageTraces,
      duration: duration,
    );
  }

  _StageResult _emptyStage({
    required _DebugStageSpec stage,
    required Object? payload,
    required List<SourceScriptDebugLogEntry> logs,
    required List<Map<String, Object?>> stageTraces,
    required Duration duration,
    required String summary,
  }) {
    return _StageResult(
      stage: stage,
      outcome: _StageOutcome.empty,
      summary: summary,
      highlights: _buildCommonHighlights(duration, stageTraces, logs),
      payload: payload,
      errorText: null,
      logs: logs,
      stageTraces: stageTraces,
      duration: duration,
    );
  }

  _StageResult _invalidStage({
    required _DebugStageSpec stage,
    required Object? payload,
    required List<SourceScriptDebugLogEntry> logs,
    required List<Map<String, Object?>> stageTraces,
    required Duration duration,
    required String summary,
  }) {
    return _StageResult(
      stage: stage,
      outcome: _StageOutcome.invalid,
      summary: summary,
      highlights: _buildCommonHighlights(duration, stageTraces, logs),
      payload: payload,
      errorText: null,
      logs: logs,
      stageTraces: stageTraces,
      duration: duration,
    );
  }

  List<String> _buildCommonHighlights(
    Duration duration,
    List<Map<String, Object?>> stageTraces,
    List<SourceScriptDebugLogEntry> logs,
  ) {
    final httpCount =
        stageTraces.where((trace) => trace['kind'] == 'http').length;
    final browserCount =
        stageTraces.where((trace) => trace['kind'] == 'browser').length;
    final errorCount =
        stageTraces
            .where((trace) => _readString(trace['error']).isNotEmpty)
            .length;
    return <String>[
      '耗时 ${_formatDuration(duration)}',
      if (httpCount > 0) 'HTTP $httpCount 次',
      if (browserCount > 0) '浏览器动作 $browserCount 次',
      if (logs.isNotEmpty) '日志 ${logs.length} 条',
      if (errorCount > 0) '轨迹错误 $errorCount 条',
    ];
  }

  _RunSummary get _runSummary {
    if (_stageResults.isEmpty) {
      return _RunSummary.empty();
    }

    final successCount =
        _stageResults
            .where((result) => result.outcome == _StageOutcome.success)
            .length;
    final failedCount =
        _stageResults.where((result) => result.isBlockingFailure).length;
    final skippedCount =
        _stageResults
            .where((result) => result.outcome == _StageOutcome.skipped)
            .length;
    final totalHttpCount = _stageResults.fold<int>(
      0,
      (total, result) =>
          total +
          result.stageTraces.where((trace) => trace['kind'] == 'http').length,
    );
    final totalBrowserCount = _stageResults.fold<int>(
      0,
      (total, result) =>
          total +
          result.stageTraces
              .where((trace) => trace['kind'] == 'browser')
              .length,
    );
    final totalTraceErrors = _stageResults.fold<int>(
      0,
      (total, result) =>
          total +
          result.stageTraces
              .where((trace) => _readString(trace['error']).isNotEmpty)
              .length,
    );
    final firstIssue = _stageResults.firstWhere(
      (result) => result.outcome != _StageOutcome.success,
      orElse: () => _stageResults.last,
    );

    final outcome =
        successCount == _stageResults.length
            ? _RunOutcome.success
            : successCount > 0
            ? _RunOutcome.partial
            : _RunOutcome.failed;

    final summaryText = switch (outcome) {
      _RunOutcome.success => '4/4 阶段通过，书源主链路可以跑通。',
      _RunOutcome.partial =>
        '${firstIssue.stage.shortLabel}阶段未通过：${firstIssue.summary}',
      _RunOutcome.failed =>
        '${firstIssue.stage.shortLabel}阶段未通过：${firstIssue.summary}',
      _RunOutcome.idle => '尚未执行调试。',
    };

    return _RunSummary(
      outcome: outcome,
      summaryText: summaryText,
      successCount: successCount,
      failedCount: failedCount,
      skippedCount: skippedCount,
      httpCount: totalHttpCount,
      browserCount: totalBrowserCount,
      traceErrorCount: totalTraceErrors,
      totalDuration: _lastRunDuration,
    );
  }

  void _showTransientMessage(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatValue(Object? value) {
    if (value == null) {
      return 'null';
    }
    if (value is String) {
      return value;
    }
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    const pageBackground = Color(0xFF0A0D12);
    const panelBackground = Color(0xFF10141B);
    const panelBorder = Color(0xFF242A35);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title?.trim().isNotEmpty == true ? widget.title! : '书源调试',
        ),
        actions: [
          TextButton.icon(
            onPressed: _isRunning ? null : _runPipeline,
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
      body: ColoredBox(
        color: pageBackground,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              children: [
                _DebugInputCard(
                  controller: _keywordController,
                  isRunning: _isRunning,
                  completedCount:
                      _stageResults
                          .where(
                            (result) => result.outcome != _StageOutcome.skipped,
                          )
                          .length,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      _DebugOverviewCard(
                        summary: _runSummary,
                        runningStageIndex: _runningStageIndex,
                        hasResults: _stageResults.isNotEmpty,
                      ),
                      const SizedBox(height: 12),
                      _StageProgressStrip(
                        stageResults: _stageResults,
                        runningStageIndex: _runningStageIndex,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: panelBackground,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: panelBorder),
                        ),
                        padding: const EdgeInsets.all(12),
                        child:
                            _stageResults.isEmpty && _isRunning
                                ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 48),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                                : _stageResults.isEmpty
                                ? const _DebugEmptyState()
                                : Column(
                                  children: [
                                    for (
                                      var index = 0;
                                      index < _stageResults.length;
                                      index++
                                    ) ...[
                                      _StageResultCard(
                                        key: ValueKey(
                                          _stageResults[index].stage.kind,
                                        ),
                                        result: _stageResults[index],
                                        formatValue: _formatValue,
                                        initiallyExpanded:
                                            _stageResults[index]
                                                .shouldExpandByDefault,
                                      ),
                                      if (index != _stageResults.length - 1)
                                        const SizedBox(height: 10),
                                    ],
                                  ],
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _DebugStageKind { search, detail, chapters, content }

enum _StageOutcome { success, empty, invalid, failed, skipped }

enum _RunOutcome { idle, success, partial, failed }

class _DebugStageSpec {
  const _DebugStageSpec({
    required this.index,
    required this.kind,
    required this.shortLabel,
    required this.title,
    required this.command,
  });

  final int index;
  final _DebugStageKind kind;
  final String shortLabel;
  final String title;
  final String command;
}

class _StageResult {
  const _StageResult({
    required this.stage,
    required this.outcome,
    required this.summary,
    required this.highlights,
    required this.payload,
    required this.errorText,
    required this.logs,
    required this.stageTraces,
    required this.duration,
  });

  factory _StageResult.skipped({
    required _DebugStageSpec stage,
    required String summary,
  }) {
    return _StageResult(
      stage: stage,
      outcome: _StageOutcome.skipped,
      summary: summary,
      highlights: const <String>[],
      payload: null,
      errorText: null,
      logs: const <SourceScriptDebugLogEntry>[],
      stageTraces: const <Map<String, Object?>>[],
      duration: Duration.zero,
    );
  }

  final _DebugStageSpec stage;
  final _StageOutcome outcome;
  final String summary;
  final List<String> highlights;
  final Object? payload;
  final String? errorText;
  final List<SourceScriptDebugLogEntry> logs;
  final List<Map<String, Object?>> stageTraces;
  final Duration duration;

  bool get isBlockingFailure =>
      outcome == _StageOutcome.empty ||
      outcome == _StageOutcome.invalid ||
      outcome == _StageOutcome.failed;

  bool get shouldExpandByDefault =>
      outcome == _StageOutcome.failed ||
      outcome == _StageOutcome.invalid ||
      outcome == _StageOutcome.empty;

  String get statusLabel => switch (outcome) {
    _StageOutcome.success => '成功',
    _StageOutcome.empty => '空结果',
    _StageOutcome.invalid => '结构异常',
    _StageOutcome.failed => '失败',
    _StageOutcome.skipped => '跳过',
  };

  Color get accent => switch (outcome) {
    _StageOutcome.success => const Color(0xFF37D67A),
    _StageOutcome.empty => const Color(0xFFFFC857),
    _StageOutcome.invalid => const Color(0xFFFF9F5A),
    _StageOutcome.failed => const Color(0xFFFF5D73),
    _StageOutcome.skipped => const Color(0xFF6E7785),
  };
}

class _RunSummary {
  const _RunSummary({
    required this.outcome,
    required this.summaryText,
    required this.successCount,
    required this.failedCount,
    required this.skippedCount,
    required this.httpCount,
    required this.browserCount,
    required this.traceErrorCount,
    required this.totalDuration,
  });

  factory _RunSummary.empty() {
    return const _RunSummary(
      outcome: _RunOutcome.idle,
      summaryText: '输入关键词后执行调试，页面会直接给出结论。',
      successCount: 0,
      failedCount: 0,
      skippedCount: 0,
      httpCount: 0,
      browserCount: 0,
      traceErrorCount: 0,
      totalDuration: null,
    );
  }

  final _RunOutcome outcome;
  final String summaryText;
  final int successCount;
  final int failedCount;
  final int skippedCount;
  final int httpCount;
  final int browserCount;
  final int traceErrorCount;
  final Duration? totalDuration;

  String get title => switch (outcome) {
    _RunOutcome.idle => '等待执行',
    _RunOutcome.success => '调试成功',
    _RunOutcome.partial => '部分通过',
    _RunOutcome.failed => '调试失败',
  };

  Color get accent => switch (outcome) {
    _RunOutcome.idle => const Color(0xFF7F8792),
    _RunOutcome.success => const Color(0xFF37D67A),
    _RunOutcome.partial => const Color(0xFFFFC857),
    _RunOutcome.failed => const Color(0xFFFF5D73),
  };
}

class _DebugInputCard extends StatelessWidget {
  const _DebugInputCard({
    required this.controller,
    required this.isRunning,
    required this.completedCount,
  });

  final TextEditingController controller;
  final bool isRunning;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card.outlined(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: const Color(0xFF10141B),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '调试参数',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _MetricChip(
                  label: isRunning ? '状态' : '结果',
                  value: isRunning ? '执行中' : '$completedCount/4',
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '调试关键词',
                labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                hintText: '例如：斗罗大陆',
                helperText: '建议使用稳定能搜到结果的关键词。',
                helperStyle: const TextStyle(color: Color(0xFF6E7785)),
                filled: true,
                fillColor: const Color(0xFF0B0F14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colorScheme.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugOverviewCard extends StatelessWidget {
  const _DebugOverviewCard({
    required this.summary,
    required this.runningStageIndex,
    required this.hasResults,
  });

  final _RunSummary summary;
  final int runningStageIndex;
  final bool hasResults;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRunning = runningStageIndex >= 0;
    return Card.outlined(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: const Color(0xFF10141B),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: summary.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summary.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isRunning)
                  Text(
                    '第 ${runningStageIndex + 1} 步执行中',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              summary.summaryText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFE4E8EF),
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(label: '通过', value: '${summary.successCount}'),
                _MetricChip(label: '未通过', value: '${summary.failedCount}'),
                if (summary.skippedCount > 0)
                  _MetricChip(label: '跳过', value: '${summary.skippedCount}'),
                _MetricChip(label: 'HTTP', value: '${summary.httpCount}'),
                _MetricChip(label: '浏览器', value: '${summary.browserCount}'),
                _MetricChip(label: '轨迹错误', value: '${summary.traceErrorCount}'),
                if (summary.totalDuration != null)
                  _MetricChip(
                    label: '总耗时',
                    value: _formatDuration(summary.totalDuration!),
                  ),
              ],
            ),
            if (!hasResults && !isRunning) ...[
              const SizedBox(height: 10),
              Text(
                '执行后会先给出结论，再展示阶段详情和原始结果。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StageProgressStrip extends StatelessWidget {
  const _StageProgressStrip({
    required this.stageResults,
    required this.runningStageIndex,
  });

  final List<_StageResult> stageResults;
  final int runningStageIndex;

  @override
  Widget build(BuildContext context) {
    const stages = <String>['搜索', '详情', '目录', '正文'];
    return Card.outlined(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: const Color(0xFF10141B),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            for (var index = 0; index < stages.length; index++) ...[
              Expanded(
                child: _StageProgressNode(
                  index: index,
                  label: stages[index],
                  result:
                      index < stageResults.length ? stageResults[index] : null,
                  isRunning: runningStageIndex == index,
                ),
              ),
              if (index != stages.length - 1)
                Expanded(
                  child: Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: const Color(0xFF2B3442),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StageProgressNode extends StatelessWidget {
  const _StageProgressNode({
    required this.index,
    required this.label,
    required this.result,
    required this.isRunning,
  });

  final int index;
  final String label;
  final _StageResult? result;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent =
        isRunning
            ? const Color(0xFF72B8FF)
            : result?.accent ?? const Color(0xFF4B5563);
    final status =
        isRunning ? '执行中' : (result == null ? '待执行' : result!.statusLabel);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Text(
            '${index + 1}',
            style: TextStyle(color: accent, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          status,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isRunning ? accent : colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StageResultCard extends StatelessWidget {
  const _StageResultCard({
    super.key,
    required this.result,
    required this.formatValue,
    required this.initiallyExpanded,
  });

  final _StageResult result;
  final String Function(Object? value) formatValue;
  final bool initiallyExpanded;

  String _buildStageCopyText() {
    final buffer =
        StringBuffer()
          ..writeln('阶段：${result.stage.title}')
          ..writeln('状态：${result.statusLabel}')
          ..writeln('摘要：${result.summary}');

    if (result.highlights.isNotEmpty) {
      buffer.writeln('亮点：${result.highlights.join(' / ')}');
    }
    if (result.errorText != null && result.errorText!.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('错误信息')
        ..writeln(result.errorText!.trim());
    }
    if (result.logs.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('脚本日志');
      for (final log in result.logs) {
        final label = switch (log.level) {
          SourceScriptDebugLogLevel.warn => 'warn',
          SourceScriptDebugLogLevel.error => 'error',
          SourceScriptDebugLogLevel.info => 'log',
        };
        buffer.writeln('[$label] ${log.message}');
      }
    }
    if (result.stageTraces.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('网络轨迹');
      for (final trace in result.stageTraces) {
        buffer.writeln(jsonEncode(trace));
      }
    }
    buffer
      ..writeln()
      ..writeln('原始结果')
      ..writeln(formatValue(result.payload));
    return buffer.toString().trimRight();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _buildPreview(result);
    final payloadText = formatValue(result.payload);
    final logsText = result.logs
        .map((log) {
          final label = switch (log.level) {
            SourceScriptDebugLogLevel.warn => 'warn',
            SourceScriptDebugLogLevel.error => 'error',
            SourceScriptDebugLogLevel.info => 'log',
          };
          return '[$label] ${log.message}';
        })
        .join('\n');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: result.accent.withValues(alpha: 0.28)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: result.accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${result.stage.index + 1}',
                  style: TextStyle(
                    color: result.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.stage.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.summary,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFAFB7C4),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: '复制完整信息',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: _buildStageCopyText()),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已复制完整调试信息')));
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: result.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  result.statusLabel,
                  style: TextStyle(
                    color: result.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          children: [
            if (result.highlights.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: result.highlights
                    .map((item) => _HighlightChip(text: item))
                    .toList(growable: false),
              ),
            if (preview != null) ...[
              const SizedBox(height: 12),
              _DetailBlock(
                title: '快速预览',
                child: SelectableText(
                  preview,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            if (result.errorText != null &&
                result.errorText!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailBlock(
                title: '错误信息',
                accent: const Color(0xFFFF5D73),
                child: SelectableText(
                  result.errorText!,
                  style: const TextStyle(
                    color: Color(0xFFFFA3B1),
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            if (result.logs.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailBlock(
                title: '脚本日志',
                child: SelectableText(
                  logsText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            if (result.stageTraces.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailBlock(
                title: '网络轨迹',
                child: Column(
                  children: result.stageTraces
                      .map(
                        (trace) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TraceTile(trace: trace),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _DetailBlock(
              title: '原始结果',
              child: SelectableText(
                payloadText,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugEmptyState extends StatelessWidget {
  const _DebugEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48, horizontal: 12),
      child: Column(
        children: [
          Text(
            '还没有调试结果',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '执行后这里会按搜索、详情、目录、正文四步展示是否成功，以及每一步的关键摘要。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF97A0AE),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: compact ? 11.5 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0F141B),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF1E2430)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFD8DEE8),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.title,
    required this.child,
    this.accent = const Color(0xFF72B8FF),
  });

  final String title;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F141B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2430)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _TraceTile extends StatelessWidget {
  const _TraceTile({required this.trace});

  final Map<String, Object?> trace;

  @override
  Widget build(BuildContext context) {
    final kind = _readString(trace['kind']);
    final error = _readString(trace['error']);
    final accent =
        error.isNotEmpty
            ? const Color(0xFFFF5D73)
            : kind == 'browser'
            ? const Color(0xFF72B8FF)
            : const Color(0xFF37D67A);
    final title = _traceTitle(trace);
    final subtitle = _traceSubtitle(trace);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF121924),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2430)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  kind.isEmpty ? 'trace' : kind,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF97A0AE),
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (error.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              error,
              style: const TextStyle(
                color: Color(0xFFFFA3B1),
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _traceTitle(Map<String, Object?> trace) {
  final kind = _readString(trace['kind']);
  if (kind == 'http') {
    final method = _readString(trace['method']);
    final url = _readString(trace['url']);
    final status = _readString(trace['status']);
    return '${method.isEmpty ? 'HTTP' : method} ${_shortenUrl(url)}${status.isNotEmpty ? ' -> $status' : ''}';
  }

  if (kind == 'browser') {
    final action = _readString(trace['action']);
    final url = _readString(trace['url']);
    return '${action.isEmpty ? 'browser' : action} ${_shortenUrl(url)}';
  }

  return _shortenText(const JsonEncoder.withIndent('  ').convert(trace), 120);
}

String _traceSubtitle(Map<String, Object?> trace) {
  final kind = _readString(trace['kind']);
  if (kind == 'http') {
    final responseJson = trace['responseJson'];
    final responseText = _readString(trace['responseText']);
    if (responseJson != null) {
      return '返回 JSON';
    }
    if (responseText.isNotEmpty) {
      return _shortenText(responseText.replaceAll(RegExp(r'\s+'), ' '), 120);
    }
    return '';
  }

  if (kind == 'browser') {
    final reason = _readString(trace['reason']);
    final waitFor = trace['waitFor'];
    if (reason.isNotEmpty) {
      return 'reason: $reason';
    }
    if (waitFor != null) {
      return _shortenText(waitFor.toString(), 120);
    }
  }
  return '';
}

String? _buildPreview(_StageResult result) {
  switch (result.stage.kind) {
    case _DebugStageKind.search:
      final list =
          result.payload is List ? result.payload! as List : const <Object?>[];
      if (list.isEmpty) {
        return null;
      }
      final items = list
          .take(3)
          .map((item) {
            final map = _asMap(item);
            if (map == null) {
              return item.toString();
            }
            final title = _readString(map['title']);
            final author = _readString(map['author']);
            return '《$title》${author.isNotEmpty ? ' / $author' : ''}';
          })
          .toList(growable: false);
      return items.join('\n');
    case _DebugStageKind.detail:
      final map = _asMap(result.payload);
      if (map == null) {
        return null;
      }
      return <String>[
        if (_readString(map['title']).isNotEmpty)
          '书名：${_readString(map['title'])}',
        if (_readString(map['author']).isNotEmpty)
          '作者：${_readString(map['author'])}',
        if (_readString(map['intro']).isNotEmpty)
          '简介：${_shortenText(_readString(map['intro']), 120)}',
        if (_readString(map['latestChapter']).isNotEmpty)
          '最新章节：${_readString(map['latestChapter'])}',
      ].join('\n');
    case _DebugStageKind.chapters:
      final list =
          result.payload is List ? result.payload! as List : const <Object?>[];
      if (list.isEmpty) {
        return null;
      }
      return list
          .take(5)
          .map((item) {
            final map = _asMap(item);
            return _readString(map?['title']);
          })
          .where((item) => item.isNotEmpty)
          .join('\n');
    case _DebugStageKind.content:
      final map = _asMap(result.payload);
      if (map == null) {
        return null;
      }
      final title = _readString(map['title']);
      final content = _shortenText(_readString(map['content']), 180);
      final images = _asList(map['images']);
      return <String>[
        if (title.isNotEmpty) '标题：$title',
        if (content.isNotEmpty) content,
        if (images.isNotEmpty) '图片：${images.length} 张',
      ].join('\n\n');
  }
}

Map<String, Object?>? _asMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (Object? key, Object? mapValue) => MapEntry(key.toString(), mapValue),
    );
  }
  return null;
}

List<Object?> _asList(Object? value) {
  if (value is List<Object?>) {
    return value;
  }
  if (value is List) {
    return value.cast<Object?>();
  }
  return const <Object?>[];
}

String _readString(Object? value) {
  return value?.toString().trim() ?? '';
}

String _shortenText(String value, int maxLength) {
  if (value.length <= maxLength) {
    return value;
  }
  return '${value.substring(0, maxLength)}...';
}

String _shortenUrl(String value) {
  if (value.isEmpty) {
    return '';
  }
  return _shortenText(value, 72);
}

String _formatDuration(Duration duration) {
  final milliseconds = duration.inMilliseconds;
  if (milliseconds < 1000) {
    return '${milliseconds}ms';
  }
  return '${(milliseconds / 1000).toStringAsFixed(milliseconds >= 10000 ? 0 : 1)}s';
}
