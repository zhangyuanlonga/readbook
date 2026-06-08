import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_spacing.dart';
import '../../../core/network/api_client.dart';
import '../application/private_book_source_provider.dart';
import '../application/private_book_source_service.dart';

class PrivateBookSourcesPage extends ConsumerWidget {
  const PrivateBookSourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGroupName = ref.watch(selectedPrivateBookSourceGroupProvider);
    final listAsync = ref.watch(privateBookSourcesProvider(selectedGroupName));
    final groupsAsync = ref.watch(privateBookSourceGroupsProvider);
    final quotaAsync = ref.watch(sourceQuotaProvider);
    final horizontal = AppSpacing.pageHorizontal(context);
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          context.go('/mine');
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('我的书源'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          actions: <Widget>[
            IconButton(
              tooltip: '刷新',
              onPressed: () => _refresh(ref),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => unawaited(_openForm(context, ref)),
          icon: const Icon(Icons.add),
          label: const Text('新增'),
        ),
        body: RefreshIndicator(
          onRefresh: () async => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontal,
              topInset + 12,
              horizontal,
              bottomInset + 96,
            ),
            children: <Widget>[
              quotaAsync.when(
                data: (quota) => _QuotaCard(quota: quota),
                loading: () => const _LoadingCard(message: '正在读取额度'),
                error:
                    (error, _) => _ErrorCard(
                      title: '额度读取失败',
                      message: _messageOf(error),
                      onRetry: () => ref.invalidate(sourceQuotaProvider),
                    ),
              ),
              const SizedBox(height: 14),
              _GroupFilterSection(
                selectedGroupName: selectedGroupName,
                groupsAsync: groupsAsync,
                onSelected: (groupName) {
                  ref
                      .read(selectedPrivateBookSourceGroupProvider.notifier)
                      .state = groupName;
                },
                onRetry: () => ref.invalidate(privateBookSourceGroupsProvider),
              ),
              const SizedBox(height: 14),
              listAsync.when(
                data: (result) {
                  if (result.items.isEmpty) {
                    return _EmptySourcesCard(
                      onCreate: () => unawaited(_openForm(context, ref)),
                    );
                  }
                  return Column(
                    children: <Widget>[
                      for (final item in result.items) ...<Widget>[
                        _PrivateSourceTile(
                          item: item,
                          onEdit:
                              () => unawaited(
                                _openForm(context, ref, item: item),
                              ),
                          onDelete:
                              () =>
                                  unawaited(_deleteSource(context, ref, item)),
                          onToggle:
                              (enabled) => unawaited(
                                _runAction(
                                  context,
                                  ref,
                                  () => ref
                                      .read(privateBookSourceServiceProvider)
                                      .setEnabled(item.id, enabled),
                                  enabled ? '已启用书源' : '已停用书源',
                                ),
                              ),
                          onTest:
                              () => unawaited(
                                _runAction(
                                  context,
                                  ref,
                                  () => ref
                                      .read(privateBookSourceServiceProvider)
                                      .test(item.id),
                                  '书源测试已记录',
                                ),
                              ),
                          onSubmit:
                              () =>
                                  unawaited(_submitSource(context, ref, item)),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
                loading: () => const _LoadingCard(message: '正在加载书源'),
                error:
                    (error, _) => _ErrorCard(
                      title: '书源加载失败',
                      message: _messageOf(error),
                      onRetry: () => ref.invalidate(privateBookSourcesProvider),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _refresh(WidgetRef ref) {
    ref.invalidate(privateBookSourcesProvider);
    ref.invalidate(privateBookSourceGroupsProvider);
    ref.invalidate(sourceQuotaProvider);
  }

  static Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    PrivateBookSourceItem? item,
  }) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _PrivateSourceForm(item: item),
    );
    if (changed == true) {
      _refresh(ref);
    }
  }

  static Future<void> _deleteSource(
    BuildContext context,
    WidgetRef ref,
    PrivateBookSourceItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('删除书源'),
            content: Text('确认删除“${item.name}”？删除后不可恢复。'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _runVoidAction(
      context,
      ref,
      () => ref.read(privateBookSourceServiceProvider).delete(item.id),
      '书源已删除',
    );
  }

  static Future<void> _submitSource(
    BuildContext context,
    WidgetRef ref,
    PrivateBookSourceItem item,
  ) async {
    final noteController = TextEditingController(text: item.description);
    final note = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('提交共享审核'),
            content: TextField(
              controller: noteController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '提交说明',
                hintText: '说明这个书源适合共享的原因',
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.of(context).pop(noteController.text.trim()),
                child: const Text('提交'),
              ),
            ],
          ),
    );
    noteController.dispose();
    if (note == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _runAction(
      context,
      ref,
      () => ref.read(privateBookSourceServiceProvider).submit(item.id, note),
      '已提交共享审核',
    );
  }

  static Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    Future<PrivateBookSourceItem> Function() action,
    String success,
  ) async {
    try {
      await action();
      if (!context.mounted) {
        return;
      }
      _refresh(ref);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageOf(error))));
    }
  }

  static Future<void> _runVoidAction(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String success,
  ) async {
    try {
      await action();
      if (!context.mounted) {
        return;
      }
      _refresh(ref);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageOf(error))));
    }
  }
}

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.quota});

  final SourceQuotaSnapshot quota;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.speed_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('书源额度', style: theme.textTheme.titleMedium),
                ),
                if (quota.policyName.isNotEmpty)
                  Text(quota.policyName, style: theme.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _QuotaChip(
                  label: '私人源',
                  value:
                      '${quota.privateSourceCount}/${_limitText(quota.maxPrivateSources)}',
                ),
                _QuotaChip(
                  label: '今日导入',
                  value: _remainingText(quota.dailyImportRemaining),
                ),
                _QuotaChip(
                  label: '今日测试',
                  value: _remainingText(quota.dailyTestRemaining),
                ),
                _QuotaChip(
                  label: '今日提交',
                  value:
                      quota.allowSubmitShared
                          ? _remainingText(quota.dailySubmitRemaining)
                          : '不可提交',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuotaChip extends StatelessWidget {
  const _QuotaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label $value', style: theme.textTheme.labelLarge),
    );
  }
}

