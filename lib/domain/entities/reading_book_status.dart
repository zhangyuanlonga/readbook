enum ReadingBookStatusKind { reading, completed }

enum ReadingBookStatusOverride { reading, completed }

class ReadingBookStatusEntry {
  const ReadingBookStatusEntry({
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.bookTitle,
    required this.override,
    required this.updatedAt,
  });

  final String bookId;
  final String sourceId;
  final String detailUrl;
  final String bookTitle;
  final ReadingBookStatusOverride override;
  final DateTime updatedAt;
}

class ReadingBookResolvedStatus {
  const ReadingBookResolvedStatus({required this.kind, required this.isManual});

  final ReadingBookStatusKind kind;
  final bool isManual;

  bool get isCompleted => kind == ReadingBookStatusKind.completed;

  String get label {
    return switch (kind) {
      ReadingBookStatusKind.reading => '在读',
      ReadingBookStatusKind.completed => '读完',
    };
  }
}
