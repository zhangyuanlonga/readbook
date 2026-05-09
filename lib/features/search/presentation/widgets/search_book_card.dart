import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_adaptive.dart';
import '../../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../../app/widgets/adaptive_card.dart';
import '../../../../app/widgets/resolved_book_cover.dart';
import '../../../../domain/entities/book.dart';
import '../../../book/application/book_metadata_presentation_resolver.dart';
import '../../../book/application/book_display_state.dart';
import '../../../mine/application/advanced_theme_provider.dart';
import '../../../mine/application/cover_gallery_provider.dart';

class SearchBookCard extends ConsumerWidget {
  const SearchBookCard({
    super.key,
    required this.book,
    required this.presentation,
    required this.sourceName,
    this.sourceHitCount = 1,
    required this.heroTag,
    this.normalizedIntro,
    this.normalizedLatestChapter,
    required this.onTap,
  });

  final Book book;
  final BookDisplayState presentation;
  final String sourceName;
  final int sourceHitCount;
  final String heroTag;
  final String? normalizedIntro;
  final String? normalizedLatestChapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    ref.watch(activeAdvancedThemeProvider);
    final palette = resolveAdvancedThemePalette(
      colorScheme,
      ref.read(activeAdvancedThemeProvider).valueOrNull,
    );
    final showHitCount = sourceHitCount > 1;
    final metrics = AppAdaptiveMetrics.of(context);
    final coverWidth = metrics.isCompactDensity ? 50.0 : 56.0;
    final coverHeight = metrics.isCompactDensity ? 72.0 : 80.0;
    final introMaxLines = metrics.isCompactDensity ? 1 : 2;
    final displayTitle =
        presentation.displayTitle.isNotEmpty
            ? presentation.displayTitle
            : book.title;
    final displayAuthor =
        presentation.displayAuthor?.trim().isNotEmpty == true
            ? presentation.displayAuthor!.trim()
            : book.author?.trim();
    final displayIntro =
        presentation.displayIntro?.trim().isNotEmpty == true
            ? presentation.displayIntro!.trim()
            : normalizedIntro;
    final displayCover =
        presentation.displayCover?.trim().isNotEmpty == true
            ? presentation.displayCover!.trim()
            : book.coverUrl;
    return AdaptiveCard(
      margin: EdgeInsets.only(bottom: metrics.contentGap),
      padding: EdgeInsets.all(metrics.cardPadding),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CoverPreview(
            coverUrl: displayCover,
            title: displayTitle,
            author: displayAuthor,
            heroTag: heroTag,
            bookId: book.id,
            sourceId: book.sourceId,
            detailUrl: book.detailUrl,
            width: coverWidth,
            height: coverHeight,
            radius: metrics.cardRadius * 0.66,
          ),
          SizedBox(width: metrics.contentGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: metrics.isCompactDensity ? 3 : 4),
                Wrap(
                  spacing: metrics.isCompactDensity ? 5 : 6,
                  runSpacing: metrics.isCompactDensity ? 5 : 6,
                  children: [
                    _InfoPill(
                      label: '来源',
                      value: sourceName,
                      backgroundColor: palette.primaryContainerColor,
                      textColor: palette.textPrimaryColor,
                    ),
                    if (displayAuthor != null && displayAuthor.isNotEmpty)
                      _InfoPill(
                        label: '作者',
                        value: displayAuthor,
                        backgroundColor: palette.primaryContainerColor,
                        textColor: palette.textPrimaryColor,
                      ),
                  ],
                ),
                if (normalizedLatestChapter != null &&
                    normalizedLatestChapter!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(
                      top: metrics.isCompactDensity ? 5 : 6,
                    ),
                    child: Text(
                      '最新章节: $normalizedLatestChapter',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                if (displayIntro != null && displayIntro.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(
                      top: metrics.isCompactDensity ? 5 : 6,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: metrics.isCompactDensity ? 7 : 8,
                        vertical: metrics.isCompactDensity ? 5 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: palette.elevatedSurfaceColor,
                        borderRadius: BorderRadius.circular(
                          metrics.cardRadius * 0.66,
                        ),
                      ),
                      child: Text(
                        displayIntro,
                        maxLines: introMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textSecondaryColor,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: metrics.isCompactDensity ? 6 : 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (showHitCount)
                _SourceHitBadge(
                  count: sourceHitCount,
                  backgroundColor: palette.secondaryColor,
                  textColor: palette.buttonTextColor,
                )
              else
                SizedBox(height: metrics.isCompactDensity ? 18 : 20),
              Icon(
                Icons.chevron_right,
                size: metrics.isCompactDensity ? 20 : 24,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({
    required this.coverUrl,
    required this.title,
    required this.heroTag,
    this.author,
    this.bookId,
    this.sourceId,
    this.detailUrl,
    required this.width,
    required this.height,
    required this.radius,
  });

  final String? coverUrl;
  final String title;
  final String? author;
  final String heroTag;
  final String? bookId;
  final String? sourceId;
  final String? detailUrl;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        ref.watch(activeAdvancedThemeProvider);
        ref.watch(coverGalleriesProvider);
        final resolvedCover = resolveBookCover(
          realCoverUrl: coverUrl,
          activeTheme: ref.read(activeAdvancedThemeProvider).valueOrNull,
          galleries: ref.read(coverGalleriesProvider).valueOrNull ?? const [],
          brightness: Theme.of(context).brightness,
          bookId: bookId,
          sourceId: sourceId,
          detailUrl: detailUrl,
        );
        return Hero(
          tag: heroTag,
          child: ResolvedBookCoverView(
            cover: resolvedCover,
            title: title,
            author: author,
            width: width,
            height: height,
            borderRadius: BorderRadius.circular(radius),
          ),
        );
      },
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    required this.value,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final String value;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = AppAdaptiveMetrics.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.isCompactDensity ? 7 : 8,
        vertical: metrics.isCompactDensity ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(metrics.cardRadius * 0.66),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelSmall?.copyWith(color: textColor),
      ),
    );
  }
}

class _SourceHitBadge extends StatelessWidget {
  const _SourceHitBadge({
    required this.count,
    required this.backgroundColor,
    required this.textColor,
  });

  final int count;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = AppAdaptiveMetrics.of(context);
    return Container(
      constraints: BoxConstraints(minWidth: metrics.isCompactDensity ? 22 : 24),
      padding: EdgeInsets.symmetric(
        horizontal: metrics.isCompactDensity ? 6 : 7,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