class _GroupFilterSection extends StatelessWidget {
  const _GroupFilterSection({
    required this.selectedGroupName,
    required this.groupsAsync,
    required this.onSelected,
    required this.onRetry,
  });

  final String? selectedGroupName;
  final AsyncValue<List<PrivateBookSourceGroupSummary>> groupsAsync;
  final ValueChanged<String?> onSelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return groupsAsync.when(
      data: (groups) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              ChoiceChip(
                label: const Text('全部'),
                selected: selectedGroupName == null,
                onSelected: (_) => onSelected(null),
              ),
              const SizedBox(width: 8),
              for (final group in groups) ...<Widget>[
                ChoiceChip(
                  label: Text('${group.displayName} ${group.sourceCount}'),
                  selected: selectedGroupName == group.name,
                  onSelected: (_) => onSelected(group.name),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
      loading:
          () => const SizedBox(
            height: 32,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      error:
          (error, _) => Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('分组读取失败'),
            ),
          ),
    );
  }
}

class _PrivateSourceTile extends StatelessWidget {
  const _PrivateSourceTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onTest,
    required this.onSubmit,
  });

  final PrivateBookSourceItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTest;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(item.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        [
                          _typeLabel(item.supportedTypes),
                          _groupLabel(item.groupName),
                          _visibilityLabel(item.visibility),
                          _reviewLabel(item.reviewStatus),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(value: item.enabled, onChanged: onToggle),
              ],
            ),
            if (item.lastTestStatus.isNotEmpty ||
                item.lastTestMessage.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '测试：${_testLabel(item.lastTestStatus)}${item.lastTestMessage.isEmpty ? '' : ' · ${item.lastTestMessage}'}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (item.description.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(item.description, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: onTest,
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('测试'),
                ),
                OutlinedButton.icon(
                  onPressed: item.visibility == 'private' ? onSubmit : null,
                  icon: const Icon(Icons.ios_share_outlined),
                  label: const Text('提交共享'),
                ),
                IconButton(
                  tooltip: '编辑',
                  onPressed: item.visibility == 'shared' ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivateSourceForm extends ConsumerStatefulWidget {
  const _PrivateSourceForm({this.item});

  final PrivateBookSourceItem? item;

  @override
  ConsumerState<_PrivateSourceForm> createState() => _PrivateSourceFormState();
}

class _PrivateSourceFormState extends ConsumerState<_PrivateSourceForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _groupController;
  late final TextEditingController _sourceController;
  String _type = 'novel';
  bool _saving = false;
  bool _groupEdited = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _groupController = TextEditingController(text: item?.groupName ?? '');
    _sourceController = TextEditingController(
      text:
          item?.sourceJson.isNotEmpty == true
              ? item!.sourceJson
              : item?.sourceCode ?? '',
    );
    _sourceController.addListener(_fillGroupFromSourceJson);
    _type =
        item?.supportedTypes.isNotEmpty == true
            ? item!.supportedTypes.first
            : 'novel';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _groupController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset + 16),
      child: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _isEditing ? '编辑书源' : '新增书源',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? '请填写名称'
                              : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: '类型'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'novel', child: Text('小说')),
                    DropdownMenuItem(value: 'comic', child: Text('漫画')),
                    DropdownMenuItem(value: 'audio', child: Text('音频')),
                    DropdownMenuItem(value: 'video', child: Text('视频')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _type = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _groupController,
                  decoration: const InputDecoration(labelText: '分组'),
                  onChanged: (_) {
                    _groupEdited = true;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '描述'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sourceController,
                  minLines: 8,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    labelText: 'Legado JSON',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    final raw = value?.trim() ?? '';
                    if (raw.isEmpty) {
                      return '请粘贴书源 JSON';
                    }
                    if (!PrivateBookSourceInput.isValidJson(raw)) {
                      return 'JSON 格式不正确';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed:
                          _saving
                              ? null
                              : () => Navigator.of(context).pop(false),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? '保存中' : '保存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
    });
    final input = PrivateBookSourceInput(
      name: _nameController.text.trim(),
      supportedTypes: <String>[_type],
      sourceCode: _sourceController.text.trim(),
      description: _descriptionController.text.trim(),
      groupName: _groupController.text.trim(),
    );
    try {
      if (_isEditing) {
        await ref
            .read(privateBookSourceServiceProvider)
            .update(widget.item!.id, input);
      } else {
        await ref.read(privateBookSourceServiceProvider).create(input);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageOf(error))));
    }
  }

  void _fillGroupFromSourceJson() {
    if (_isEditing || _groupEdited || _groupController.text.trim().isNotEmpty) {
      return;
    }
    final groupName = PrivateBookSourceInput.defaultGroupNameFromJson(
      _sourceController.text.trim(),
    );
    if (groupName.isEmpty) {
      return;
    }
    _groupController.text = groupName;
  }
}

