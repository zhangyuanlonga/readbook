import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/import_export_copy.dart';
import '../../../app/widgets/import_export_task_overlay.dart';
import '../../../core/auth/auth_session_store.dart';
import '../../../core/mobile_features/mobile_feature_service.dart';
import '../application/source_runtime_facade.dart';
import '../providers.dart';

class ScriptSourcePasteImportPage extends ConsumerStatefulWidget {
  const ScriptSourcePasteImportPage({super.key, this.sourceRuntimeFacade});

  final SourceRuntimeFacade? sourceRuntimeFacade;

  @override
  ConsumerState<ScriptSourcePasteImportPage> createState() =>
      _ScriptSourcePasteImportPageState();
}

class _ScriptSourcePasteImportPageState
    extends ConsumerState<ScriptSourcePasteImportPage> {
  late final SourceRuntimeFacade _sourceRuntimeFacade;
  late final TextEditingController _controller;
  late final AuthSessionStore _authSessionStore;
  late final MobileFeatureService _mobileFeatureService;

  bool _isImporting = false;
  ImportExportTaskStatus? _taskStatus;

  @override
  void initState() {
    super.initState();
    _sourceRuntimeFacade =
        widget.sourceRuntimeFacade ?? ref.read(sourceRuntimeFacadeProvider);
    _authSessionStore = ref.read(sourceAuthSessionStoreProvider);
    _mobileFeatureService = ref.read(sourceMobileFeatureServiceProvider);
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
      _taskStatus = ImportExportCopy.running(
        title: '正在导入书源',
        message: '正在校验粘贴内容并准备保存…',
      );
    });

    try {
      if (!await _ensureCanImport()) {
        return;
      }
      if (mounted) {
        setState(() {
          _taskStatus = ImportExportCopy.running(
            title: '正在导入书源',
            message: '正在解析书源格式并保存到书源列表…',
          );
        });
      }
      final saved = await _sourceRuntimeFacade.saveScriptSource(
        sourceCode: sourceCode,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _taskStatus = ImportExportCopy.success(
          title: '书源导入完成',
          message: '已完成书源保存，即将返回书源列表。',
          detail: saved.name,
          progress: 1,
        );
      });
      context.pop('已导入书源：${saved.name}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _taskStatus = ImportExportCopy.failure(
          title: '导入书源失败',
          message: _toFriendlyImportError(error),
        );
      });
      _showMessage(_toFriendlyImportError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _taskStatus = null;
        });
      }
    }
  }

  Future<bool> _ensureCanImport() async {
    // 默认限制为 10 个书源
    const int defaultQuotaLimit = 10;

    // 获取当前书源数量
    final currentSources = await _sourceRuntimeFacade.listScriptSources();
    final currentCount = currentSources.length;
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
      _showMessage(
        quotaLimit == defaultQuotaLimit
            ? '最多只能导入 $defaultQuotaLimit 个书源。'
            : '已达到书源导入上限（最多 $quotaLimit 个）。',
      );
      return false;
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
    return ImportExportTaskOverlay(
      status: _taskStatus,
      child: Scaffold(
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
                    maxWidth:
                        constraints.maxWidth > 880 ? 880 : double.infinity,
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
                                    : const Icon(
                                      Icons.content_paste_go_rounded,
                                    ),
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
      ),
    );
  }
}
