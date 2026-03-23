import '../../../../domain/entities/local_book.dart';

class LocalParsedChapter {
  const LocalParsedChapter({
    required this.title,
    required this.content,
    this.imageUrls = const <String>[],
    this.startOffset,
    this.endOffset,
  });

  final String title;
  final String content;
  final List<String> imageUrls;
  final int? startOffset;
  final int? endOffset;
}

class LocalParsedBook {
  const LocalParsedBook({
    required this.chapters,
    this.title,
    this.author,
    this.coverPath,
    this.charset,
  });

  final String? title;
  final String? author;
  final String? coverPath;
  final String? charset;
  final List<LocalParsedChapter> chapters;
}

abstract class LocalBookParser {
  bool supports(LocalBookFormat format);

  Future<LocalParsedBook> parse(LocalBook book);
}
