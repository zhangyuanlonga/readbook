import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_cover_layout_resolver.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_page_models.dart';

void main() {
  const resolver = BookshelfCoverLayoutResolver();

  group('BookshelfCoverLayoutResolver', () {
    test('uses zero extra height for cover-only grid styles', () {
      expect(
        resolver.gridCardItemHeightExtra(
          visualStyle: BookshelfGridVisualStyle.coverOnly,
          showTitle: true,
          showAuthor: true,
          showLatestChapter: true,
          showProgressBar: true,
          titleMaxLines: 2,
        ),
        0,
      );
      expect(
        resolver.gridCardItemHeightExtra(
          visualStyle: BookshelfGridVisualStyle.overlayTitle,
          showTitle: true,
          showAuthor: false,
          showLatestChapter: false,
          showProgressBar: false,
          titleMaxLines: 1,
        ),
        0,
      );
    });

    test('matches grid metadata height priorities', () {
      expect(
        resolver.gridCardItemHeightExtra(
          visualStyle: BookshelfGridVisualStyle.standard,
          showTitle: false,
          showAuthor: false,
          showLatestChapter: false,
          showProgressBar: false,
          titleMaxLines: 1,
        ),
        44,
      );
      expect(
        resolver.gridCardItemHeightExtra(
          visualStyle: BookshelfGridVisualStyle.standard,
          showTitle: true,
          showAuthor: false,
          showLatestChapter: false,
          showProgressBar: false,
          titleMaxLines: 2,
        ),
        144,
      );
      expect(
        resolver.gridCardItemHeightExtra(
          visualStyle: BookshelfGridVisualStyle.standard,
          showTitle: true,
          showAuthor: true,
          showLatestChapter: true,
          showProgressBar: true,
          titleMaxLines: 1,
        ),
        112,
      );
    });

    test('computes compact and regular list cover sizes', () {
      final compact = resolver.listCoverLayout(
        compactMode: true,
        showCover: true,
        showLatestChapter: true,
        showTaxonomyBadges: true,
        showProgressBar: true,
        showRecentReadTime: false,
      );
      expect(compact.fallbackCoverHeight, 90);
      expect(compact.minCardHeight, 108);
      expect(
        compact.coverHeight(
          hasFiniteConstraint: true,
          constrainedHeight: 300,
          cardPaddingVertical: 18,
        ),
        118,
      );

      final regularWithoutCover = resolver.listCoverLayout(
        compactMode: false,
        showCover: false,
        showLatestChapter: false,
        showTaxonomyBadges: false,
        showProgressBar: false,
        showRecentReadTime: false,
      );
      expect(regularWithoutCover.fallbackCoverHeight, 96);
      expect(regularWithoutCover.minCardHeight, 88);
    });
  });
}
