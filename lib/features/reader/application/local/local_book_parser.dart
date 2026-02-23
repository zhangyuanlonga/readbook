import '../../../../domain/entities/local_book.dart';

class LocalParsedChapter {
  const LocalParsedChapter({
    required this.title,
    required this.content,
    this.startOffset,
    this.endOffset,
  });

  final String title;
  final String content;
  final int? startOffset;
  final int? endOffset;
}

class LocalParsedBook {
  const LocalParsedBook({required this.chapters, this.title, this.author});

  final String? title;
  final String? author;
  final List<LocalParsedChapter> chapters;
}

abstract class LocalBookParser {
  bool supports(LocalBookFormat format);

  Future<LocalParsedBook> parse(LocalBook book);
}
