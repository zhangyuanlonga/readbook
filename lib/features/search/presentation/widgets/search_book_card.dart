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
    final coverWidth = metrics.isCompactDensity ? 64.0 : 72.0;
    final coverHeight = metrics.isCompactDensity ? 92.0 : 104.0;
    final introMaxLines = 1;
    final displayTitle =
        presentation.displayTitle.isNotEmpty
            ? presentation.displayTitle
            : book.title;
    final displayAuthor = _cleanDisplayMetaValue(
      presentation.displayAuthor?.trim().isNotEmpty == true
          ? presentation.displayAuthor!.trim()
          : book.author?.trim(),
      label: '作者',
    );
    final displayIntro =
        presentation.displayIntro?.trim().isNotEmpty == true
            ? presentation.displayIntro!.trim()
            : normalizedIntro;
    final displayCover =
        presentation.displayCover?.trim().isNotEmpty == true
            ? presentation.displayCover!.trim()
            : book.coverUrl;
    final metaItems = _buildSearchMetaItems(book);
    final visibleMetaItems =
        metrics.isCompactDensity ? metaItems.take(3).toList() : metaItems;
    final trailingWidth = metrics.isCompactDensity ? 32.0 : 36.0;
    return AdaptiveCard(
      margin: EdgeInsets.only(bottom: metrics.contentGap),
      padding: EdgeInsets.all(metrics.cardPadding),
      onTap: onTap,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(right: trailingWidth),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      if (displayAuthor != null && displayAuthor.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(
                            top: metrics.isCompactDensity ? 3 : 4,
                          ),
                          child: Text(
                            '作者: $displayAuthor',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textSecondaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (visibleMetaItems.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(
                            top: metrics.isCompactDensity ? 5 : 6,
                          ),
                          child: Row(
                            children: [
                              for (var i = 0; i < visibleMetaItems.length; i++)
                                Flexible(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right:
                                          i == visibleMetaItems.length - 1
                                              ? 0
                                              : metrics.isCompactDensity
                                              ? 5
                                              : 6,
                                    ),
                                    child: _MetaPill(
                                      value: visibleMetaItems[i],
                                      backgroundColor:
                                          palette.primaryContainerColor,
                                      textColor: palette.textPrimaryColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (normalizedLatestChapter != null &&
                          normalizedLatestChapter!.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(
                            top: metrics.isCompactDensity ? 5 : 6,
                          ),
                          child: Text(
                            '最新: $normalizedLatestChapter',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      if (displayIntro != null && displayIntro.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(
                            top: metrics.isCompactDensity ? 4 : 5,
                          ),
                          child: Text(
                            displayIntro,
                            maxLines: introMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textSecondaryColor,
                              height: 1.25,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.center,
              child: Icon(
                Icons.chevron_right,
                size: metrics.isCompactDensity ? 20 : 24,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (showHitCount)
            Positioned(
              right: 0,
              top: 0,
              child: _SourceHitBadge(
                count: sourceHitCount,
                backgroundColor: palette.secondaryColor,
                textColor: _readableForegroundFor(palette.secondaryColor),
              ),
            ),
        ],
      ),
    );
  }

  String? _cleanDisplayMetaValue(String? value, {required String label}) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    var normalized = trimmed;
    final pattern = RegExp('^$label[：:]\\s*');
    while (pattern.hasMatch(normalized)) {
      normalized = normalized.replaceFirst(pattern, '').trim();
    }
    return normalized.isEmpty ? null : normalized;
  }

  List<String> _buildSearchMetaItems(Book book) {
    final items = <String>[];
    final wordCount = _cleanDisplayMetaValue(book.wordCount, label: '字数');
    if (wordCount != null && wordCount.isNotEmpty) {
      items.add(wordCount);
    }
    final seenTags = <String>{};
    final category = _cleanDisplayMetaValue(book.category, label: '分类');
    if (category != null && category.isNotEmpty) {
      seenTags.add(category);
      items.add(category);
    }
    for (final tag in book.tags) {
      final normalized = _cleanDisplayMetaValue(tag, label: '标签');
      if (normalized == null ||
          normalized.isEmpty ||
          seenTags.contains(normalized)) {
        continue;
      }
      seenTags.add(normalized);
      items.add(normalized);
      if (items.length >= 5) {
        break;
      }
    }
    return items;
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.value,
    required this.backgroundColor,
    required this.textColor,
  });

  final String value;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = AppAdaptiveMetrics.of(context);

    return Container(
      constraints: BoxConstraints(
        maxWidth: metrics.isCompactDensity ? 92 : 120,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: metrics.isCompactDensity ? 7 : 8,
        vertical: metrics.isCompactDensity ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(metrics.cardRadius * 0.66),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
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

Color _readableForegroundFor(Color backgroundColor) {
  return ThemeData.estimateBrightnessForColor(backgroundColor) ==
          Brightness.dark
      ? Colors.white
      : Colors.black;
}
