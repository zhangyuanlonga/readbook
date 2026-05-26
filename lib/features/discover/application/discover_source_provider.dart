import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'server_discover_gateway_service.dart';
import '../domain/discover_source_summary.dart';

final serverDiscoverGatewayServiceProvider =
    Provider<ServerDiscoverGatewayService>((ref) {
      return ServerDiscoverGatewayService();
    });

final discoverSourceSummariesProvider =
    FutureProvider<List<DiscoverSourceSummary>>((ref) async {
      final service = ref.watch(serverDiscoverGatewayServiceProvider);
      return service.loadDiscoverSources();
    });

final discoverSourceCategoriesProvider =
    FutureProvider.family<DiscoverSourceSummary, DiscoverSourceSummary>((
      ref,
      source,
    ) async {
      final service = ref.watch(serverDiscoverGatewayServiceProvider);
      return service.loadSourceCategories(source: source);
    });

final discoverCategoryBooksProvider = FutureProvider.family<
  List<DiscoverCategoryBook>,
  DiscoverCategoryBooksRequest
>((ref, request) async {
  final service = ref.watch(serverDiscoverGatewayServiceProvider);
  return service.loadCategoryBooks(
    source: request.source,
    category: request.category,
    page: request.page,
  );
});

class DiscoverCategoryBooksRequest {
  const DiscoverCategoryBooksRequest({
    required this.source,
    required this.category,
    this.page = 1,
  });

  final DiscoverSourceSummary source;
  final DiscoverSourceCategory category;
  final int page;

  @override
  bool operator ==(Object other) {
    return other is DiscoverCategoryBooksRequest &&
        other.source.id == source.id &&
        other.category.id == category.id &&
        other.category.ruleFindUrl == category.ruleFindUrl &&
        other.page == page;
  }

  @override
  int get hashCode =>
      Object.hash(source.id, category.id, category.ruleFindUrl, page);
}
