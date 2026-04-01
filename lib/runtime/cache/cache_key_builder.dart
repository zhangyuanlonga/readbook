class CacheKeyBuilder {
  const CacheKeyBuilder._();

  static String discoverCategories({required String sourceId}) {
    return '$sourceId:discover:categories';
  }

  static String discoverBooks({
    required String sourceId,
    required String categoryTitle,
    String? categoryUrl,
    required int page,
    required int pageSize,
  }) {
    final title = Uri.encodeQueryComponent(categoryTitle.trim());
    final url = Uri.encodeQueryComponent(categoryUrl?.trim() ?? '');
    return '$sourceId:discover:books:title=$title:url=$url:page=$page:size=$pageSize';
  }

  static String search({required String sourceId, required String keyword}) {
    return '$sourceId:search:keyword=${Uri.encodeQueryComponent(keyword.trim())}';
  }

  static String detail({required String sourceId, required String bookId}) {
    return '$sourceId:detail:book=$bookId';
  }

  static String chapters({required String sourceId, required String bookId}) {
    return '$sourceId:chapters:book=$bookId';
  }

  static String content({required String sourceId, required String chapterId}) {
    return '$sourceId:content:chapter=$chapterId';
  }
}