class _EmptySourcesCard extends StatelessWidget {
  const _EmptySourcesCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            const Icon(Icons.library_books_outlined, size: 42),
            const SizedBox(height: 10),
            Text('还没有私人书源', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('新增书源'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

String _limitText(int value) => value < 0 ? '不限' : '$value';

String _remainingText(int value) => value < 0 ? '不限' : '剩 $value';

String _typeLabel(List<String> types) {
  if (types.isEmpty) {
    return '小说';
  }
  return types
      .map((type) {
        return switch (type) {
          'novel' => '小说',
          'comic' => '漫画',
          'audio' => '音频',
          'video' => '视频',
          _ => type,
        };
      })
      .join('、');
}

String _groupLabel(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? '未分组' : normalized;
}

String _visibilityLabel(String value) {
  return switch (value) {
    'private' => '私人',
    'submitted' => '审核中',
    'shared' => '共享',
    _ => value.isEmpty ? '私人' : value,
  };
}

String _reviewLabel(String value) {
  return switch (value) {
    'pending' => '待审核',
    'approved' => '已通过',
    'rejected' => '已拒绝',
    _ => value.isEmpty ? '待审核' : value,
  };
}

String _testLabel(String value) {
  return switch (value) {
    'passed' => '通过',
    'failed' => '失败',
    'pending' => '待测试',
    _ => value.isEmpty ? '未测试' : value,
  };
}

String _messageOf(Object error) {
  if (error is ApiException) {
    return error.briefMessage;
  }
  return error.toString();
}
