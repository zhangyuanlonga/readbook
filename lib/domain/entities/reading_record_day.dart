class ReadingRecordDay {
  const ReadingRecordDay({
    required this.bookId,
    required this.dateKey,
    required this.bookTitle,
    this.bookAuthor,
    this.coverUrl,
    required this.readMillis,
    this.readChars = 0,
    required this.firstReadAt,
    required this.lastReadAt,
  });

  final String bookId;
  final String dateKey;
  final String bookTitle;
  final String? bookAuthor;
  final String? coverUrl;
  final int readMillis;
  final int readChars;
  final DateTime firstReadAt;
  final DateTime lastReadAt;
}
