import '../sources/source_result_models.dart';

enum SourceSearchStatus { queued, running, success, failed }

class SourceSearchReport {
  const SourceSearchReport({
    required this.sourceId,
    required this.status,
    this.resultCount = 0,
    this.error,
  });

  final String sourceId;
  final SourceSearchStatus status;
  final int resultCount;
  final String? error;
}

class AggregatedBook {
  const AggregatedBook({
    required this.key,
    required this.primary,
    required this.sourceBooks,
  });

  final String key;
  final Book primary;
  final List<Book> sourceBooks;
}

class SearchAggregationResult {
  const SearchAggregationResult({
    required this.keyword,
    required this.books,
    required this.reports,
  });

  final String keyword;
  final List<AggregatedBook> books;
  final Map<String, SourceSearchReport> reports;
}
