import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../../app/widgets/resolved_book_cover.dart';
import '../../../../domain/entities/book.dart';
import '../../../book/application/book_metadata_presentation_resolver.dart';
import '../../../mine/application/advanced_theme_provider.dart';
import '../../../mine/application/cover_gallery_provider.dart';
import '../../providers.dart';

class SearchBookCard extends ConsumerWidget {
  const SearchBookCard({
    super.key,
    required this.book,
    required this.sourceName,
    this.sourceHitCount = 1,
    required this.heroTag,
    this.normalizedIntro,
    this.normalizedLatestChapter,
    required this.onTap,
  });

  final Book book;
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

    return FutureBuilder<BookMetadataPresentation>(
      future: _resolvePresentation(ref, book),
      builder: (context, snapshot) {
        final presentation =
            snapshot.data ?? const BookMetadataPresentation(displayTitle: '');
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
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
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
                  ),
                  const SizedBox(width: 12),
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
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _InfoPill(
                              label: '来源',
                              value: sourceName,
                              backgroundColor: palette.primaryContainerColor,
                              textColor: palette.textPrimaryColor,
                            ),
                            if (displayAuthor != null &&
                                displayAuthor.isNotEmpty)
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
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '最新章节: $normalizedLatestChapter',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        if (displayIntro != null && displayIntro.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: palette.elevatedSurfaceColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                displayIntro,
                                maxLines: 2,
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
                  const SizedBox(width: 8),
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
                        const SizedBox(height: 20),
                      Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<BookMetadataPresentation> _resolvePresentation(
    WidgetRef ref,
    Book book,
  ) async {
    return ref
        .read(searchBookPresentationQueryServiceProvider)
        .resolveRemoteBook(book);
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
  });

  final String? coverUrl;
  final String title;
  final String? author;
  final String heroTag;
  final String? bookId;
  final String? sourceId;
  final String? detailUrl;

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
            width: 56,
            height: 80,
            borderRadius: BorderRadius.circular(8),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
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
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
