import 'package:flutter/material.dart';

import '../../application/search_service.dart';

class SearchReportSummary extends StatelessWidget {
  const SearchReportSummary({
    super.key,
    required this.report,
    required this.visibleBookCount,
    required this.isPreciseBookMatch,
  });

  final SearchExecutionReport report;
  final int visibleBookCount;
  final bool isPreciseBookMatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final resultText =
        isPreciseBookMatch && visibleBookCount != report.books.length
            ? '$visibleBookCount/${report.books.length}'
            : '$visibleBookCount';
    final processedSourceCount = report.processedSourceCount;
    final sourceProgressText =
        processedSourceCount > 0 && processedSourceCount < report.sourceCount
            ? '${report.successSourceCount}/$processedSourceCount 已处理源成功'
            : '${report.successSourceCount}/${report.sourceCount} 源成功';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.menu_book_rounded, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            '$resultText 本结果',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '·',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            sourceProgressText,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (report.failedSourceCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${report.failedSourceCount} 失败',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
