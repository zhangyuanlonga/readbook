import '../../../../domain/entities/local_book.dart';
import '../../../../domain/entities/reader_document.dart';

class LocalParsedChapter {
  const LocalParsedChapter({
    required this.title,
    required this.content,
    this.imageUrls = const <String>[],
    this.sourceRef,
    this.startOffset,
    this.endOffset,
    this.document,
  });

  final String title;
  final String content;
  final List<String> imageUrls;
  final String? sourceRef;
  final int? startOffset;
  final int? endOffset;
  final ReaderDocument? document;
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
