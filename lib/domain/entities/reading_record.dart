class ReadingRecord {
  const ReadingRecord({
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.bookTitle,
    this.bookAuthor,
    this.coverUrl,
    this.lastChapterId,
    this.lastChapterTitle,
    this.lastChapterIndex,
    this.lastChapterUrl,
    this.lastPositionRatio = 0,
    this.totalReadMillis = 0,
    required this.lastReadAt,
  });

  final String bookId;
  final String sourceId;
  final String detailUrl;
  final String bookTitle;
  final String? bookAuthor;
  final String? coverUrl;
  final String? lastChapterId;
  final String? lastChapterTitle;
  final int? lastChapterIndex;
  final String? lastChapterUrl;
  final double lastPositionRatio;
  final int totalReadMillis;
  final DateTime lastReadAt;
}
