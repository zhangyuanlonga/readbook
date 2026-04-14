import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session_store.dart';
import '../../../core/mobile_features/mobile_feature_service.dart';
import '../application/source_runtime_facade.dart';

class ScriptSourcePasteImportPage extends StatefulWidget {
  const ScriptSourcePasteImportPage({super.key, this.sourceRuntimeFacade});

  final SourceRuntimeFacade? sourceRuntimeFacade;

  @override
  State<ScriptSourcePasteImportPage> createState() =>
      _ScriptSourcePasteImportPageState();
}

class _ScriptSourcePasteImportPageState
    extends State<ScriptSourcePasteImportPage> {
  late final SourceRuntimeFacade _sourceRuntimeFacade;
  late final TextEditingController _controller;
  final AuthSessionStore _authSessionStore = AuthSessionStore();
  final MobileFeatureService _mobileFeatureService = MobileFeatureService();

  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _sourceRuntimeFacade =
        widget.sourceRuntimeFacade ?? SourceRuntimeFacade.instance;
    _controller = TextEditingController();
    unawaited(_tryPrefillFromClipboard());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _tryPrefillFromClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim() ?? '';
      if (!mounted || text.isEmpty) {
        return;
      }
      _controller.text = text;
    } catch (_) {}
  }

  Future<void> _import() async {
    if (_isImporting) {
      return;
    }

    final sourceCode = _controller.text.trim();
    if (sourceCode.isEmpty) {
      _showMessage('请先粘贴书源脚本。');
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      if (!await _ensureCanImport()) {
        return;
      }
      final saved = await _sourceRuntimeFacade.saveScriptSource(
        sourceCode: sourceCode,
      );
      if (!mounted) {
        return;
      }
      context.pop('已导入书源：${saved.name}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(_toFriendlyImportError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<bool> _ensureCanImport() async {
    final session = await _authSessionStore.getSession();
    if (session == null) {
      _showMessage('登录后可导入书源。');
      return false;
    }

    try {
      final modules = await _mobileFeatureService.fetchMyModules();
      var quotaLimit = 10;
      for (final item in modules) {
        if (item.code == 'source_import') {
          quotaLimit = item.quotaLimit;
          break;
        }
      }
      if (quotaLimit >= 0) {
        final currentSources = await _sourceRuntimeFacade.listScriptSources();
        if (currentSources.length >= quotaLimit) {
          _showMessage('普通用户最多导入 $quotaLimit 个书源，开通会员可不限量。');
          return false;
        }
      }
    } catch (_) {
      final currentSources = await _sourceRuntimeFacade.listScriptSources();
      if (currentSources.length >= 10) {
        _showMessage('普通用户最多导入 10 个书源，开通会员可不限量。');
        return false;
      }
    }

    return true;
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _toFriendlyImportError(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) {
      return '导入失败，请检查书源格式后重试。';
    }
    if (raw.contains('书源缺少必须方法')) {
      return '书源缺少必须方法，至少需要实现 search / detail / chapters / content。';
    }
    if (raw.contains('无法读取书源导出的 meta')) {
      return '无法识别书源格式，请确认内容使用 export default 导出，并包含 meta.name。';
    }
    if (raw.contains('书源导出格式不支持') || raw.contains('当前仅支持以')) {
      return '书源导出格式不支持，请使用 export default { meta, ... }。';
    }
    if (raw.contains('Script source code cannot be empty')) {
      return '书源内容不能为空。';
    }
    return raw.replaceFirst('SourceScriptCompileException: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('粘贴导入'),
        actions: [
          TextButton(
            onPressed: _isImporting ? null : _tryPrefillFromClipboard,
            child: const Text('读取剪贴板'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth > 880 ? 880 : double.infinity,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '将完整书源脚本粘贴到下方，导入后会直接保存到书源列表。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          keyboardType: TextInputType.multiline,
                          decoration: const InputDecoration(
                            hintText:
                                '请粘贴 export default { meta, ... } 形式的书源脚本',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isImporting ? null : _import,
                          icon:
                              _isImporting
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.content_paste_go_rounded),
                          label: Text(_isImporting ? '导入中...' : '导入书源'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
