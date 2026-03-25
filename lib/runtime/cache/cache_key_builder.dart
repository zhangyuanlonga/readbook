class CacheKeyBuilder {
  const CacheKeyBuilder._();

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
