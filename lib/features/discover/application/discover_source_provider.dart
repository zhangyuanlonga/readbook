import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'server_discover_gateway_service.dart';
import '../domain/discover_source_summary.dart';

final serverDiscoverGatewayServiceProvider =
    Provider<ServerDiscoverGatewayService>((ref) {
      return ServerDiscoverGatewayService();
    });

final discoverSourcePagerProvider =
    AsyncNotifierProvider<DiscoverSourcePager, DiscoverSourcePagerState>(
      DiscoverSourcePager.new,
    );

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

class DiscoverSourcePager extends AsyncNotifier<DiscoverSourcePagerState> {
  static const int pageSize =
      ServerDiscoverGatewayService.defaultSourcePageSize;

  @override
  Future<DiscoverSourcePagerState> build() async {
    return _loadFirstPage();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<DiscoverSourcePagerState>();
    state = await AsyncValue.guard(_loadFirstPage);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final service = ref.read(serverDiscoverGatewayServiceProvider);
      final page = await service.loadDiscoverSourcePage(
        page: current.page + 1,
        pageSize: current.pageSize,
      );
      final merged = _mergeSources(current.items, page.items);
      state = AsyncData(
        current.copyWith(
          items: merged,
          page: page.page,
          pageSize: page.pageSize == 0 ? current.pageSize : page.pageSize,
          total: page.total,
          hasMore: page.hasMore,
          isLoadingMore: false,
          loadMoreError: null,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreError: error),
      );
    }
  }

  Future<List<DiscoverSourceSummary>> searchRemote(String keyword) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return const <DiscoverSourceSummary>[];
    }
    final service = ref.read(serverDiscoverGatewayServiceProvider);
    final page = await service.searchDiscoverSources(
      keyword: normalized,
      pageSize: pageSize,
    );
    return page.items;
  }

  Future<DiscoverSourcePagerState> _loadFirstPage() async {
    final service = ref.read(serverDiscoverGatewayServiceProvider);
    final page = await service.loadDiscoverSourcePage(
      page: 1,
      pageSize: pageSize,
    );
    return DiscoverSourcePagerState(
      items: page.items,
      page: page.page,
      pageSize: page.pageSize == 0 ? pageSize : page.pageSize,
      total: page.total,
      hasMore: page.hasMore,
    );
  }

  List<DiscoverSourceSummary> _mergeSources(
    List<DiscoverSourceSummary> current,
    List<DiscoverSourceSummary> next,
  ) {
    if (next.isEmpty) {
      return current;
    }
    final seen = current.map((source) => source.id).toSet();
    final merged = <DiscoverSourceSummary>[...current];
    for (final source in next) {
      if (seen.add(source.id)) {
        merged.add(source);
      }
    }
    return merged;
  }
}

class DiscoverSourcePagerState {
  const DiscoverSourcePagerState({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<DiscoverSourceSummary> items;
  final int page;
  final int pageSize;
  final int total;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? loadMoreError;

  int get loadedCount => items.length;

  DiscoverSourcePagerState copyWith({
    List<DiscoverSourceSummary>? items,
    int? page,
    int? pageSize,
    int? total,
    bool? hasMore,
    bool? isLoadingMore,
    Object? loadMoreError,
  }) {
    return DiscoverSourcePagerState(
      items: items ?? this.items,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: loadMoreError,
    );
  }
}

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
