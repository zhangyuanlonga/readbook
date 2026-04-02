import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/vs.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight/languages/javascript.dart';

import '../../../domain/entities/script_source.dart';
import '../../../runtime/sources/source_script_compiler.dart'
    show SourceScriptCompileException;
import '../../../runtime/sources/source_script_template.dart';
import '../application/source_runtime_facade.dart';
import 'script_source_debug_page.dart';

class ScriptSourceEditorPage extends StatefulWidget {
  const ScriptSourceEditorPage({
    super.key,
    this.scriptSourceId,
    this.sourceRuntimeFacade,
  });

  final String? scriptSourceId;
  final SourceRuntimeFacade? sourceRuntimeFacade;

  @override
  State<ScriptSourceEditorPage> createState() => _ScriptSourceEditorPageState();
}

class _ScriptSourceEditorPageState extends State<ScriptSourceEditorPage> {
  late final SourceRuntimeFacade _sourceRuntimeFacade;
  late final CodeController _controller;

  ScriptSource? _source;
  _EditorAppearance _appearance = _EditorAppearance.night;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDirty = false;
  bool _isEditorMounted = false;
  bool _isApplyingEditorValue = false;

  bool get _isEditingExisting =>
      widget.scriptSourceId?.trim().isNotEmpty == true && _source != null;

  _EditorPalette get _palette => switch (_appearance) {
    _EditorAppearance.day => _EditorPalette.day,
    _EditorAppearance.night => _EditorPalette.night,
  };

  double get _gutterWidth {
    final lineCount = '\n'.allMatches(_controller.fullText).length + 1;
    final digitCount = lineCount.toString().length;
    return switch (digitCount) {
      1 || 2 => 72,
      3 => 80,
      _ => 88,
    };
  }

  String get _editorFileName {
    final baseName = (_source?.name ?? '').trim();
    if (baseName.isEmpty) {
      return 'untitled.js';
    }
    return baseName.endsWith('.js') ? baseName : '$baseName.js';
  }

  Map<String, TextStyle> get _editorThemeStyles {
    final root =
        _palette.highlightTheme['root'] ??
        TextStyle(color: _palette.textPrimary);
    return <String, TextStyle>{
      ..._palette.highlightTheme,
      'root': root.copyWith(
        color: _palette.textPrimary,
        backgroundColor: _palette.panelBackground,
      ),
    };
  }

  @override
  void initState() {
    super.initState();
    _sourceRuntimeFacade =
        widget.sourceRuntimeFacade ?? SourceRuntimeFacade.instance;
    _controller = CodeController(
      text: '',
      language: javascript,
      analyzer: const _ScriptSourceEditorAnalyzer(),
    );
    _controller.autocompleter.setCustomWords(_scriptSourceAutocompleteWords);
    _controller.addListener(_handleEditorChanged);
    unawaited(_scheduleEditorMount());
    unawaited(_loadInitialValue());
  }

