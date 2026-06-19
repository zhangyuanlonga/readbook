import 'package:flutter/material.dart';

import '../../application/private_book_source_service.dart';
import '../private_book_source_presentation.dart';
import 'private_book_source_more_menu_button.dart';

class PrivateBookSourceTile extends StatelessWidget {
  const PrivateBookSourceTile({
    super.key,
    required this.item,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
    required this.onTest,
    required this.onSubmit,
  });

  final PrivateBookSourceItem item;
  final VoidCallback onDetail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTest;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final badges = PrivateBookSourcePresentation.badgesFor(item);

    return Material(
      color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onDetail,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  PrivateBookSourceMoreMenuButton(
                    item: item,
                    onDetail: onDetail,
                    onTest: onTest,
                    onSubmit: onSubmit,
                    onEdit: onEdit,
                    onDelete: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final badge in badges)
                    _PrivateSourceBadgeChip(
                      label: badge.label,
                      backgroundColor:
                          PrivateBookSourcePresentation.toneForeground(
                            badge.tone,
                            colorScheme,
                          ).withValues(alpha: 0.12),
                      foregroundColor:
                          PrivateBookSourcePresentation.toneForeground(
                            badge.tone,
                            colorScheme,
                          ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivateSourceBadgeChip extends StatelessWidget {
  const _PrivateSourceBadgeChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
