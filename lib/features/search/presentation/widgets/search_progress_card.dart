import 'package:flutter/material.dart';

import '../../application/search_service.dart';

class SearchProgressCard extends StatelessWidget {
  const SearchProgressCard({
    super.key,
    required this.report,
    required this.isSearching,
  });

  final SearchExecutionReport? report;
  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    // Only show during active search
    if (!isSearching) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sourceCount = report?.sourceCount ?? 1;
    final processedCount = report?.processedSourceCount ?? 0;
    final progressValue =
        sourceCount == 0 ? 0.0 : (processedCount / sourceCount).clamp(0.0, 1.0);
    final progressPercent = (progressValue * 100).round();
    final bookCount = report?.books.length ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report == null
                          ? '正在搜索书享源...'
                          : '$processedCount/$sourceCount 源 · $bookCount 本',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$progressPercent%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 4,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
