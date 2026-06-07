import 'bookshelf_page_models.dart';

class BookshelfListCoverLayout {
  const BookshelfListCoverLayout({
    required this.fallbackCoverHeight,
    required this.minCardHeight,
  });

  final double fallbackCoverHeight;
  final double minCardHeight;

  double coverHeight({
    required bool hasFiniteConstraint,
    required double constrainedHeight,
    required double cardPaddingVertical,
  }) {
    if (!hasFiniteConstraint) {
      return fallbackCoverHeight;
    }
    return (constrainedHeight - cardPaddingVertical)
        .clamp(fallbackCoverHeight, maxCoverHeight)
        .toDouble();
  }

  double get maxCoverHeight => fallbackCoverHeight >= 96 ? 144.0 : 118.0;
}

class BookshelfCoverLayoutResolver {
  const BookshelfCoverLayoutResolver();

  static const double coverAspectRatio = 68 / 96;

  double gridCardItemHeightExtra({
    required BookshelfGridVisualStyle visualStyle,
    required bool showTitle,
    required bool showAuthor,
    required bool showLatestChapter,
    required bool showProgressBar,
    required int titleMaxLines,
  }) {
    if (visualStyle == BookshelfGridVisualStyle.coverOnly ||
        visualStyle == BookshelfGridVisualStyle.overlayTitle) {
      return 0;
    }
    final hasMetaInfo =
        showTitle || showAuthor || showLatestChapter || showProgressBar;
    if (!hasMetaInfo) {
      return 36;
    }
    if (showTitle && titleMaxLines > 1) {
      return 128;
    }
    if (showLatestChapter) {
      return 92;
    }
    if (showProgressBar) {
      return 78;
    }
    return 62;
  }

  BookshelfListCoverLayout listCoverLayout({
    required bool compactMode,
    required bool showCover,
    required bool showLatestChapter,
    required bool showTaxonomyBadges,
    required bool showProgressBar,
    required bool showRecentReadTime,
  }) {
    final visibleDetailCount =
        <bool>[
          showLatestChapter,
          showTaxonomyBadges,
          showProgressBar,
          showRecentReadTime,
        ].where((visible) => visible).length;
    final fallbackCoverHeight =
        compactMode
            ? (visibleDetailCount >= 3
                ? 90.0
                : visibleDetailCount >= 2
                ? 82.0
                : 74.0)
            : (visibleDetailCount >= 3
                ? 118.0
                : visibleDetailCount >= 2
                ? 108.0
                : 96.0);
    final minCardHeight =
        compactMode
            ? (showCover ? fallbackCoverHeight + 18 : 72.0)
            : (showCover ? fallbackCoverHeight + 24 : 88.0);
    return BookshelfListCoverLayout(
      fallbackCoverHeight: fallbackCoverHeight,
      minCardHeight: minCardHeight,
    );
  }
}
