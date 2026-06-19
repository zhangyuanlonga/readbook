import 'package:flutter/material.dart';

import '../../../../app/layout/app_adaptive.dart';
import '../../application/private_book_source_service.dart';
import '../private_book_source_presentation.dart';

enum PrivateBookSourceDetailAction { edit, test }

class PrivateBookSourceDetailSheet extends StatelessWidget {
  const PrivateBookSourceDetailSheet({super.key, required this.item});

  final PrivateBookSourceItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final normalizationStatus = item.normalizationStatus.trim();
    final normalizationMessage = item.normalizationError.trim();
    final testStatus = item.lastTestStatus.trim();
    final testMessage = item.lastTestMessage.trim();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.pagePadding,
        metrics.contentGap,
        metrics.pagePadding,
        bottomInset + metrics.sectionGap,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.menu_book_outlined,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _PrivateSourceDetailChip(
                    label: PrivateBookSourcePresentation.typeLabel(
                      item.supportedTypes,
                    ),
                    color: colorScheme.primary,
                  ),
                  _PrivateSourceDetailChip(
                    label: PrivateBookSourcePresentation.groupLabel(
                      item.groupName,
                    ),
                    color: colorScheme.secondary,
                  ),
                  _PrivateSourceDetailChip(
                    label: PrivateBookSourcePresentation.reviewLabel(
                      item.reviewStatus,
                      item.visibility,
                    ),
                    color:
                        item.visibility == 'private'
                            ? colorScheme.primary
                            : colorScheme.tertiary,
                  ),
                  _PrivateSourceDetailChip(
                    label: item.enabled ? '已启用' : '已停用',
                    color: item.enabled ? Colors.green : Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _PrivateSourceDetailSection(
                title: '基础信息',
                children: <Widget>[
                  _PrivateSourceDetailRow(
                    label: '类型',
                    value: PrivateBookSourcePresentation.typeLabel(
                      item.supportedTypes,
                    ),
                  ),
                  _PrivateSourceDetailRow(
                    label: '分组',
                    value: PrivateBookSourcePresentation.groupLabel(
                      item.groupName,
                    ),
                  ),
                  _PrivateSourceDetailRow(
                    label: '状态',
                    value:
                        '${item.enabled ? '已启用' : '已停用'} / ${PrivateBookSourcePresentation.reviewLabel(item.reviewStatus, item.visibility)}',
                  ),
                  _PrivateSourceDetailRow(
                    label: '创建时间',
                    value: PrivateBookSourcePresentation.formatDate(
                      item.createdAt,
                    ),
                  ),
                  _PrivateSourceDetailRow(
                    label: '更新时间',
                    value: PrivateBookSourcePresentation.formatDate(
                      item.updatedAt,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PrivateSourceDetailSection(
                title: '检测与配置',
                children: <Widget>[
                  _PrivateSourceDetailRow(
                    label: '检测状态',
                    value:
                        testMessage.isEmpty
                            ? PrivateBookSourcePresentation.testLabel(
                              testStatus,
                            )
                            : '${PrivateBookSourcePresentation.testLabel(testStatus)}：$testMessage',
                  ),
                  _PrivateSourceDetailRow(
                    label: '配置状态',
                    value:
                        normalizationMessage.isEmpty
                            ? PrivateBookSourcePresentation.normalizationLabel(
                              normalizationStatus,
                            )
                            : '${PrivateBookSourcePresentation.normalizationLabel(normalizationStatus)}：$normalizationMessage',
                  ),
                  if (item.reviewNote.trim().isNotEmpty)
                    _PrivateSourceDetailRow(
                      label: '审核备注',
                      value: item.reviewNote.trim(),
                    ),
                ],
              ),
              if (item.description.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                _PrivateSourceDetailSection(
                  title: '描述',
                  children: <Widget>[
                    SelectableText(
                      item.description.trim(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed:
                        () => Navigator.of(
                          context,
                        ).pop(PrivateBookSourceDetailAction.test),
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('检测'),
                  ),
                  if (item.visibility != 'shared') ...<Widget>[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed:
                          () => Navigator.of(
                            context,
                          ).pop(PrivateBookSourceDetailAction.edit),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('编辑'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivateSourceDetailSection extends StatelessWidget {
  const _PrivateSourceDetailSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _PrivateSourceDetailRow extends StatelessWidget {
  const _PrivateSourceDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              value.trim().isEmpty ? '-' : value.trim(),
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivateSourceDetailChip extends StatelessWidget {
  const _PrivateSourceDetailChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
