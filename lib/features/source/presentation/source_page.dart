import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../domain/entities/script_source.dart';
import '../application/source_runtime_facade.dart';

class SourcePage extends StatefulWidget {
  const SourcePage({
    super.key,
    this.sourceRuntimeFacade,
    this.bootstrapOnInit = true,
    this.enableRouterNavigation = true,
  });

  final SourceRuntimeFacade? sourceRuntimeFacade;
  final bool bootstrapOnInit;
  final bool enableRouterNavigation;

  @override
  State<SourcePage> createState() => _SourcePageState();
}

class _SourcePageState extends State<SourcePage> {
  late final SourceRuntimeFacade _sourceRuntimeFacade;

  bool _isReloadingScriptSources = false;
  final Set<String> _savingScriptSourceIds = <String>{};
  final Set<String> _changingEnabledScriptSourceIds = <String>{};
  final Set<String> _deletingScriptSourceIds = <String>{};

  @override
  void initState() {
    super.initState();
    _sourceRuntimeFacade =
        widget.sourceRuntimeFacade ?? SourceRuntimeFacade.instance;
    if (widget.bootstrapOnInit) {
      unawaited(_reloadScriptSourcesSilently());
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final canPopRoute =
        widget.enableRouterNavigation
            ? context.canPop()
            : Navigator.of(context).canPop();

    return PopScope<void>(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted) {
          return;
        }
        if (widget.enableRouterNavigation) {
          context.go('/mine');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _handleBackNavigation,
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('脚本源'),
          actions: [
            IconButton(
              tooltip: '重载脚本源',
              onPressed:
                  _isReloadingScriptSources
                      ? null
                      : () => unawaited(_reloadScriptSources()),
              icon:
                  _isReloadingScriptSources
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.sync_rounded),
            ),
            IconButton(
              tooltip: '新增脚本源',
              onPressed:
                  _savingScriptSourceIds.isNotEmpty
                      ? null
                      : () => unawaited(_openScriptSourceEditorPage()),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surfaceContainerLow,
              ],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AppLayout.pageContentMaxWidth(
                    context,
                    maxWidth: AppLayout.searchContentMaxWidth,
                  ),
                ),
                child: StreamBuilder<List<ScriptSource>>(
                  stream: _sourceRuntimeFacade.watchScriptSources(),
                  builder: (context, snapshot) {
                    final sources = [...(snapshot.data ?? const <ScriptSource>[])]
                      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        16,
                        horizontal,
                        16 + bottomSafe,
                      ),
                      children: [
                        _buildIntroCard(context),
                        const SizedBox(height: 12),
                        if (sources.isEmpty)
                          _buildEmptyCard(context)
                        else
                          ...sources.map((source) => _buildSourceCard(context, source)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleBackNavigation() {
    if (widget.enableRouterNavigation && context.canPop()) {
      context.pop();
      return;
    }
    if (widget.enableRouterNavigation) {
      context.go('/mine');
      return;
    }
    Navigator.of(context).maybePop();
  }

  Widget _buildIntroCard(BuildContext context) {
    return Card(
      shape: _buildOutlinedCardShape(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '脚本源是当前唯一书源规范',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '此页面仅管理脚本源，只接受符合规范的 JS 脚本配置。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      _savingScriptSourceIds.isNotEmpty
                          ? null
                          : () => unawaited(_openScriptSourceEditorPage()),
                  icon: const Icon(Icons.add),
                  label: const Text('新增脚本源'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _isReloadingScriptSources
                          ? null
                          : () => unawaited(_reloadScriptSources()),
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('重载'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context) {
    return Card(
      shape: _buildOutlinedCardShape(context),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.javascript_rounded, size: 30),
            const SizedBox(height: 12),
            Text(
              '当前没有脚本源',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '新建一个脚本源，或直接在编辑页粘贴符合规范的 JS 配置。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => unawaited(_openScriptSourceEditorPage()),
              icon: const Icon(Icons.add),
              label: const Text('新增脚本源'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard(BuildContext context, ScriptSource source) {
    final isSaving = _savingScriptSourceIds.contains(source.id);
    final isChangingEnabled = _changingEnabledScriptSourceIds.contains(
      source.id,
    );
    final isDeleting = _deletingScriptSourceIds.contains(source.id);
    final busy = isSaving || isChangingEnabled || isDeleting;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: _buildOutlinedCardShape(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    source.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: source.enabled,
                  onChanged:
                      busy
                          ? null
                          : (value) =>
                              unawaited(_setScriptSourceEnabled(source, value)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (source.group != null && source.group!.trim().isNotEmpty)
                  _buildCompactChip(context, source.group!),
                if (source.author != null && source.author!.trim().isNotEmpty)
                  _buildCompactChip(context, '作者：${source.author!}'),
                _buildCompactChip(context, source.enabled ? '已启用' : '未启用'),
              ],
            ),
            if (source.description != null && source.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(source.description!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 10),
            Text(
              '更新时间：${_formatDateTime(source.updatedAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      busy
                          ? null
                          : () => unawaited(
                            _openScriptSourceEditorPage(source: source),
                          ),
                  icon:
                      isSaving
                          ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.edit_rounded),
                  label: const Text('编辑'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      busy
                          ? null
                          : () => unawaited(_deleteScriptSource(source)),
                  icon:
                      isDeleting
                          ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.delete_outline_rounded),
                  label: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }

  Future<void> _reloadScriptSourcesSilently() async {
    try {
      await _sourceRuntimeFacade.reloadScriptSources();
    } catch (_) {
      // Ignore bootstrap failures here and surface them on manual actions.
    }
  }

  Future<void> _reloadScriptSources() async {
    if (_isReloadingScriptSources) {
      return;
    }
    setState(() {
      _isReloadingScriptSources = true;
    });
    try {
      final report = await _sourceRuntimeFacade.reloadScriptSources();
      if (!mounted) {
        return;
      }
      if (report.failures.isEmpty) {
        _showMessage('脚本源已重载。');
      } else {
        _showMessage('已重载 ${report.loaded.length} 个脚本源，${report.failures.length} 个失败。');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('重载脚本源失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isReloadingScriptSources = false;
        });
      }
    }
  }

  Future<void> _openScriptSourceEditorPage({ScriptSource? source}) async {
    final queryParameters = <String, String>{
      if (source != null) 'id': source.id,
    };
    final result = await context.push<String>(
      Uri(
        path: '/source/script-editor',
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
      ).toString(),
    );
    if (!mounted || result == null || result.trim().isEmpty) {
      return;
    }
    _showMessage(result);
  }

  Future<void> _setScriptSourceEnabled(
    ScriptSource source,
    bool enabled,
  ) async {
    setState(() {
      _changingEnabledScriptSourceIds.add(source.id);
    });
    try {
      await _sourceRuntimeFacade.setScriptSourceEnabled(
        id: source.id,
        enabled: enabled,
      );
    } catch (error) {
      if (mounted) {
        _showMessage('更新脚本源状态失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _changingEnabledScriptSourceIds.remove(source.id);
        });
      }
    }
  }

  Future<void> _deleteScriptSource(ScriptSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除脚本源'),
          content: Text('确认删除「${source.name}」吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _deletingScriptSourceIds.add(source.id);
    });
    try {
      await _sourceRuntimeFacade.deleteScriptSource(source.id);
      if (mounted) {
        _showMessage('脚本源已删除。');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('删除脚本源失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingScriptSourceIds.remove(source.id);
        });
      }
    }
  }

  RoundedRectangleBorder _buildOutlinedCardShape(BuildContext context) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int input) => input.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}
