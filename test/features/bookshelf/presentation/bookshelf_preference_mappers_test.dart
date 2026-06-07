import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_page_state.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_page_models.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_preference_mappers.dart';

void main() {
  group('bookshelf preference mappers', () {
    test('maps sort mode storage values and falls back to default', () {
      expect(
        sortModeFromStorageValue(BookshelfService.recentReadSortMode),
        BookshelfSortMode.recentRead,
      );
      expect(
        sortModeStorageValue(BookshelfSortMode.readingProgress),
        BookshelfService.readingProgressSortMode,
      );
      expect(
        sortModeFromStorageValue('unknown'),
        BookshelfSortMode.defaultOrder,
      );
    });

    test('maps grid visual style storage values and labels', () {
      expect(
        gridVisualStyleFromStorageValue(
          BookshelfService.gridOverlayTitleVisualStyle,
        ),
        BookshelfGridVisualStyle.overlayTitle,
      );
      expect(
        gridVisualStyleStorageValue(BookshelfGridVisualStyle.coverOnly),
        BookshelfService.gridCoverOnlyVisualStyle,
      );
      expect(gridVisualStyleLabel(BookshelfGridVisualStyle.standard), '标准');
    });

    test('maps progress info mode storage values and labels', () {
      expect(
        progressInfoModeFromStorageValue(
          BookshelfService.progressInfoModeUnreadChapters,
        ),
        BookshelfProgressInfoMode.unreadChapters,
      );
      expect(
        progressInfoModeStorageValue(BookshelfProgressInfoMode.progressBar),
        BookshelfService.progressInfoModeProgressBar,
      );
      expect(
        progressInfoModeLabel(BookshelfProgressInfoMode.unreadChapters),
        '未读章节数',
      );
    });

    test('maps search quick filter storage values and labels', () {
      expect(
        searchQuickFilterContentFromStorageValue('tags'),
        BookshelfSearchQuickFilterContent.tags,
      );
      expect(
        searchQuickFilterContentStorageValue(
          BookshelfSearchQuickFilterContent.categories,
        ),
        'categories',
      );
      expect(
        searchQuickFilterContentLabel(BookshelfSearchQuickFilterContent.none),
        '不显示',
      );
    });
  });
}
