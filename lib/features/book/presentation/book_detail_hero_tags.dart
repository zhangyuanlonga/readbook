class BookDetailHeroTagResolver {
  const BookDetailHeroTagResolver();

  String cover({
    required String? explicitHeroTag,
    required String bookId,
    required String sourceId,
    required String detailUrl,
  }) {
    final explicit = _normalizedExplicitTag(explicitHeroTag);
    if (explicit != null) {
      return explicit;
    }
    return _detailTag(
      prefix: 'book_cover',
      bookId: bookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
    );
  }

  String title({
    required String? explicitHeroTag,
    required String bookId,
    required String sourceId,
    required String detailUrl,
  }) {
    final explicit = _normalizedExplicitTag(explicitHeroTag);
    if (explicit != null) {
      return explicit;
    }
    return _detailTag(
      prefix: 'book_title',
      bookId: bookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
    );
  }

  String meta({
    required String? explicitHeroTag,
    required String bookId,
    required String sourceId,
    required String detailUrl,
  }) {
    final explicit = _normalizedExplicitTag(explicitHeroTag);
    if (explicit != null) {
      return explicit;
    }
    return _detailTag(
      prefix: 'book_meta',
      bookId: bookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
    );
  }

  String readerCover({
    required String bookId,
    required String sourceId,
    required String detailUrl,
  }) {
    return _detailTag(
      prefix: 'reader_cover',
      bookId: bookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
    );
  }

  String loadingCover(String bookId) => 'book_loading_${bookId.trim()}';

  String desktopEditorCover(String coverHeroTag) {
    return '${coverHeroTag.trim()}_desktop_editor';
  }

  String _detailTag({
    required String prefix,
    required String bookId,
    required String sourceId,
    required String detailUrl,
  }) {
    return '${prefix}_${sourceId.trim()}_${bookId.trim()}_${detailUrl.hashCode}';
  }

  String? _normalizedExplicitTag(String? raw) {
    final normalized = raw?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
