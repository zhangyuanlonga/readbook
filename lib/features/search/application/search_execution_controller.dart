import 'search_models.dart';
import 'server_online_search_service.dart';

typedef SearchExecutionRunner =
    Future<SearchExecutionReport> Function(SearchExecutionRequest request);

class SearchExecutionRequest {
  const SearchExecutionRequest({
    required this.keyword,
    required this.contentMode,
    required this.preciseMatch,
    required this.aggregateByTitleAuthor,
    this.sourceIds,
    this.groupNames,
    this.cancellationToken,
    this.onProgress,
  });

  final String keyword;
  final SearchContentMode contentMode;
  final bool preciseMatch;
  final bool aggregateByTitleAuthor;
  final List<String>? sourceIds;
  final List<String>? groupNames;
  final SearchCancellationToken? cancellationToken;
  final SearchProgressCallback? onProgress;
}

class SearchExecutionController {
  SearchExecutionController({required SearchExecutionRunner runSearch})
    : _runSearch = runSearch;

  factory SearchExecutionController.fromService(
    ServerOnlineSearchService service,
  ) {
    return SearchExecutionController(
      runSearch: (request) {
        return service.search(
          keyword: request.keyword,
          contentMode: request.contentMode,
          sourceIds: request.sourceIds,
          groupNames: request.groupNames,
          preciseMatch: request.preciseMatch,
          aggregateByTitleAuthor: request.aggregateByTitleAuthor,
          cancellationToken: request.cancellationToken,
          onProgress: request.onProgress,
        );
      },
    );
  }

  final SearchExecutionRunner _runSearch;

  Future<SearchExecutionReport> run(SearchExecutionRequest request) {
    return _runSearch(request);
  }
}
