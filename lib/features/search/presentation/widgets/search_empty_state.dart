import 'package:flutter/material.dart';

class SearchEmptyState extends StatelessWidget {
  const SearchEmptyState({
    super.key,
    required this.history,
    required this.onHistoryTap,
    required this.onClearHistory,
    this.onRemoveHistoryItem,
  });

  final List<String> history;
  final ValueChanged<String> onHistoryTap;
  final VoidCallback onClearHistory;
  final ValueChanged<String>? onRemoveHistoryItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasHistory = history.isNotEmpty;

    return Column(
      children: [
        // ── History section (on top when available) ──
        if (hasHistory) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '搜索历史',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onClearHistory,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    '清除全部',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  history
                      .map(
                        (keyword) => _HistoryChip(
                          keyword: keyword,
                          onTap: () => onHistoryTap(keyword),
                          onRemove:
                              onRemoveHistoryItem != null
                                  ? () => onRemoveHistoryItem!(keyword)
                                  : null,
                        ),
                      )
                      .toList(growable: false),
            ),
          ),
        ],

        // ── Guide section (de-emphasized when history exists) ──
        Padding(
          padding: EdgeInsets.symmetric(vertical: hasHistory ? 16 : 24),
          child: Column(
            children: [
              Icon(
                Icons.manage_search_rounded,
                color: colorScheme.onSurfaceVariant.withValues(
                  alpha: hasHistory ? 0.3 : 0.5,
                ),
                size: hasHistory ? 28 : 40,
              ),
              const SizedBox(height: 6),
              Text(
                '输入关键词开始搜索',
                style: (hasHistory
                        ? theme.textTheme.bodySmall
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(
                    alpha: hasHistory ? 0.5 : 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({
    required this.keyword,
    required this.onTap,
    this.onRemove,
  });

  final String keyword;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        onLongPress: onRemove,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            6,
            onRemove != null ? 4 : 12,
            6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                keyword,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 2),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onRemove,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
