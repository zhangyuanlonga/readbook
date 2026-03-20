class ReadingRecordSession {
  const ReadingRecordSession({
    required this.id,
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.bookTitle,
    this.bookAuthor,
    this.coverUrl,
    this.chapterId,
    this.chapterTitle,
    this.chapterIndex,
    this.chapterUrl,
    required this.startAt,
    required this.endAt,
    required this.durationMillis,
    this.readChars = 0,
    this.startPositionRatio = 0,
    this.endPositionRatio = 0,
  });

  final int id;
  final String bookId;
  final String sourceId;
  final String detailUrl;
  final String bookTitle;
  final String? bookAuthor;
  final String? coverUrl;
  final String? chapterId;
  final String? chapterTitle;
  final int? chapterIndex;
  final String? chapterUrl;
  final DateTime startAt;
  final DateTime endAt;
  final int durationMillis;
  final int readChars;
  final double startPositionRatio;
  final double endPositionRatio;
}
