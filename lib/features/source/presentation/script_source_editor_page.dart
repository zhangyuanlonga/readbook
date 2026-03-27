import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
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
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDirty = false;
  bool _isApplyingEditorValue = false;

  bool get _isEditingExisting =>
      widget.scriptSourceId?.trim().isNotEmpty == true && _source != null;

  Map<String, TextStyle> get _editorThemeStyles {
    final root = atomOneDarkTheme['root'] ?? const TextStyle(color: Colors.white);
    return <String, TextStyle>{
      ...atomOneDarkTheme,
      'root': root.copyWith(
        color: Colors.white,
        backgroundColor: Colors.black,
      ),
    };
  }

  @override
  void initState() {
    super.initState();
    _sourceRuntimeFacade =
        widget.sourceRuntimeFacade ?? SourceRuntimeFacade.instance;
    _controller = CodeController(
      text: sourceScriptTemplateV1,
      language: javascript,
    );
    _controller.addListener(_handleEditorChanged);
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

  Future<void> _applySourceCode(
    String value, {
    required bool markDirty,
  }) async {
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
        _showTransientMessage('未找到要编辑的脚本配置。');
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
      _showTransientMessage('加载脚本配置失败：$error');
    }
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
      context.pop(_source == null ? '脚本配置已新增。' : '脚本配置已保存。');
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

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_isDirty || _isSaving) {
      return true;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('放弃未保存内容？'),
          content: const Text('当前脚本内容还没有保存，离开后本次修改将丢失。'),
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
              title: _isEditingExisting ? '脚本调试' : '新建脚本调试',
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
        appBar: AppBar(
          title: Text(_isEditingExisting ? '编辑脚本配置' : '新增脚本配置'),
          actions: [
            OutlinedButton(
              onPressed: _isLoading || _isSaving ? null : _openDebugPage,
              child: const Text('调试'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _isLoading || _isSaving ? null : _save,
              child:
                  _isSaving
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('保存'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: ColoredBox(
          color: Colors.black,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                if (_isLoading) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      inputDecorationTheme: const InputDecorationTheme(
                        filled: false,
                        fillColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
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
                        background: Colors.black,
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Menlo, Consolas, "Courier New", monospace',
                          fontSize: 13,
                          height: 1.45,
                        ),
                        gutterStyle: const GutterStyle(
                          width: 44,
                          margin: 12,
                          background: Colors.black,
                          textStyle: TextStyle(
                            color: Color(0xFF7D8590),
                            fontSize: 12,
                          ),
                          showErrors: false,
                        ),
                        smartDashesType: SmartDashesType.disabled,
                        smartQuotesType: SmartQuotesType.disabled,
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
}

@visibleForTesting
String? validateScriptSourceDraft(String sourceCode) {
  final trimmed = sourceCode.trimLeft();
  if (trimmed.isEmpty) {
    return '脚本内容不能为空。';
  }
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return '检测到你粘贴的内容更像旧规则 JSON，不是脚本配置。请返回“规则配置”页导入；如果要写脚本配置，请使用 `export default { meta, ... }`。';
  }
  if (!trimmed.contains('export default') &&
      !trimmed.contains('globalThis.__sourceDefinition')) {
    return '脚本导出格式不支持。请使用 `export default { meta, ... }` 或 `globalThis.__sourceDefinition = { meta, ... }`。';
  }
  if (!RegExp(r'\bmeta\s*:').hasMatch(trimmed)) {
    return '脚本缺少 `meta` 对象。请至少提供 `meta.name`。';
  }
  if (!RegExp(r'\bname\s*:').hasMatch(trimmed)) {
    return '脚本缺少 `meta.name`，无法识别配置名称。';
  }
  return null;
}

@visibleForTesting
String toFriendlyScriptEditorError(Object error) {
  final raw = error.toString().trim();
  if (raw.isEmpty) {
    return '保存失败，请检查脚本格式后重试。';
  }

  if (error is SourceScriptCompileException) {
    if (raw.contains('无法读取书源导出的 meta')) {
      return '无法识别脚本配置格式。请确认内容使用 `export default` 导出，并包含 `meta.name`。如果你粘贴的是旧规则 JSON，请返回“规则配置”页导入。';
    }
    if (raw.contains('当前仅支持以')) {
      return '脚本导出格式不支持。请使用 `export default { meta, ... }` 或 `globalThis.__sourceDefinition = { meta, ... }`。';
    }
    if (raw.contains('书源缺少必须方法')) {
      return '脚本缺少必须方法。至少需要实现 `search`、`detail`、`chapters`、`content`。';
    }
    return raw.replaceFirst('SourceScriptCompileException: ', '');
  }

  if (raw.contains('Script source code cannot be empty')) {
    return '脚本内容不能为空。';
  }

  return raw;
}
