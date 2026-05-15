part of 'search_service.dart';

Future<SearchExecutionReport> buildSearchExecutionReportWithExistingAggregator({
  required String keyword,
  required int sourceCount,
  required int successSourceCount,
  required Map<String, Book> booksById,
  required List<SourceSearchFailure> failures,
  required Map<String, String> sourceNames,
  required Map<String, int> sourceOrderById,
  required bool aggregateByTitleAuthor,
  int? processedSourceCountOverride,
}) async {
  final report = await _SearchReportAssembler(
    logger: AppLogger.instance,
    searchHitCacheService: SearchHitCacheService(),
    progressAggregationInterval: Duration.zero,
  ).buildExecutionReport(
    keyword: keyword,
    sourceCount: sourceCount,
    successSourceCount: successSourceCount,
    booksById: booksById,
    failures: failures,
    sourceNames: sourceNames,
    sourceOrderById: sourceOrderById,
    aggregateByTitleAuthor: aggregateByTitleAuthor,
  );
  if (processedSourceCountOverride == null) {
    return report;
  }
  return SearchExecutionReport(
    keyword: report.keyword,
    sourceCount: report.sourceCount,
    successSourceCount: report.successSourceCount,
    books: report.books,
    failures: report.failures,
    sourceNames: report.sourceNames,
    bookSourceHitCounts: report.bookSourceHitCounts,
    bookSourceHits: report.bookSourceHits,
    processedSourceCountOverride: processedSourceCountOverride,
  );
}

class _SearchReportAssembler {
  const _SearchReportAssembler({
    required AppLogger logger,
    required SearchHitCacheService searchHitCacheService,
    required Duration progressAggregationInterval,
  }) : _logger = logger,
       _searchHitCacheService = searchHitCacheService,
       _progressAggregationInterval = progressAggregationInterval;

  final AppLogger _logger;
  final SearchHitCacheService _searchHitCacheService;
  final Duration _progressAggregationInterval;

  Duration get progressAggregationInterval => _progressAggregationInterval;

  Future<void> persistSearchHitCache({
    required Iterable<Book> books,
    required Map<String, String> sourceNames,
  }) async {
    if (books.isEmpty) {
      return;
    }

    try {
      await _searchHitCacheService.recordBooks(books, sourceNames: sourceNames);
    } catch (error) {
      _logger.warn(
        'Persist search hit cache failed',
        context: <String, Object?>{'error': error.toString()},
      );
    }
  }

  Future<SearchExecutionReport> buildExecutionReport({
    required String keyword,
    required int sourceCount,
    required int successSourceCount,
    required Map<String, Book> booksById,
    required List<SourceSearchFailure> failures,
    required Map<String, String> sourceNames,
    required Map<String, int> sourceOrderById,
    required bool aggregateByTitleAuthor,
  }) async {
    final books = booksById.values.toList(growable: false);
    final hitCounts = <String, int>{};
    final hitBooks = <String, List<Book>>{};

    late final List<Book> outputBooks;
    if (aggregateByTitleAuthor) {
      final aggregated = await _aggregateAndRankBooksAsync(
        keyword: keyword,
        books: books,
        sourceOrderById: sourceOrderById,
      );
      outputBooks = aggregated.books;
      hitCounts.addAll(aggregated.hitCountsByPrimaryBookId);
      hitBooks.addAll(aggregated.hitsByPrimaryBookId);
    } else {
      outputBooks = books;
      for (final book in books) {
        hitCounts[book.id] = 1;
        hitBooks[book.id] = List.unmodifiable(<Book>[book]);
      }
    }

    return SearchExecutionReport(
      keyword: keyword,
      sourceCount: sourceCount,
      successSourceCount: successSourceCount,
      books: List.unmodifiable(outputBooks),
      failures: List.unmodifiable(failures),
      sourceNames: Map.unmodifiable(sourceNames),
      bookSourceHitCounts: Map.unmodifiable(hitCounts),
      bookSourceHits: Map.unmodifiable(hitBooks),
    );
  }

  Future<_AggregatedBookReport> _aggregateAndRankBooksAsync({
    required String keyword,
    required Iterable<Book> books,
    required Map<String, int> sourceOrderById,
  }) async {
    final candidateBooks = books.toList(growable: false);
    if (candidateBooks.length < 160) {
      return _aggregateAndRankBooks(
        keyword: keyword,
        books: candidateBooks,
        sourceOrderById: sourceOrderById,
      );
    }

    try {
      return await Isolate.run(
        () => _aggregateAndRankBooksInIsolate(
          _AggregateAndRankInput(
            keyword: keyword,
            books: candidateBooks,
            sourceOrderById: sourceOrderById,
          ),
        ),
      );
    } catch (_) {
      return _aggregateAndRankBooks(
        keyword: keyword,
        books: candidateBooks,
        sourceOrderById: sourceOrderById,
      );
    }
  }