  @override
  void dispose() {
    _controller.removeListener(_handleEditorChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleEditorChanged() {
    if (_isLoading || _isApplyingEditorValue || _isDirty || !mounted) {
      return;
    }

    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.idle ||
        binding.schedulerPhase == SchedulerPhase.postFrameCallbacks) {
      setState(() {
        _isDirty = true;
      });
    } else {
      binding.addPostFrameCallback((_) {
        if (!mounted || _isDirty) {
          return;
        }
        setState(() {
          _isDirty = true;
        });
      });
    }
  }

  Future<void> _applySourceCode(String value, {required bool markDirty}) async {
    _isApplyingEditorValue = true;
    _controller.fullText = value;
    _isApplyingEditorValue = false;
    if (!mounted) {
      return;
    }
    setState(() {
      _isDirty = markDirty;
    });
  }

  Future<void> _loadInitialValue() async {
    final scriptSourceId = widget.scriptSourceId?.trim() ?? '';
    if (scriptSourceId.isEmpty) {
      if (!mounted) {
        return;
      }
      await _applySourceCode(sourceScriptTemplateV1, markDirty: false);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final source = await _sourceRuntimeFacade.getScriptSourceById(
        scriptSourceId,
      );
      if (!mounted) {
        return;
      }
      if (source == null) {
        setState(() {
          _isLoading = false;
        });
        _showTransientMessage('未找到要编辑的书享源。');
        return;
      }
      _source = source;
      await _applySourceCode(source.sourceCode, markDirty: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      _showTransientMessage('加载书享源失败：$error');
    }
  }

  Future<void> _scheduleEditorMount() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) {
      return;
    }
    setState(() {
      _isEditorMounted = true;
    });
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final sourceCode = _controller.fullText;
    final validationError = validateScriptSourceDraft(sourceCode);
    if (validationError != null) {
      _showTransientMessage(validationError);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _sourceRuntimeFacade.saveScriptSource(
        sourceCode: sourceCode,
        id: _source?.id,
        enabled: _source?.enabled ?? true,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isDirty = false;
      });
      context.pop(_source == null ? '书享源已新增。' : '书享源已保存。');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showTransientMessage(toFriendlyScriptEditorError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _formatSourceCode() async {
    if (_isLoading || _isSaving) {
      return;
    }

    final original = _controller.fullText;
    final formatted = formatScriptSourceDraft(original);
    if (formatted == original) {
      _showTransientMessage('当前内容已经是较整洁的格式。');
      return;
    }

    final previousOffset = _controller.selection.baseOffset;
    _isApplyingEditorValue = true;
    _controller.fullText = formatted;
    final nextOffset = math.min(
      previousOffset.clamp(0, formatted.length),
      formatted.length,
    );
    _controller.selection = TextSelection.collapsed(offset: nextOffset);
    _isApplyingEditorValue = false;
    if (!mounted) {
      return;
    }
    setState(() {
      _isDirty = true;
    });
    _showTransientMessage('已格式化书享源。');
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_isDirty || _isSaving) {
      return true;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('放弃未保存内容？'),
          content: const Text('当前书享源内容还没有保存，离开后本次修改将丢失。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('继续编辑'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('放弃'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _openDebugPage() async {
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => ScriptSourceDebugPage(
              sourceCode: _controller.fullText,
              title: _isEditingExisting ? '书享源调试' : '新建书享源调试',
            ),
      ),
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

  Future<void> _handleBackPressed() async {
    final allowLeave = await _confirmDiscardIfNeeded();
    if (!allowLeave || !mounted) {
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/source');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !_isDirty && context.canPop(),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !context.mounted) {
          return;
        }
        final allowLeave = await _confirmDiscardIfNeeded();
        if (!allowLeave || !context.mounted) {
          return;
        }
        context.go('/source');
      },
      child: Scaffold(
        body: ColoredBox(
          color: _palette.shellBackground,
          child: SafeArea(
            child: Column(
              children: [
                if (_isLoading) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _palette.panelBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _palette.border),
                        boxShadow: [
                          BoxShadow(
                            color: _palette.shadowColor,
                            blurRadius: 22,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          children: [
                            _buildEditorToolbar(context),
                            _buildIssueBanner(context),
                            Expanded(
                              child:
                                  _isLoading || !_isEditorMounted
                                      ? _buildEditorLoadingState(context)
                                      : _buildCodeEditor(context),
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
      ),
    );
  }

  Widget _buildEditorLoadingState(BuildContext context) {
    return ColoredBox(
      color: _palette.panelBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: _palette.accent,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '正在加载书享源',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _palette.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeEditor(BuildContext context) {
    return RepaintBoundary(
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            filled: false,
            fillColor: Colors.transparent,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: _palette.accent,
            selectionColor: _palette.selectionColor,
            selectionHandleColor: _palette.accent,
          ),
        ),
        child: CodeTheme(
          data: CodeThemeData(styles: _editorThemeStyles),
          child: CodeField(
            controller: _controller,
            expands: true,
            minLines: null,
            maxLines: null,
            wrap: false,
            background: _palette.panelBackground,
            cursorColor: _palette.accent,
            padding: const EdgeInsets.only(top: 14, bottom: 20, right: 24),
            textStyle: TextStyle(
              color: _palette.textPrimary,
              fontFamily: 'Menlo, Consolas, "Courier New", monospace',
              fontSize: 13.5,
              height: 1.55,
              letterSpacing: 0.15,
            ),
            gutterStyle: GutterStyle(
              width: _gutterWidth,
              margin: 8,
              background: _palette.tabBackground,
              textStyle: TextStyle(color: _palette.textMuted, fontSize: 12),
              showErrors: true,
              showFoldingHandles: true,
            ),
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
          ),
        ),
      ),
    );
  }

  Widget _buildEditorToolbar(BuildContext context) {
    final subtitle =
        _isDirty ? '未保存更改' : (_isEditingExisting ? '编辑书享源' : '新增书享源');

    return ColoredBox(
      color: _palette.tabBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          children: [
            IconButton(
              tooltip: '返回',
              onPressed: () => unawaited(_handleBackPressed()),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _palette.textPrimary,
                size: 18,
              ),
            ),
            const SizedBox(width: 4),
            const _EditorDot(color: Color(0xFFFF5F56)),
            const SizedBox(width: 6),
            const _EditorDot(color: Color(0xFFFFBD2E)),
            const SizedBox(width: 6),
            const _EditorDot(color: Color(0xFF27C93F)),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _palette.panelBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _palette.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.javascript_rounded,
                          size: 16,
                          color: _palette.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _editorFileName,
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(
                            color: _palette.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_isDirty) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _palette.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _palette.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: '格式化',
              style: IconButton.styleFrom(
                backgroundColor: _palette.statusBackground,
                foregroundColor: _palette.textPrimary,
              ),
              onPressed: _isLoading || _isSaving ? null : _formatSourceCode,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: '查找',
              style: IconButton.styleFrom(
                backgroundColor: _palette.statusBackground,
                foregroundColor: _palette.textPrimary,
              ),
              onPressed: _isLoading ? null : _controller.showSearch,
              icon: const Icon(Icons.search_rounded, size: 18),
            ),
            IconButton.filledTonal(
              tooltip:
                  _appearance == _EditorAppearance.night ? '切换到日间' : '切换到夜间',
              style: IconButton.styleFrom(
                backgroundColor: _palette.statusBackground,
                foregroundColor: _palette.textPrimary,
              ),
              onPressed: () {
                setState(() {
                  _appearance =
                      _appearance == _EditorAppearance.night
                          ? _EditorAppearance.day
                          : _EditorAppearance.night;
                });
              },
              icon: Icon(
                _appearance == _EditorAppearance.night
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: '调试',
              style: IconButton.styleFrom(
                backgroundColor: _palette.toolbarSecondaryBackground,
                foregroundColor: _palette.toolbarSecondaryForeground,
              ),
              onPressed: _isLoading || _isSaving ? null : _openDebugPage,
              icon: const Icon(Icons.bug_report_outlined, size: 18),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: _isSaving ? '保存中' : '保存',
              style: IconButton.styleFrom(
                backgroundColor: _palette.accent,
                foregroundColor: _palette.onAccent,
              ),
              onPressed: _isLoading || _isSaving ? null : _save,
              icon:
                  _isSaving
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.save_outlined, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueBanner(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final issues = _controller.analysisResult.issues;
        if (_isLoading || issues.isEmpty) {
          return const SizedBox.shrink();
        }

        final firstIssue = issues.first;
        final issueColor = switch (firstIssue.type) {
          IssueType.error => const Color(0xFFE85D75),
          IssueType.warning => const Color(0xFFF0B44C),
          IssueType.info => _palette.accent,
        };
        final issueLabel =
            issues.length == 1 ? '1 个问题' : '${issues.length} 个问题';

        return DecoratedBox(
          decoration: BoxDecoration(
            color: _palette.statusBackground,
            border: Border(
              top: BorderSide(color: _palette.border),
              bottom: BorderSide(color: _palette.border),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 18, color: issueColor),
                const SizedBox(width: 10),
                Text(
                  issueLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: issueColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '第 ${firstIssue.line + 1} 行: ${firstIssue.message}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _palette.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EditorDot extends StatelessWidget {
  const _EditorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ScriptSourceEditorAnalyzer extends AbstractAnalyzer {
  const _ScriptSourceEditorAnalyzer();

  @override
  Future<AnalysisResult> analyze(Code code) async {
    final baseResult = await const DefaultLocalAnalyzer().analyze(code);
    final draftIssues = analyzeScriptSourceDraftIssues(code.text);
    final mergedIssues = <Issue>[...baseResult.issues, ...draftIssues]
      ..sort(issueLineComparator);
    return AnalysisResult(issues: mergedIssues);
  }
}

enum _EditorAppearance { day, night }

class _EditorPalette {
  const _EditorPalette({
    required this.shellBackground,
    required this.panelBackground,
    required this.tabBackground,
    required this.border,
    required this.accent,
    required this.onAccent,
    required this.textPrimary,
    required this.textMuted,
    required this.selectionColor,
    required this.statusBackground,
    required this.toolbarSecondaryBackground,
    required this.toolbarSecondaryForeground,
    required this.appBarBackground,
    required this.appBarForeground,
    required this.shadowColor,
    required this.highlightTheme,
  });

  static const _EditorPalette night = _EditorPalette(
    shellBackground: Color(0xFF11151C),
    panelBackground: Color(0xFF0C1117),
    tabBackground: Color(0xFF151C25),
    border: Color(0xFF253040),
    accent: Color(0xFF53A7FF),
    onAccent: Color(0xFF03111F),
    textPrimary: Color(0xFFE6EDF3),
    textMuted: Color(0xFF8B98A9),
    selectionColor: Color(0x4D2F81F7),
    statusBackground: Color(0xFF111A24),
    toolbarSecondaryBackground: Color(0xFF1B2633),
    toolbarSecondaryForeground: Color(0xFFE6EDF3),
    appBarBackground: Color(0xFF11151C),
    appBarForeground: Color(0xFFE6EDF3),
    shadowColor: Color(0x55000000),
    highlightTheme: vs2015Theme,
  );

  static const _EditorPalette day = _EditorPalette(
    shellBackground: Color(0xFFF4F6FA),
    panelBackground: Color(0xFFFFFFFF),
    tabBackground: Color(0xFFECEFF5),
    border: Color(0xFFD8DEE8),
    accent: Color(0xFF1565C0),
    onAccent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1F2329),
    textMuted: Color(0xFF667085),
    selectionColor: Color(0x332F81F7),
    statusBackground: Color(0xFFF6F8FC),
    toolbarSecondaryBackground: Color(0xFFE8EEF7),
    toolbarSecondaryForeground: Color(0xFF1F2329),
    appBarBackground: Color(0xFFF4F6FA),
    appBarForeground: Color(0xFF1F2329),
    shadowColor: Color(0x180E1726),
    highlightTheme: vsTheme,
  );

  final Color shellBackground;
  final Color panelBackground;
  final Color tabBackground;
  final Color border;
  final Color accent;
  final Color onAccent;
  final Color textPrimary;
  final Color textMuted;
  final Color selectionColor;
  final Color statusBackground;
  final Color toolbarSecondaryBackground;
  final Color toolbarSecondaryForeground;
  final Color appBarBackground;
  final Color appBarForeground;
  final Color shadowColor;
  final Map<String, TextStyle> highlightTheme;
}

@visibleForTesting
String? validateScriptSourceDraft(String sourceCode) {
  final issues = analyzeScriptSourceDraftIssues(sourceCode);
  if (issues.isEmpty) {
    return null;
  }
  return issues.first.message;
}

@visibleForTesting
List<Issue> analyzeScriptSourceDraftIssues(String sourceCode) {
  final trimmed = sourceCode.trimLeft();
  final issues = <Issue>[];
  if (trimmed.isEmpty) {
    return const <Issue>[
      Issue(line: 0, message: '书享源内容不能为空。', type: IssueType.error),
    ];
  }
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return const <Issue>[
      Issue(
        line: 0,
        message:
            '检测到你粘贴的内容更像 JSON 配置，不是书享源脚本。当前版本只支持书享源；如果要编写书享源，请使用 `export default { meta, ... }`。',
        type: IssueType.error,
      ),
    ];
  }

  final exportLine = _findLineForPattern(
    sourceCode,
    RegExp(r'export\s+default|globalThis\.__sourceDefinition'),
  );
  if (exportLine == null) {
    return const <Issue>[
      Issue(
        line: 0,
        message:
            '书享源导出格式不支持。请使用 `export default { meta, ... }` 或 `globalThis.__sourceDefinition = { meta, ... }`。',
        type: IssueType.error,
      ),
    ];
  }

  final metaLine = _findLineForPattern(sourceCode, RegExp(r'\bmeta\s*:'));
  if (metaLine == null) {
    issues.add(
      Issue(
        line: exportLine,
        message: '书享源缺少 `meta` 对象。请至少提供 `meta.name`。',
        type: IssueType.error,
      ),
    );
  }

  final metaNameLine = _findLineForPattern(
    sourceCode,
    RegExp(r'\bmeta\s*:\s*\{[\s\S]*?\bname\s*:', multiLine: true),
  );
  if (metaNameLine == null) {
    issues.add(
      Issue(
        line: metaLine ?? exportLine,
        message: '书享源缺少 `meta.name`，无法识别名称。',
        type: IssueType.error,
      ),
    );
  }

  final missingMethods = _requiredScriptMethods
      .where(
        (methodName) =>
            !RegExp(
              '\\b(?:async\\s+)?$methodName\\s*\\(',
              multiLine: true,
            ).hasMatch(sourceCode),
      )
      .toList(growable: false);
  if (missingMethods.isNotEmpty) {
    issues.add(
      Issue(
        line: exportLine,
        message:
            '缺少必须方法：${missingMethods.join(' / ')}。至少需要 search/detail/chapters/content。',
        type: IssueType.error,
      ),
    );
  }

  return issues;
}

@visibleForTesting
String formatScriptSourceDraft(String sourceCode) {
  final normalized = sourceCode.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized.split('\n');
  final result = <String>[];
  final state = _ScriptFormatState();
  var indentLevel = 0;
  var previousWasBlank = false;

  for (final rawLine in lines) {
    final rightTrimmed = rawLine.replaceFirst(RegExp(r'[ \t]+$'), '');
    final trimmed = rightTrimmed.trimLeft();

    if (trimmed.isEmpty) {
      if (!previousWasBlank && result.isNotEmpty) {
        result.add('');
      }
      previousWasBlank = true;
      continue;
    }

    final leadingClosers = _countLeadingClosers(trimmed);
    final currentIndent = math.max(0, indentLevel - leadingClosers);
    result.add('${'  ' * currentIndent}$trimmed');
    previousWasBlank = false;

    indentLevel = math.max(
      0,
      currentIndent + _computeIndentDelta(trimmed, state),
    );
  }

  return result.join('\n').trimRight();
}

@visibleForTesting
String toFriendlyScriptEditorError(Object error) {
  final raw = error.toString().trim();
  if (raw.isEmpty) {
    return '保存失败，请检查书享源格式后重试。';
  }

  if (error is SourceScriptCompileException) {
    if (raw.contains('无法读取书享源导出的 meta')) {
      return '无法识别书享源格式。请确认内容使用 `export default` 导出，并包含 `meta.name`。当前版本不再支持 JSON 书享源配置导入。';
    }
    if (raw.contains('当前仅支持以')) {
      return '书享源导出格式不支持。请使用 `export default { meta, ... }` 或 `globalThis.__sourceDefinition = { meta, ... }`。';
    }
    if (raw.contains('书享源缺少必须方法')) {
      return '书享源缺少必须方法。至少需要实现 `search`、`detail`、`chapters`、`content`。';
    }
    return raw.replaceFirst('SourceScriptCompileException: ', '');
  }

  if (raw.contains('Script source code cannot be empty')) {
    return '书享源内容不能为空。';
  }

  return raw;
}

int? _findLineForPattern(String sourceCode, Pattern pattern) {
  final match = switch (pattern) {
    final RegExp regExp => regExp.firstMatch(sourceCode),
    _ => null,
  };
  if (match == null) {
    return null;
  }
  return '\n'.allMatches(sourceCode.substring(0, match.start)).length;
}

int _countLeadingClosers(String line) {
  var count = 0;
  for (final rune in line.runes) {
    final char = String.fromCharCode(rune);
    if (char == '}' || char == ']' || char == ')') {
      count++;
      continue;
    }
    if (char.trim().isEmpty) {
      continue;
    }
    break;
  }
  return count;
}

int _computeIndentDelta(String line, _ScriptFormatState state) {
  var opens = 0;
  var closes = 0;
  var escaping = false;
  var inLineComment = false;

  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    final next = i + 1 < line.length ? line[i + 1] : '';

    if (inLineComment) {
      break;
    }

    if (state.inBlockComment) {
      if (char == '*' && next == '/') {
        state.inBlockComment = false;
        i++;
      }
      continue;
    }

    if (state.stringDelimiter != null) {
      if (escaping) {
        escaping = false;
        continue;
      }
      if (char == r'\') {
        escaping = true;
        continue;
      }
      if (char == state.stringDelimiter) {
        state.stringDelimiter = null;
      }
      continue;
    }

    if (char == '/' && next == '/') {
      inLineComment = true;
      continue;
    }
    if (char == '/' && next == '*') {
      state.inBlockComment = true;
      i++;
      continue;
    }
    if (char == '\'' || char == '"' || char == '`') {
      state.stringDelimiter = char;
      continue;
    }
    if (char == '{' || char == '[' || char == '(') {
      opens++;
      continue;
    }
    if (char == '}' || char == ']' || char == ')') {
      closes++;
    }
  }

  return opens - closes;
}

class _ScriptFormatState {
  bool inBlockComment = false;
  String? stringDelimiter;
}

const List<String> _requiredScriptMethods = <String>[
  'search',
  'detail',
  'chapters',
  'content',
];

const List<String> _scriptSourceAutocompleteWords = <String>[
  'createDiscoverCategory',
  'createBook',
  'createChapter',
  'createContent',
  'requestJson',
  'requestJsonLite',
  'meta',
  'name',
  'group',
  'author',
  'description',
  'domains',
  'homepage',
  'enabled',
  'capabilities',
  'rateLimits',
  'init',
  'discoverCategories',
  'discoverBooks',
  'search',
  'detail',
  'chapters',
  'content',
  'ctx',
  'task',
  'book',
  'chapter',
  'keyword',
  'category',
  'page',
  'pageSize',
  'session',
  'http',
  'browser',
  'cookie',
  'cache',
  'html',
  'utils',
  'crypto',
  'log',
  'request',
  'isChallenge',
  'challenge',
  'parse',
  'collect',
  'text',
  'absoluteUrl',
  'get',
  'set',
  'clear',
  'getAll',
  'extra',
  'debug',
  'detailUrl',
  'tocUrl',
  'latestChapter',
  'wordCount',
  'updateTime',
  'tags',
  'responseType',
  'headers',
  'queryParameters',
  'body',
  'json',
  'text',
  'statusCode',
];
