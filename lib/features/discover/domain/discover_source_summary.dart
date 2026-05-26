enum DiscoverSourceStatus { available, slow, unavailable }

class DiscoverSourceSummary {
  const DiscoverSourceSummary({
    required this.id,
    required this.name,
    required this.categoryCount,
    required this.status,
    required this.latencyMs,
    required this.categories,
  });

  final String id;
  final String name;
  final int categoryCount;
  final DiscoverSourceStatus status;
  final int? latencyMs;
  final List<DiscoverSourceCategory> categories;
}

class DiscoverSourceCategory {
  const DiscoverSourceCategory({
    required this.id,
    required this.name,
    required this.books,
  });

  final String id;
  final String name;
  final List<DiscoverCategoryBook> books;
}

class DiscoverCategoryBook {
  const DiscoverCategoryBook({
    required this.id,
    required this.name,
    required this.detailUrl,
    required this.coverSeed,
  });

  final String id;
  final String name;
  final String detailUrl;
  final int coverSeed;
}
