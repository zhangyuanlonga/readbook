import 'dart:collection';

import 'aggregation_models.dart';
import 'dedupe_service.dart';
import '../sources/source_executor.dart';
import '../sources/source_registry.dart';
import '../sources/source_result_models.dart';

class SearchAggregator {
  SearchAggregator({
    required SourceRegistry sourceRegistry,
    required SourceExecutor sourceExecutor,
    DedupeService? dedupeService,
  }) : _sourceRegistry = sourceRegistry,
       _sourceExecutor = sourceExecutor,
       _dedupeService = dedupeService ?? const DedupeService();

  final SourceRegistry _sourceRegistry;
  final SourceExecutor _sourceExecutor;
  final DedupeService _dedupeService;

  Future<SearchAggregationResult> search(
    String keyword, {
    Iterable<String>? sourceIds,
    int concurrency = 4,
  }) async {
    final selectedSources =
        sourceIds == null
            ? _sourceRegistry.all()
            : sourceIds
                .map(_sourceRegistry.getById)
                .whereType<RegisteredSource>()
                .toList(growable: false);

    final queue = Queue<RegisteredSource>.from(selectedSources);
    final reports = <String, SourceSearchReport>{
      for (final source in selectedSources)
        source.runtime.id: SourceSearchReport(
          sourceId: source.runtime.id,
          status: SourceSearchStatus.queued,
        ),
    };
    final books = <Book>[];
    final workerCount =
        selectedSources.isEmpty
            ? 0
            : concurrency.clamp(1, selectedSources.length);

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final source = queue.removeFirst();
        reports[source.runtime.id] = SourceSearchReport(
          sourceId: source.runtime.id,
          status: SourceSearchStatus.running,
        );

        try {
          final result = await _sourceExecutor.search(source, keyword);
          books.addAll(result);
          reports[source.runtime.id] = SourceSearchReport(
            sourceId: source.runtime.id,
            status: SourceSearchStatus.success,
            resultCount: result.length,
          );
        } catch (error) {
          reports[source.runtime.id] = SourceSearchReport(
            sourceId: source.runtime.id,
            status: SourceSearchStatus.failed,
            error: error.toString(),
          );
        }
      }
    }

    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );

    return SearchAggregationResult(
      keyword: keyword,
      books: _dedupeService.dedupe(books),
      reports: Map<String, SourceSearchReport>.unmodifiable(reports),
    );
  }
}
