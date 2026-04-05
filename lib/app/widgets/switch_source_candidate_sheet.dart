import 'package:flutter/material.dart';

import '../../app/layout/app_spacing.dart';
import 'source_health_badge.dart';
import '../../features/reader/application/switch_source_shared.dart';

Future<SwitchSourceCandidate?> showSwitchSourceCandidateSheet({
  required BuildContext context,
  required ValueNotifier<SwitchSourceLookupState> lookupStateNotifier,
  required String currentTitle,
  required int currentChapterCount,
  required Future<void> Function(
    SwitchSourceCandidate candidate,
    SwitchSourceScoreAction action,
  )
  onScoreAction,
  ThemeData? themeData,
  double heightFactor = 0.88,
  double? horizontalPadding,
  double? bottomInset,
}) {
  final resolvedHorizontal =
      horizontalPadding ?? AppSpacing.pageHorizontal(context);
  final resolvedBottomInset =
      bottomInset ?? MediaQuery.viewPaddingOf(context).bottom;

  final sheet = FractionallySizedBox(
    heightFactor: heightFactor,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        resolvedHorizontal,
        4,
        resolvedHorizontal,
        12,
      ),
      child: ValueListenableBuilder<SwitchSourceLookupState>(
        valueListenable: lookupStateNotifier,
        builder: (context, lookupState, _) {
          final candidates = lookupState.candidates;
          final colorScheme = Theme.of(context).colorScheme;
          final progressText =
              lookupState.sourceCount <= 0
                  ? '正在准备书源列表...'
                  : '已扫描 ${lookupState.processedSourceCount}/${lookupState.sourceCount} 个书源';
          final emptyMessage = lookupState.errorText ?? '没有检索到可切换书源，请稍后重试。';

          return Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '切换书源（${candidates.length}）',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '当前书名：${currentTitle.isEmpty ? '未知' : currentTitle}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '当前目录：$currentChapterCount 章',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  progressText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  lookupState.scoreRankingEnabled
                      ? '评分排序：已启用（匹配分 + 源评分 + 本书评分）'
                      : '评分排序：已关闭（仅按匹配分排序）',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child:
                    candidates.isEmpty
                        ? lookupState.isLoading
                            ? _buildSwitchSourceLoadingPlaceholderList(
                              colorScheme,
                            )
                            : Center(
                              child: Text(
                                emptyMessage,
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                        : ListView.separated(
                          itemCount: candidates.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final candidate = candidates[index];
                            final author = candidate.book.author?.trim();
                            final subtitle =
                                (author == null || author.isEmpty)
                                    ? candidate.sourceName
                                    : '${candidate.sourceName} · $author';
                            final healthLevel = candidate.healthLevel;

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                candidate.book.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (healthLevel != null) ...[
                                    const SizedBox(height: 4),
                                    SourceHealthBadge(
                                      level: healthLevel,
                                      compact: true,
                                    ),
                                  ],
                                  const SizedBox(height: 2),
                                  Text(
                                    '最新：${candidate.latestChapterLabel}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color:
                                          candidate.isPotentiallyOutdated
                                              ? colorScheme.error
                                              : colorScheme.onSurfaceVariant,
                                      fontWeight:
                                          candidate.isPotentiallyOutdated
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    lookupState.scoreRankingEnabled
                                        ? '匹配:${candidate.baseScore} · 命中:${candidate.hitCount} · 源评:${_formatSignedScore(candidate.sourceScore)} · 书评:${_formatSignedScore(candidate.bookScore)}'
                                        : '匹配:${candidate.baseScore} · 命中:${candidate.hitCount}（评分排序关闭）',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (candidate.isPotentiallyOutdated) ...[
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: colorScheme.error,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 2),
                                  ],
                                  PopupMenuButton<SwitchSourceScoreAction>(
                                    tooltip: '评分',
                                    icon: const Icon(
                                      Icons.thumb_up_alt_outlined,
                                      size: 18,
                                    ),
                                    onSelected:
                                        (action) =>
                                            onScoreAction(candidate, action),
                                    itemBuilder:
                                        (context) => const [
                                          PopupMenuItem(
                                            value:
                                                SwitchSourceScoreAction.upvote,
                                            child: Text('推荐 +1'),
                                          ),
                                          PopupMenuItem(
                                            value:
                                                SwitchSourceScoreAction
                                                    .downvote,
                                            child: Text('降权 -1'),
                                          ),
                                          PopupMenuItem(
                                            value:
                                                SwitchSourceScoreAction.reset,
                                            child: Text('重置本书评分'),
                                          ),
                                        ],
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: () => Navigator.of(context).pop(candidate),
                            );
                          },
                        ),
              ),
              if (lookupState.isLoading && candidates.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '正在继续检索其他书源...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: resolvedBottomInset),
            ],
          );
        },
      ),
    ),
  );

  if (themeData != null) {
    return showModalBottomSheet<SwitchSourceCandidate>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: themeData.colorScheme.surface,
      builder: (context) => Theme(data: themeData, child: sheet),
    );
  }

  return showModalBottomSheet<SwitchSourceCandidate>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => sheet,
  );
}

Widget _buildSwitchSourceLoadingPlaceholderList(ColorScheme colorScheme) {
  final placeholderColor = colorScheme.surfaceContainerHigh;
  return ListView.separated(
    itemCount: 6,
    separatorBuilder: (_, __) => const Divider(height: 1),
    itemBuilder: (context, index) {
      final titleWidth = 110.0 + (index % 3) * 42.0;
      final subtitleWidth = 150.0 + (index % 2) * 56.0;

      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: titleWidth,
            height: 14,
            decoration: BoxDecoration(
              color: placeholderColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: subtitleWidth,
              height: 12,
              decoration: BoxDecoration(
                color: placeholderColor.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        trailing: Icon(
          Icons.hourglass_top_rounded,
          color: colorScheme.onSurfaceVariant,
          size: 18,
        ),
      );
    },
  );
}

String _formatSignedScore(int score) {
  if (score > 0) {
    return '+$score';
  }
  return '$score';
}
