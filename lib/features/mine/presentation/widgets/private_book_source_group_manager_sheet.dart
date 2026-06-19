import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_adaptive.dart';
import '../../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../../app/widgets/app_empty_state_card.dart';
import '../../../../app/widgets/foundation/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../application/private_book_source_provider.dart';
import '../../application/private_book_source_service.dart';
import 'private_book_source_action_surfaces.dart';

class PrivateBookSourceGroupManagerSheet extends ConsumerStatefulWidget {
  const PrivateBookSourceGroupManagerSheet({super.key});

  @override
  ConsumerState<PrivateBookSourceGroupManagerSheet> createState() =>
      PrivateBookSourceGroupManagerSheetState();
}

class PrivateBookSourceGroupManagerSheetState
    extends ConsumerState<PrivateBookSourceGroupManagerSheet> {
  late final TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final groupsAsync = ref.watch(privateBookSourceGroupsProvider);
    final metrics = AppAdaptiveMetrics.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        metrics.contentGap,
        16,
        bottomInset + metrics.sectionGap,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _nameController,
                      enabled: !_saving,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.15),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: colorScheme.surfaceContainerLowest
                            .withValues(alpha: 0.94),
                        hintText: '新增分组，例如：常用、漫画、备用',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.48,
                            ),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.48,
                            ),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: colorScheme.primary.withValues(alpha: 0.78),
                            width: 1.4,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => unawaited(_createGroup()),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message: _saving ? '保存中' : '新增分组',
                  child: SizedBox.square(
                    dimension: 48,
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => unawaited(_createGroup()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        backgroundColor: Colors.transparent,
                        fixedSize: const Size.square(48),
                        minimumSize: const Size.square(48),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.62,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child:
                          _saving
                              ? SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              )
                              : const Icon(Icons.add_rounded, size: 26),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: groupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return const AppEmptyStateCard(
                      icon: Icons.folder_off_outlined,
                      title: '暂无私人分组',
                      description: '新增分组后，可以在书源编辑里选择或填写对应分组名。',
                      compact: true,
                    );
                  }
                  return ListView.separated(
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final isDefault = _isDefaultGroup(group);
                      return Material(
                        key: ValueKey<String>(
                          'private_book_source_group_${group.id}',
                        ),
                        color: Theme.of(context).colorScheme.surfaceContainerLow
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color:
                                        isDefault
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer
                                            : Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isDefault
                                        ? Icons.folder_special_outlined
                                        : Icons.folder_outlined,
                                    size: 20,
                                    color:
                                        isDefault
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer
                                            : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        group.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isDefault ? '默认书源分组' : '私人书源分组',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall?.copyWith(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: '重命名',
                                  onPressed:
                                      () => unawaited(_renameGroup(group)),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                ),
                                IconButton(
                                  tooltip: '删除',
                                  onPressed:
                                      isDefault
                                          ? null
                                          : () =>
                                              unawaited(_deleteGroup(group)),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading:
                    () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                error:
                    (error, _) => AppEmptyStateCard(
                      icon: Icons.error_outline_rounded,
                      title: '分组读取失败',
                      description: _privateBookSourceMessageOf(error),
                      actionLabel: '重试',
                      onAction:
                          () => ref.invalidate(privateBookSourceGroupsProvider),
                      compact: true,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('请填写分组名称');
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await ref
          .read(privateBookSourceActionControllerProvider)
          .createGroup(name);
      _nameController.clear();
      _showMessage('分组已新增');
    } catch (error) {
      _showMessage(_privateBookSourceMessageOf(error));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _renameGroup(PrivateBookSourceGroup group) async {
    final controller = TextEditingController(text: group.displayName);
    final name = await showAdaptiveActionSurface<String>(
      context: context,
      maxWidth: 440,
      builder: (context) => RenameGroupSurface(controller: controller),
    );
    controller.dispose();
    if (!mounted) {
      return;
    }
    if (name == null || name.isEmpty || name == group.displayName) {
      return;
    }
    try {
      await ref
          .read(privateBookSourceActionControllerProvider)
          .renameGroup(group, name);
      if (!mounted) {
        return;
      }
      _showMessage('分组已重命名');
    } catch (error) {
      _showMessage(_privateBookSourceMessageOf(error));
    }
  }

  Future<void> _deleteGroup(PrivateBookSourceGroup group) async {
    final confirmed = await showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 440,
      builder:
          (context) => ConfirmActionSurface(
            icon: Icons.folder_delete_outlined,
            title: '删除分组',
            message: '确认删除“${group.displayName}”？分组内书源会移到未分组。',
            confirmLabel: '删除',
            destructive: true,
          ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref
          .read(privateBookSourceActionControllerProvider)
          .deleteGroup(group);
      _showMessage('分组已删除');
    } catch (error) {
      _showMessage(_privateBookSourceMessageOf(error));
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    AppFeedback.showSnackBar(
      context,
      message: message,
      tone:
          message.contains('失败') ? AppFeedbackTone.error : AppFeedbackTone.info,
      useHaptics: false,
    );
  }
}

bool _isDefaultGroup(PrivateBookSourceGroup group) {
  return group.displayName == '未分组';
}

String _privateBookSourceMessageOf(Object error) {
  if (error is ApiException) {
    return error.briefMessage;
  }
  return error.toString();
}
