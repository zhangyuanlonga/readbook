class CacheBudgetPolicy {
  const CacheBudgetPolicy({
    required this.maxEntries,
    required this.maxBytes,
    required this.stalePeriod,
  });

  final int maxEntries;
  final int maxBytes;
  final Duration stalePeriod;
}

class AppCacheBudgetPolicies {
  const AppCacheBudgetPolicies._();

  static const chapterCaches = CacheBudgetPolicy(
    maxEntries: 3000,
    maxBytes: 96 * 1024 * 1024,
    stalePeriod: Duration(days: 45),
  );

  static const paginationLayouts = CacheBudgetPolicy(
    maxEntries: 1200,
    maxBytes: 24 * 1024 * 1024,
    stalePeriod: Duration(days: 30),
  );

  static const coverImages = CacheBudgetPolicy(
    maxEntries: 300,
    maxBytes: 48 * 1024 * 1024,
    stalePeriod: Duration(days: 30),
  );
}
