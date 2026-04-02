import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../runtime/session/source_session.dart';
import '../../../runtime/sources/source_script_compiler.dart';

class ScriptSourceDebugPage extends StatefulWidget {
  const ScriptSourceDebugPage({
    super.key,
    required this.sourceCode,
    this.title,
    this.autoRunOnInit = true,
  });

  final String sourceCode;
  final String? title;
  final bool autoRunOnInit;

  @override
  State<ScriptSourceDebugPage> createState() => _ScriptSourceDebugPageState();
}

class _ScriptSourceDebugPageState extends State<ScriptSourceDebugPage> {
  final SourceScriptDebugService _debugService = SourceScriptDebugService();
  final SourceSession _session = SourceSession(sourceId: '__script_debug__');
  final TextEditingController _keywordController = TextEditingController(
    text: '斗罗大陆',
  );

  bool _isRunning = false;
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

  Future<void> _runPipeline() async {
    final keyword = _keywordController.text.trim();
    if (_isRunning) {
      return;
    }

    setState(() {
      _isRunning = true;
      _stageResults.clear();
      _session.clear();
      _session.clearCookies();
    });

    final stages = <_DebugStageSpec>[
      _DebugStageSpec(
        title: '搜索阶段返回结果',
        command: '''
const keyword = ${jsonEncode(keyword)};
const books = await source.search(ctx, keyword);
console.log('search result', books);
return books;
''',
      ),
      _DebugStageSpec(
        title: '详情页返回结果',
        command: '''
const keyword = ${jsonEncode(keyword)};
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
        title: '目录返回结果',
        command: '''
const keyword = ${jsonEncode(keyword)};
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
        title: '正文返回结果',
        command: '''
const keyword = ${jsonEncode(keyword)};
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

    final nextStageResults = <_StageResult>[];

    for (final stage in stages) {
      final result = await _debugService.evaluate(
        sourceCode: widget.sourceCode,
        command: stage.command,
        session: _session,
      );

      nextStageResults.add(
        _StageResult(
          title: stage.title,
          payload: result.result,
          errorText: result.errorText,
          logs: result.logs,
          debugTraces: result.debugTraces,
        ),
      );

      if (mounted) {
        setState(() {
          _stageResults
            ..clear()
            ..addAll(nextStageResults);
        });
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isRunning = false;
    });
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
          widget.title?.trim().isNotEmpty == true ? widget.title! : '书享源调试',
        ),
        actions: [
          FilledButton(
            onPressed: _isRunning ? null : _runPipeline,
            child:
                _isRunning
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('重新执行'),
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
                Container(
                  decoration: BoxDecoration(
                    color: panelBackground,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: panelBorder),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _keywordController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: '调试关键词',
                            labelStyle: const TextStyle(
                              color: Color(0xFF8D95A2),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF0B0F14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isRunning ? '执行中' : '${_stageResults.length}/4',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _buildStagePanel(
                    context,
                    panelBackground: panelBackground,
                    panelBorder: panelBorder,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStagePanel(
    BuildContext context, {
    required Color panelBackground,
    required Color panelBorder,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: panelBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: panelBorder),
      ),
      child:
          _stageResults.isEmpty && _isRunning
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemBuilder: (context, index) {
                  return _StageResultCard(
                    result: _stageResults[index],
                    formatValue: _formatValue,
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: _stageResults.length,
              ),
    );
  }
}

class _DebugStageSpec {
  const _DebugStageSpec({required this.title, required this.command});

  final String title;
  final String command;
}

class _StageResult {
  const _StageResult({
    required this.title,
    required this.payload,
    required this.errorText,
    required this.logs,
    required this.debugTraces,
  });

  final String title;
  final Object? payload;
  final String? errorText;
  final List<SourceScriptDebugLogEntry> logs;
  final List<Map<String, Object?>> debugTraces;

  bool get hasError => errorText != null && errorText!.trim().isNotEmpty;
}

class _StageResultCard extends StatelessWidget {
  const _StageResultCard({required this.result, required this.formatValue});

  final _StageResult result;
  final String Function(Object? value) formatValue;

  @override
  Widget build(BuildContext context) {
    final accent =
        result.hasError ? const Color(0xFFFF5D73) : const Color(0xFF4B7BFF);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2430)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  result.hasError ? '失败' : '完成',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (result.hasError)
            SelectableText(
              result.errorText!,
              style: const TextStyle(
                color: Color(0xFFFF9AAA),
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.45,
              ),
            )
          else
            SelectableText(
              formatValue(result.payload),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          const SizedBox(height: 10),
          Text(
            '日志 ${result.logs.length} 条 · 轨迹 ${result.debugTraces.length} 条',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF7F8792)),
          ),
          if (result.logs.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...result.logs.map(
              (log) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _InlineLogTile(
                  label: switch (log.level) {
                    SourceScriptDebugLogLevel.warn => 'warn',
                    SourceScriptDebugLogLevel.error => 'error',
                    SourceScriptDebugLogLevel.info => 'log',
                  },
                  message: log.message,
                ),
              ),
            ),
          ],
          if (result.debugTraces.isNotEmpty) ...[
            const SizedBox(height: 4),
            _InlineLogTile(
              label: 'trace',
              message: const JsonEncoder.withIndent(
                '  ',
              ).convert(result.debugTraces),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineLogTile extends StatelessWidget {
  const _InlineLogTile({required this.label, required this.message});

  final String label;
  final String message;

  @override
  Widget build(BuildContext context) {
    final accent = switch (label) {
      'warn' => const Color(0xFFFFB020),
      'error' => const Color(0xFFFF5D73),
      'trace' => const Color(0xFF72B8FF),
      _ => const Color(0xFF9AA3AF),
    };

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F141B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2430)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
