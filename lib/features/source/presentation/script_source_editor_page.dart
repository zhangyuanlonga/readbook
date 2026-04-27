import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/vs.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight/languages/javascript.dart';

import '../../../core/auth/auth_session_store.dart';
import '../../../core/mobile_features/mobile_feature_service.dart';
import '../../../domain/entities/script_source.dart';
import '../../../runtime/sources/source_script_compiler.dart'
    show SourceScriptCompileException;
import '../../../runtime/sources/source_script_template.dart';
import '../application/source_runtime_facade.dart';
import '../providers.dart';
import 'script_source_debug_page.dart';

class ScriptSourceEditorPage extends ConsumerStatefulWidget {
  const ScriptSourceEditorPage({
    super.key,
    this.scriptSourceId,
    this.sourceRuntimeFacade,
  });

  final String? scriptSourceId;
  final SourceRuntimeFacade? sourceRuntimeFacade;

  @override
  ConsumerState<ScriptSourceEditorPage> createState() =>
      _ScriptSourceEditorPageState();
}

enum _EditorToolbarMenuAction { format, search, toggleAppearance, debug }

class _ScriptSourceEditorPageState
    extends ConsumerState<ScriptSourceEditorPage> {
  late final SourceRuntimeFacade _sourceRuntimeFacade;
  late final CodeController _controller;
  late final AuthSessionStore _authSessionStore;
  late final MobileFeatureService _mobileFeatureService;
  final ValueNotifier<_EditorIssueSummary> _issueSummaryNotifier =
      ValueNotifier<_EditorIssueSummary>(_EditorIssueSummary.empty);

  ScriptSource? _source;
  _EditorAppearance _appearance = _EditorAppearance.night;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDirty = false;
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
      1 || 2 => 58,
      3 => 66,
      _ => 74,
    };
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

  SystemUiOverlayStyle get _systemOverlayStyle {
    final base =
        _appearance == _EditorAppearance.night
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;
    return base.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }

  @override
  void initState() {
    super.initState();
    _sourceRuntimeFacade =
        widget.sourceRuntimeFacade ?? ref.read(sourceRuntimeFacadeProvider);
    _authSessionStore = ref.read(sourceAuthSessionStoreProvider);
    _mobileFeatureService = ref.read(sourceMobileFeatureServiceProvider);
    _controller = CodeController(
      text: '',
      language: javascript,
      analyzer: const _ScriptSourceEditorAnalyzer(),
    );
    _controller.autocompleter.setCustomWords(_scriptSourceAutocompleteWords);
    _controller.addListener(_handleEditorChanged);
    _controller.addListener(_handleAnalysisResultChanged);
    final scriptSourceId = widget.scriptSourceId?.trim() ?? '';
    if (scriptSourceId.isEmpty) {
      _isApplyingEditorValue = true;
      _controller.fullText = sourceScriptTemplateV1;
      _isApplyingEditorValue = false;
      _isLoading = false;
    }
    _refreshIssueSummary();
    if (scriptSourceId.isNotEmpty) {
      unawaited(_loadInitialValue());
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleEditorChanged);
    _controller.removeListener(_handleAnalysisResultChanged);
    _issueSummaryNotifier.dispose();
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
    _refreshIssueSummary();
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
        _showTransientMessage('未找到要编辑的书源。');
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
      _refreshIssueSummary();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      _showTransientMessage('加载书源失败：$error');
    }
  }

  void _handleAnalysisResultChanged() {
    _refreshIssueSummary();
  }

  void _refreshIssueSummary() {
    final next = _EditorIssueSummary.fromIssues(
      _controller.analysisResult.issues,
    );
    if (_issueSummaryNotifier.value == next) {
      return;
    }
    _issueSummaryNotifier.value = next;
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

    if (!_isEditingExisting) {
      final canSave = await _ensureCanCreateSource();
      if (!canSave) {
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }

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
      context.pop(_source == null ? '书源已新增。' : '书源已保存。');
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

  Future<bool> _ensureCanCreateSource() async {
    // 默认限制为 10 个书源
    const int defaultQuotaLimit = 10;

    // 获取当前书源数量
    final sources = await _sourceRuntimeFacade.listScriptSources();
    final currentCount = sources.length;
    var quotaLimit = defaultQuotaLimit;

    // 尝试获取已登录用户的权限配置（网络请求可能失败）
    final session = await _authSessionStore.getSession();
    try {
      final modules = await (session == null
              ? _mobileFeatureService.fetchPublicModules()
              : _mobileFeatureService.fetchMyModules())
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              // 超时时抛出异常，走 catch 分支
              throw TimeoutException('Request timeout');
            },
          );

      for (final item in modules) {
        if (item.code == 'source_import') {
          quotaLimit = item.quotaLimit;
          break;
        }
      }
    } catch (e) {
      // 网络异常或超时，使用默认限制
      debugPrint('获取会员权限失败，使用默认限制: $e');
    }

    if (quotaLimit >= 0 && currentCount >= quotaLimit) {
      _showTransientMessage(
        quotaLimit == defaultQuotaLimit
            ? '最多只能创建 $defaultQuotaLimit 个书源。'
            : '已达到书源导入上限（最多 $quotaLimit 个）。',
      );
      return false;
    }

    return true;
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
    _refreshIssueSummary();
    if (!mounted) {
      return;
    }
    setState(() {
      _isDirty = true;
    });
    _showTransientMessage('已格式化书源脚本。');
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
          content: const Text('当前书源内容还没有保存，离开后本次修改将丢失。'),
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
              title: _isEditingExisting ? '书源调试' : '新建书源调试',
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
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: _systemOverlayStyle,
        child: Scaffold(
          body: ColoredBox(
            color: _palette.shellBackground,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  if (_isLoading) const LinearProgressIndicator(minHeight: 2),
                  _buildEditorToolbar(context),
                  _EditorIssueBanner(
                    issueSummaryListenable: _issueSummaryNotifier,
                    isLoading: _isLoading,
                    palette: _palette,
                  ),
                  Expanded(
                    child:
                        _isLoading
                            ? _buildEditorLoadingState(context)
                            : _buildCodeEditor(context),
                  ),
                ],
              ),
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
              '正在加载书源',
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
            padding: const EdgeInsets.only(top: 8, right: 12, bottom: 12),
            textStyle: TextStyle(
              color: _palette.textPrimary,
              fontFamily: 'Menlo, Consolas, "Courier New", monospace',
              fontSize: 12.5,
              height: 1.42,
              letterSpacing: 0.05,
            ),
            gutterStyle: GutterStyle(
              width: _gutterWidth,
              margin: 6,
              background: _palette.tabBackground,
              textStyle: TextStyle(color: _palette.textMuted, fontSize: 11),
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
    return RepaintBoundary(
      child: ColoredBox(
        color: _palette.tabBackground,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
          child: Row(
            children: [
              IconButton(
                tooltip: '返回',
                onPressed: () => unawaited(_handleBackPressed()),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _palette.textPrimary,
                  size: 16,
                ),
              ),
              const Spacer(),
              if (_isDirty)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: _palette.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 6),
              ..._buildToolbarActions(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildToolbarActions(BuildContext context) {
    final actions = <Widget>[
      _buildToolbarButton(
        tooltip: '调试',
        onPressed: _isLoading || _isSaving ? null : _openDebugPage,
        icon: const Icon(Icons.bug_report_outlined, size: 18),
        backgroundColor: _palette.toolbarSecondaryBackground,
        foregroundColor: _palette.toolbarSecondaryForeground,
      ),
      const SizedBox(width: 6),
      IconButton.filled(
        tooltip: _isSaving ? '保存中' : '保存',
        style: IconButton.styleFrom(
          backgroundColor: _palette.accent,
          foregroundColor: _palette.onAccent,
          visualDensity: VisualDensity.compact,
          minimumSize: const Size(34, 34),
          padding: const EdgeInsets.all(7),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
      const SizedBox(width: 6),
      PopupMenuButton<_EditorToolbarMenuAction>(
        tooltip: '更多工具',
        enabled: !_isLoading,
        onSelected: _handleToolbarMenuAction,
        itemBuilder:
            (context) => [
              const PopupMenuItem(
                value: _EditorToolbarMenuAction.search,
                child: Text('查找'),
              ),
              const PopupMenuItem(
                value: _EditorToolbarMenuAction.format,
                child: Text('格式化'),
              ),
              PopupMenuItem(
                value: _EditorToolbarMenuAction.toggleAppearance,
                child: Text(
                  _appearance == _EditorAppearance.night ? '切换到日间' : '切换到夜间',
                ),
              ),
              const PopupMenuItem(
                value: _EditorToolbarMenuAction.debug,
                child: Text('调试'),
              ),
            ],
        child: Container(
          width: 38,
          height: 34,
          decoration: BoxDecoration(
            color: _palette.statusBackground,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _palette.border),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.more_vert_rounded,
            size: 17,
            color: _palette.textPrimary,
          ),
        ),
      ),
    ];
    return actions;
  }

  Widget _buildToolbarButton({
    required String tooltip,
    required VoidCallback? onPressed,
    required Widget icon,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: backgroundColor ?? _palette.statusBackground,
        foregroundColor: foregroundColor ?? _palette.textPrimary,
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(34, 34),
        padding: const EdgeInsets.all(7),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      icon: icon,
    );
  }

  void _toggleAppearance() {
    setState(() {
      _appearance =
          _appearance == _EditorAppearance.night
              ? _EditorAppearance.day
              : _EditorAppearance.night;
    });
  }

  void _handleToolbarMenuAction(_EditorToolbarMenuAction action) {
    switch (action) {
      case _EditorToolbarMenuAction.search:
        _controller.showSearch();
        break;
      case _EditorToolbarMenuAction.format:
        unawaited(_formatSourceCode());
        break;
      case _EditorToolbarMenuAction.toggleAppearance:
        _toggleAppearance();
        break;
      case _EditorToolbarMenuAction.debug:
        unawaited(_openDebugPage());
        break;
    }
  }
}

class _EditorIssueBanner extends StatelessWidget {
  const _EditorIssueBanner({
    required this.issueSummaryListenable,
    required this.isLoading,
    required this.palette,
  });

  final ValueNotifier<_EditorIssueSummary> issueSummaryListenable;
  final bool isLoading;
  final _EditorPalette palette;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<_EditorIssueSummary>(
        valueListenable: issueSummaryListenable,
        builder: (context, summary, _) {
          if (isLoading || !summary.hasIssues) {
            return const SizedBox.shrink();
          }

          final firstIssue = summary.firstIssue!;
          final issueColor = switch (firstIssue.type) {
            IssueType.error => const Color(0xFFE85D75),
            IssueType.warning => const Color(0xFFF0B44C),
            IssueType.info => palette.accent,
          };
          final issueLabel =
              summary.count == 1 ? '1 个问题' : '${summary.count} 个问题';

          return DecoratedBox(
            decoration: BoxDecoration(
              color: palette.statusBackground,
              border: Border(
                top: BorderSide(color: palette.border),
                bottom: BorderSide(color: palette.border),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: issueColor,
                  ),
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
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EditorIssueSummary {
  const _EditorIssueSummary({required this.count, required this.firstIssue});

  static const _EditorIssueSummary empty = _EditorIssueSummary(
    count: 0,
    firstIssue: null,
  );

  final int count;
  final Issue? firstIssue;

  bool get hasIssues => count > 0 && firstIssue != null;

  factory _EditorIssueSummary.fromIssues(List<Issue> issues) {
    if (issues.isEmpty) {
      return empty;
    }
    return _EditorIssueSummary(count: issues.length, firstIssue: issues.first);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _EditorIssueSummary &&
        other.count == count &&
        other.firstIssue?.line == firstIssue?.line &&
        other.firstIssue?.message == firstIssue?.message &&
        other.firstIssue?.type == firstIssue?.type;
  }

  @override
  int get hashCode => Object.hash(
    count,
    firstIssue?.line,
    firstIssue?.message,
    firstIssue?.type,
  );
}

class _ScriptSourceEditorAnalyzer extends AbstractAnalyzer {
  const _ScriptSourceEditorAnalyzer();

  @override
  Future<AnalysisResult> analyze(Code code) async {
    final baseResult = await const DefaultLocalAnalyzer().analyze(code);
    final draftIssues = _analyzeScriptSourceDraftIssues(
      code.text,
      mode: _DraftAnalysisMode.light,
    );
    final mergedIssues = <Issue>[...baseResult.issues, ...draftIssues]
      ..sort(issueLineComparator);
    return AnalysisResult(issues: mergedIssues);
  }
}

enum _DraftAnalysisMode { light, full }

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
    shellBackground: Color(0xFF0C1117),
    panelBackground: Color(0xFF070A0E),
    tabBackground: Color(0xFF0C1117),
    border: Color(0xFF1A2430),
    accent: Color(0xFF53A7FF),
    onAccent: Color(0xFF03111F),
    textPrimary: Color(0xFFE6EDF3),
    textMuted: Color(0xFF7D8999),
    selectionColor: Color(0x4D2F81F7),
    statusBackground: Color(0xFF111821),
    toolbarSecondaryBackground: Color(0xFF17202B),
    toolbarSecondaryForeground: Color(0xFFE6EDF3),
    appBarBackground: Color(0xFF05070A),
    appBarForeground: Color(0xFFE6EDF3),
    shadowColor: Color(0x00000000),
    highlightTheme: vs2015Theme,
  );

  static const _EditorPalette day = _EditorPalette(
    shellBackground: Color(0xFFECEFF5),
    panelBackground: Color(0xFFFFFFFF),
    tabBackground: Color(0xFFECEFF5),
    border: Color(0xFFD8DEE8),
    accent: Color(0xFF1565C0),
    onAccent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1F2329),
    textMuted: Color(0xFF667085),
    selectionColor: Color(0x332F81F7),
    statusBackground: Color(0xFFF2F5FA),
    toolbarSecondaryBackground: Color(0xFFE3EBF7),
    toolbarSecondaryForeground: Color(0xFF163B6D),
    appBarBackground: Color(0xFFF4F6FA),
    appBarForeground: Color(0xFF1F2329),
    shadowColor: Color(0x00000000),
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
  final issues = _analyzeScriptSourceDraftIssues(
    sourceCode,
    mode: _DraftAnalysisMode.full,
  );
  if (issues.isEmpty) {
    return null;
  }
  return issues.first.message;
}

@visibleForTesting
List<Issue> analyzeScriptSourceDraftIssues(String sourceCode) {
  return _analyzeScriptSourceDraftIssues(
    sourceCode,
    mode: _DraftAnalysisMode.full,
  );
}

List<Issue> _analyzeScriptSourceDraftIssues(
  String sourceCode, {
  required _DraftAnalysisMode mode,
}) {
  final trimmed = sourceCode.trimLeft();
  final issues = <Issue>[];
  if (trimmed.isEmpty) {
    return const <Issue>[
      Issue(line: 0, message: '书源内容不能为空。', type: IssueType.error),
    ];
  }
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return const <Issue>[
      Issue(
        line: 0,
        message:
            '检测到你粘贴的内容更像 JSON 配置，不是书源脚本。当前版本只支持脚本书源；如果要编写书源，请使用 `export default { meta, ... }`。',
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
            '书源导出格式不支持。请使用 `export default { meta, ... }` 或 `globalThis.__sourceDefinition = { meta, ... }`。',
        type: IssueType.error,
      ),
    ];
  }

  final metaLine = _findLineForPattern(sourceCode, RegExp(r'\bmeta\s*:'));
  if (metaLine == null) {
    issues.add(
      Issue(
        line: exportLine,
        message: '书源缺少 `meta` 对象。请至少提供 `meta.name`。',
        type: IssueType.error,
      ),
    );
  }

  if (mode == _DraftAnalysisMode.light) {
    return issues;
  }

  final metaNameLine = _findLineForPattern(
    sourceCode,
    RegExp(r'\bmeta\s*:\s*\{[\s\S]*?\bname\s*:', multiLine: true),
  );
  if (metaNameLine == null) {
    issues.add(
      Issue(
        line: metaLine ?? exportLine,
        message: '书源缺少 `meta.name`，无法识别名称。',
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
    return '保存失败，请检查书源格式后重试。';
  }

  if (error is SourceScriptCompileException) {
    if (raw.contains('无法读取书源导出的 meta')) {
      return '无法识别书源格式。请确认内容使用 `export default` 导出，并包含 `meta.name`。当前版本不再支持 JSON 书源配置导入。';
    }
    if (raw.contains('当前仅支持以')) {
      return '书源导出格式不支持。请使用 `export default { meta, ... }` 或 `globalThis.__sourceDefinition = { meta, ... }`。';
    }
    if (raw.contains('书源缺少必须方法')) {
      return '书源缺少必须方法。至少需要实现 `search`、`detail`、`chapters`、`content`。';
    }
    return raw.replaceFirst('SourceScriptCompileException: ', '');
  }

  if (raw.contains('Script source code cannot be empty')) {
    return '书源内容不能为空。';
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
  'checkKeyword',
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
