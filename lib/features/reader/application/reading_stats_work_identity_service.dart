class ReadingStatsWorkIdentityService {
  const ReadingStatsWorkIdentityService();

  Map<String, List<T>> groupItems<T>({
    required Iterable<T> items,
    required String Function(T item) titleOf,
    required String? Function(T item) authorOf,
    required String Function(T item) fallbackIdOf,
  }) {
    final byTitle = <String, List<T>>{};

    for (final item in items) {
      final normalizedTitle = normalizeTitle(titleOf(item));
      final titleKey =
          normalizedTitle.isEmpty
              ? '__untitled__:${fallbackIdOf(item).trim()}'
              : normalizedTitle;
      byTitle.putIfAbsent(titleKey, () => <T>[]).add(item);
    }

    final grouped = <String, List<T>>{};
    for (final entry in byTitle.entries) {
      final titleKey = entry.key;
      final authorBuckets = <String, List<T>>{};
      final unknownAuthorItems = <T>[];

      for (final item in entry.value) {
        final authorKey = normalizeAuthor(authorOf(item));
        if (authorKey.isEmpty) {
          unknownAuthorItems.add(item);
        } else {
          authorBuckets.putIfAbsent(authorKey, () => <T>[]).add(item);
        }
      }

      if (authorBuckets.isEmpty) {
        grouped[_buildKey(titleKey: titleKey)] = List<T>.from(entry.value);
        continue;
      }

      if (authorBuckets.length == 1) {
        final onlyAuthorKey = authorBuckets.keys.first;
        grouped[_buildKey(titleKey: titleKey, authorKey: onlyAuthorKey)] = <T>[
          ...authorBuckets.values.first,
          ...unknownAuthorItems,
        ];
        continue;
      }

      for (final bucket in authorBuckets.entries) {
        grouped[_buildKey(
          titleKey: titleKey,
          authorKey: bucket.key,
        )] = List<T>.from(bucket.value);
      }
      for (final item in unknownAuthorItems) {
        grouped[_buildKey(
          titleKey: titleKey,
          unknownId: fallbackIdOf(item),
        )] = <T>[item];
      }
    }

    return grouped;
  }

  int countDistinctWorks<T>({
    required Iterable<T> items,
    required String Function(T item) titleOf,
    required String? Function(T item) authorOf,
    required String Function(T item) fallbackIdOf,
  }) {
    return groupItems(
      items: items,
      titleOf: titleOf,
      authorOf: authorOf,
      fallbackIdOf: fallbackIdOf,
    ).length;
  }

  String normalizeTitle(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  String normalizeAuthor(String? value) {
    return (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'''[\s\-_:：·•,，.。/\\'"“”‘’（）()\[\]【】《》]+'''), '')
        .replaceAll(RegExp(r'(作者|著)$'), '');
  }

  String _buildKey({
    required String titleKey,
    String? authorKey,
    String? unknownId,
  }) {
    if (authorKey != null && authorKey.isNotEmpty) {
      return 'title:$titleKey|author:$authorKey';
    }
    if (unknownId != null && unknownId.trim().isNotEmpty) {
      return 'title:$titleKey|unknown:${unknownId.trim()}';
    }
    return 'title:$titleKey';
  }
}
