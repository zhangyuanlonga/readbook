import 'package:flutter/material.dart';

import '../../app/layout/app_spacing.dart';
import '../../domain/entities/source_health.dart';
import '../../features/reader/application/switch_source_shared.dart';
import 'adaptive_bottom_sheet.dart';
import 'source_health_badge.dart';

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

  final sheet = SizedBox(
    height: MediaQuery.sizeOf(context).height * heightFactor,
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
                            final healthLevel = candidate.healthLevel;
                            final recommendation = _buildRecommendationText(
                              candidate,
                              currentChapterCount: currentChapterCount,
                            );
                            final metadata =
                                (author == null || author.isEmpty)
                                    ? candidate.book.title
                                    : '${candidate.book.title} · $author';
                            final riskPresentation = _resolveRiskPresentation(
                              healthLevel,
                            );

                            return InkWell(
                              onTap: () => Navigator.of(context).pop(candidate),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  candidate.sourceName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                              if (index == 0) ...[
                                                const SizedBox(width: 8),
                                                _SwitchSourceTag(
                                                  label: '推荐',
                                                  background:
                                                      colorScheme.primary,
                                                  foreground:
                                                      colorScheme.onPrimary,
                                                ),
                                              ],
                                              if (riskPresentation != null) ...[
                                                const SizedBox(width: 6),
                                                _SwitchSourceTag(
                                                  label: riskPresentation.$1,
                                                  background:
                                                      riskPresentation.$2,
                                                  foreground:
                                                      riskPresentation.$3,
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            recommendation,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.copyWith(
                                              color:
                                                  candidate
                                                          .isPotentiallyOutdated
                                                      ? colorScheme.error
                                                      : colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            metadata,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '最新：${candidate.latestChapterLabel}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            lookupState.scoreRankingEnabled
                                                ? '匹配 ${candidate.baseScore} · 命中 ${candidate.hitCount} · 源评 ${_formatSignedScore(candidate.sourceScore)} · 书评 ${_formatSignedScore(candidate.bookScore)}'
                                                : '匹配 ${candidate.baseScore} · 命中 ${candidate.hitCount}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          if (healthLevel != null) ...[
                                            const SizedBox(height: 6),
                                            SourceHealthBadge(
                                              level: healthLevel,
                                              compact: true,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
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
                                                  SwitchSourceScoreAction
                                                      .upvote,
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
                                    const SizedBox(width: 2),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
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
    return showAdaptiveActionSurface<SwitchSourceCandidate>(
      context: context,
      maxWidth: 720,
      maxHeightFactor: heightFactor,
      padding: EdgeInsets.zero,
      builder: (context) => Theme(data: themeData, child: sheet),
    );
  }

  return showAdaptiveActionSurface<SwitchSourceCandidate>(
    context: context,
    maxWidth: 720,
    maxHeightFactor: heightFactor,
    padding: EdgeInsets.zero,
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

String _buildRecommendationText(
  SwitchSourceCandidate candidate, {
  required int currentChapterCount,
}) {
  final latest = candidate.latestChapterNumber;
  if (latest != null && currentChapterCount > 0) {
    if (candidate.isPotentiallyOutdated) {
      return '章节可能落后，当前约 $currentChapterCount 章';
    }
    if (latest > currentChapterCount) {
      return '章节更全，当前约 $latest / $currentChapterCount 章';
    }
    return '可接近当前阅读位置，当前约 $latest / $currentChapterCount 章';
  }

  if (candidate.hitCount > 0) {
    return '搜索命中较稳定';
  }

  if (candidate.baseScore >= 140) {
    return '标题与当前书籍高度匹配';
  }

  return '可作为备选来源';
}

(String, Color, Color)? _resolveRiskPresentation(SourceHealthLevel? level) {
  return switch (level) {
    SourceHealthLevel.healthy => (
      '稳定',
      const Color(0xFFE7F6EC),
      const Color(0xFF1F7A3D),
    ),
    SourceHealthLevel.warning => (
      '需验证',
      const Color(0xFFFFF4D9),
      const Color(0xFF9A6700),
    ),
    SourceHealthLevel.risky || SourceHealthLevel.unavailable => (
      '高风险',
      const Color(0xFFFDE7EA),
      const Color(0xFFB42318),
    ),
    _ => null,
  };
}

class _SwitchSourceTag extends StatelessWidget {
  const _SwitchSourceTag({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