  _AggregatedBookReport _aggregateAndRankBooks({
    required String keyword,
    required Iterable<Book> books,
    required Map<String, int> sourceOrderById,
  }) {
    final normalizedKeyword = _normalizeAggregateText(keyword);
    final groupsByKey = <_BookAggregateKey, _BookAggregateGroup>{};

    for (final book in books) {
      final key = _BookAggregateKey(title: book.title, author: book.author);
      final group = groupsByKey.putIfAbsent(key, () => _BookAggregateGroup());

      final existing = group.hitsBySourceId[book.sourceId];
      if (existing == null) {
        group.hitsBySourceId[book.sourceId] = book;
      } else {
        final candidateScore = _bookQualityScore(
          book,
          normalizedKeyword: normalizedKeyword,
          sourceOrderById: sourceOrderById,
        );
        final existingScore = _bookQualityScore(
          existing,
          normalizedKeyword: normalizedKeyword,
          sourceOrderById: sourceOrderById,
        );
        if (candidateScore > existingScore) {
          group.hitsBySourceId[book.sourceId] = book;
        }
      }
      final tier = _resolveBookRelevanceTier(
        book,
        normalizedKeyword: normalizedKeyword,
      );
      if (tier > group.relevanceTier) {
        group.relevanceTier = tier;
      }
    }

    final aggregates = <_RankedAggregateBook>[];
    for (final group in groupsByKey.values) {
      final hits = group.hitsBySourceId.values.toList(growable: false);
      if (hits.isEmpty) {
        continue;
      }
      final sortedHits = hits.toList(growable: false)..sort((a, b) {
        final qualityDiff =
            _bookQualityScore(
              b,
              normalizedKeyword: normalizedKeyword,
              sourceOrderById: sourceOrderById,
            ) -
            _bookQualityScore(
              a,
              normalizedKeyword: normalizedKeyword,
              sourceOrderById: sourceOrderById,
            );
        if (qualityDiff != 0) {
          return qualityDiff;
        }
        final sourceOrderDiff = (sourceOrderById[a.sourceId] ?? 1 << 20)
            .compareTo(sourceOrderById[b.sourceId] ?? 1 << 20);
        if (sourceOrderDiff != 0) {
          return sourceOrderDiff;
        }
        return a.title.compareTo(b.title);
      });
      final primaryBook = sortedHits.first;
      aggregates.add(
        _RankedAggregateBook(
          primaryBook: primaryBook,
          hits: List.unmodifiable(sortedHits),
          relevanceTier: group.relevanceTier,
          primaryQualityScore: _bookQualityScore(
            primaryBook,
            normalizedKeyword: normalizedKeyword,
            sourceOrderById: sourceOrderById,
          ),
          primarySourceOrder: sourceOrderById[primaryBook.sourceId] ?? 1 << 20,
        ),
      );
    }

    aggregates.sort((a, b) {
      final tierDiff = b.relevanceTier.compareTo(a.relevanceTier);
      if (tierDiff != 0) {
        return tierDiff;
      }
      final hitCountDiff = b.hits.length.compareTo(a.hits.length);
      if (hitCountDiff != 0) {
        return hitCountDiff;
      }
      final qualityDiff = b.primaryQualityScore.compareTo(
        a.primaryQualityScore,
      );
      if (qualityDiff != 0) {
        return qualityDiff;
      }
      final sourceOrderDiff = a.primarySourceOrder.compareTo(
        b.primarySourceOrder,
      );
      if (sourceOrderDiff != 0) {
        return sourceOrderDiff;
      }
      return a.primaryBook.title.compareTo(b.primaryBook.title);
    });

    final booksOut = <Book>[];
    final hitCounts = <String, int>{};
    final hitsByPrimaryBookId = <String, List<Book>>{};
    for (final aggregate in aggregates) {
      booksOut.add(aggregate.primaryBook);
      hitCounts[aggregate.primaryBook.id] = aggregate.hits.length;
      hitsByPrimaryBookId[aggregate.primaryBook.id] = aggregate.hits;
    }

    return _AggregatedBookReport(
      books: List.unmodifiable(booksOut),
      hitCountsByPrimaryBookId: Map.unmodifiable(hitCounts),
      hitsByPrimaryBookId: Map.unmodifiable(hitsByPrimaryBookId),
    );
  }

