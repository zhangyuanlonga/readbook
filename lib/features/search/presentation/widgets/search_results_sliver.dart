import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/layout/app_adaptive.dart';
import '../../../../app/widgets/adaptive_grid_sliver.dart';
import '../../../../domain/entities/book.dart';
import '../../../../domain/entities/book_metadata_override.dart';
import '../../../book/application/book_display_state.dart';
import '../../application/search_models.dart';
import '../search_render_state_controller.dart';
import 'search_book_card.dart';

typedef SearchResultHeroTagBuilder = String Function(Book book, int listIndex);

typedef SearchResultTapHandler =
    Future<void> Function({
      required Book book,
      required int listIndex,
      required String heroTag,
    });

class SearchResultsSliver extends StatelessWidget {
  const SearchResultsSliver({
    super.key,
    required this.books,
    required this.report,
    required this.renderState,
    required this.visibleCount,
    required this.presentationByTargetKey,
    required this.buildHeroTag,
    required this.onBookTap,
  });

  final List<Book> books;
  final SearchExecutionReport report;
  final SearchRenderState renderState;
  final int visibleCount;
  final Map<String, BookDisplayState> presentationByTargetKey;
  final SearchResultHeroTagBuilder buildHeroTag;
  final SearchResultTapHandler onBookTap;

  @override
  Widget build(BuildContext context) {
    final useCompactList = AppAdaptiveMetrics.of(context).isCompactWindow;
    if (useCompactList) {
      return SliverList.builder(
        itemCount: visibleCount,
        findChildIndexCallback: _findChildIndexByKey,
        itemBuilder: (context, index) {
          return _buildSearchBookCard(index);
        },
      );
    }

    return AdaptiveGridSliver(
      itemCount: visibleCount,
      minItemWidth: 300,
      minColumns: 1,
      maxColumns: 3,
      mainSpacing: 0,
      childAspectRatio: 2.55,
      findChildIndexCallback: _findChildIndexByKey,
      itemBuilder: (context, index) {
        return _buildSearchBookCard(index);
      },
    );
  }

  int? _findChildIndexByKey(Key key) {
    final resultKey = _searchResultKeyFromKey(key);
    if (resultKey == null) {
      return null;
    }
    final limitedCount = visibleCount.clamp(0, books.length).toInt();
    for (var index = 0; index < limitedCount; index += 1) {
      if (_searchResultKey(books[index]) == resultKey) {
        return index;
      }
    }
    return null;
  }

  String? _searchResultKeyFromKey(Key key) {
    if (key is! ValueKey<String>) {
      return null;
    }
    const prefix = 'search_result_';
    final value = key.value;
    return value.startsWith(prefix) ? value.substring(prefix.length) : null;
  }

  Widget _buildSearchBookCard(int listIndex) {
    final book = books[listIndex];
    final sourceName = report.sourceNames[book.sourceId] ?? book.sourceId;
    final targetKey = BookMetadataOverride.remoteTargetKey(
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
    );
    final heroTag = buildHeroTag(book, listIndex);

    return KeyedSubtree(
      key: ValueKey<String>('search_result_${_searchResultKey(book)}'),
      child: SearchBookCard(
        book: book,
        presentation:
            presentationByTargetKey[targetKey] ??
            const BookDisplayState(displayTitle: ''),
        sourceName: sourceName,
        sourceHitCount: report.sourceHitCountOf(book),
        heroTag: heroTag,
        normalizedIntro: renderState.normalizedIntros[book.id],
        normalizedLatestChapter: renderState.normalizedLatestChapters[book.id],
        onTap:
            () => unawaited(
              onBookTap(book: book, listIndex: listIndex, heroTag: heroTag),
            ),
      ),
    );
  }

  String _searchResultKey(Book book) {
    return '${book.sourceId}::${book.detailUrl}::${book.id}';
  }
}