  int _resolveBookRelevanceTier(
    Book book, {
    required String normalizedKeyword,
  }) {
    if (normalizedKeyword.isEmpty) {
      return 1;
    }
    final normalizedTitle = _normalizeAggregateText(book.title);
    final normalizedAuthor = _normalizeAggregateText(book.author ?? '');

    if (normalizedTitle == normalizedKeyword ||
        normalizedAuthor == normalizedKeyword) {
      return 3;
    }
    if (normalizedTitle.contains(normalizedKeyword) ||
        normalizedAuthor.contains(normalizedKeyword)) {
      return 2;
    }
    return 1;
  }

  int _bookQualityScore(
    Book book, {
    required String normalizedKeyword,
    required Map<String, int> sourceOrderById,
  }) {
    var score =
        _resolveBookRelevanceTier(book, normalizedKeyword: normalizedKeyword) *
        1000;
    if (book.coverUrl?.trim().isNotEmpty == true) {
      score += 40;
    }
    if (book.latestChapter?.trim().isNotEmpty == true) {
      score += 24;
    }
    if (book.intro?.trim().isNotEmpty == true) {
      score += 12;
    }
    final sourceOrder = sourceOrderById[book.sourceId] ?? 200;
    score += max(0, 200 - min(sourceOrder, 200));
    return score;
  }

  String _normalizeAggregateText(String raw) {
    var normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }
    normalized = normalized.replaceAll(RegExp(r'<[^>]+>'), ' ');
    normalized = normalized.replaceAll(RegExp(r'[\u3000\s]+'), ' ');
    normalized = normalized.replaceAll(RegExp(r'[《》〈〉【】\\[\\]()（）<>「」『』]'), '');
    return normalized.trim();
  }
}

class _BookAggregateGroup {
  final Map<String, Book> hitsBySourceId = <String, Book>{};
  int relevanceTier = 1;
}

class _BookAggregateKey {
  const _BookAggregateKey({required this.title, required this.author});

  final String title;
  final String? author;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BookAggregateKey &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          author == other.author;

  @override
  int get hashCode => Object.hash(title, author);
}

class _RankedAggregateBook {
  const _RankedAggregateBook({
    required this.primaryBook,
    required this.hits,
    required this.relevanceTier,
    required this.primaryQualityScore,
    required this.primarySourceOrder,
  });

  final Book primaryBook;
  final List<Book> hits;
  final int relevanceTier;
  final int primaryQualityScore;
  final int primarySourceOrder;
}

class _AggregatedBookReport {
  const _AggregatedBookReport({
    required this.books,
    required this.hitCountsByPrimaryBookId,
    required this.hitsByPrimaryBookId,
  });

  final List<Book> books;
  final Map<String, int> hitCountsByPrimaryBookId;
  final Map<String, List<Book>> hitsByPrimaryBookId;
}

class _AggregateAndRankInput {
  const _AggregateAndRankInput({
    required this.keyword,
    required this.books,
    required this.sourceOrderById,
  });

  final String keyword;
  final List<Book> books;
  final Map<String, int> sourceOrderById;
}

_AggregatedBookReport _aggregateAndRankBooksInIsolate(
  _AggregateAndRankInput input,
) {
  final normalizedKeyword = _normalizeAggregateTextForIsolate(input.keyword);
  final groupsByKey = <_BookAggregateKey, _BookAggregateGroup>{};

  for (final book in input.books) {
    final key = _BookAggregateKey(title: book.title, author: book.author);
    final group = groupsByKey.putIfAbsent(key, () => _BookAggregateGroup());

    final existing = group.hitsBySourceId[book.sourceId];
    if (existing == null) {
      group.hitsBySourceId[book.sourceId] = book;
    } else {
      final candidateScore = _bookQualityScoreForIsolate(
        book,
        normalizedKeyword: normalizedKeyword,
        sourceOrderById: input.sourceOrderById,
      );
      final existingScore = _bookQualityScoreForIsolate(
        existing,
        normalizedKeyword: normalizedKeyword,
        sourceOrderById: input.sourceOrderById,
      );
      if (candidateScore > existingScore) {
        group.hitsBySourceId[book.sourceId] = book;
      }
    }
    final tier = _resolveBookRelevanceTierForIsolate(
      book,
      normalizedKeyword: normalizedKeyword,
    );
    if (tier > group.relevanceTier) {
      group.relevanceTier = tier;
    }
  }

  final aggregates = <_RankedAggregateBook>[];
  for (final group in groupsByKey.values) {
    final hits = group.hitsBySourceId.values.toList(growable: false);
    if (hits.isEmpty) {
      continue;
    }
    final sortedHits = hits.toList(growable: false)..sort((a, b) {
      final qualityDiff =
          _bookQualityScoreForIsolate(
            b,
            normalizedKeyword: normalizedKeyword,
            sourceOrderById: input.sourceOrderById,
          ) -
          _bookQualityScoreForIsolate(
            a,
            normalizedKeyword: normalizedKeyword,
            sourceOrderById: input.sourceOrderById,
          );
      if (qualityDiff != 0) {
        return qualityDiff;
      }
      final sourceOrderDiff = (input.sourceOrderById[a.sourceId] ?? 1 << 20)
          .compareTo(input.sourceOrderById[b.sourceId] ?? 1 << 20);
      if (sourceOrderDiff != 0) {
        return sourceOrderDiff;
      }
      return a.title.compareTo(b.title);
    });
    final primaryBook = sortedHits.first;
    aggregates.add(
      _RankedAggregateBook(
        primaryBook: primaryBook,
        hits: List.unmodifiable(sortedHits),
        relevanceTier: group.relevanceTier,
        primaryQualityScore: _bookQualityScoreForIsolate(
          primaryBook,
          normalizedKeyword: normalizedKeyword,
          sourceOrderById: input.sourceOrderById,
        ),
        primarySourceOrder:
            input.sourceOrderById[primaryBook.sourceId] ?? 1 << 20,
      ),
    );
  }

  aggregates.sort((a, b) {
    final tierDiff = b.relevanceTier.compareTo(a.relevanceTier);
    if (tierDiff != 0) {
      return tierDiff;
    }
    final hitCountDiff = b.hits.length.compareTo(a.hits.length);
    if (hitCountDiff != 0) {
      return hitCountDiff;
    }
    final qualityDiff = b.primaryQualityScore.compareTo(a.primaryQualityScore);
    if (qualityDiff != 0) {
      return qualityDiff;
    }
    final sourceOrderDiff = a.primarySourceOrder.compareTo(
      b.primarySourceOrder,
    );
    if (sourceOrderDiff != 0) {
      return sourceOrderDiff;
    }
    return a.primaryBook.title.compareTo(b.primaryBook.title);
  });

  final booksOut = <Book>[];
  final hitCounts = <String, int>{};
  final hitsByPrimaryBookId = <String, List<Book>>{};
  for (final aggregate in aggregates) {
    booksOut.add(aggregate.primaryBook);
    hitCounts[aggregate.primaryBook.id] = aggregate.hits.length;
    hitsByPrimaryBookId[aggregate.primaryBook.id] = aggregate.hits;
  }

  return _AggregatedBookReport(
    books: List.unmodifiable(booksOut),
    hitCountsByPrimaryBookId: Map.unmodifiable(hitCounts),
    hitsByPrimaryBookId: Map.unmodifiable(hitsByPrimaryBookId),
  );
}

int _resolveBookRelevanceTierForIsolate(
  Book book, {
  required String normalizedKeyword,
}) {
  if (normalizedKeyword.isEmpty) {
    return 1;
  }
  final normalizedTitle = _normalizeAggregateTextForIsolate(book.title);
  final normalizedAuthor = _normalizeAggregateTextForIsolate(book.author ?? '');

  if (normalizedTitle == normalizedKeyword ||
      normalizedAuthor == normalizedKeyword) {
    return 3;
  }
  if (normalizedTitle.contains(normalizedKeyword) ||
      normalizedAuthor.contains(normalizedKeyword)) {
    return 2;
  }
  return 1;
}

int _bookQualityScoreForIsolate(
  Book book, {
  required String normalizedKeyword,
  required Map<String, int> sourceOrderById,
}) {
  var score =
      _resolveBookRelevanceTierForIsolate(
        book,
        normalizedKeyword: normalizedKeyword,
      ) *
      1000;
  if (book.coverUrl?.trim().isNotEmpty == true) {
    score += 40;
  }
  if (book.latestChapter?.trim().isNotEmpty == true) {
    score += 24;
  }
  if (book.intro?.trim().isNotEmpty == true) {
    score += 12;
  }
  final sourceOrder = sourceOrderById[book.sourceId] ?? 200;
  score += max(0, 200 - min(sourceOrder, 200));
  return score;
}

String _normalizeAggregateTextForIsolate(String raw) {
  var normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) {
    return '';
  }
  normalized = normalized.replaceAll(RegExp(r'<[^>]+>'), ' ');
  normalized = normalized.replaceAll(RegExp(r'[\u3000\s]+'), ' ');
  normalized = normalized.replaceAll(RegExp(r'[《》〈〉【】\\[\\]()（）<>「」『』]'), '');
  return normalized.trim();
}
