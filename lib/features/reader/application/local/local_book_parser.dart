import '../../../../domain/entities/local_book.dart';
import '../../../../domain/entities/reader_document.dart';

enum LocalBookParserInputSource {
  nativeFilePath,
  webUploadedBytes,
  managedFile,
}

class LocalBookParserInput {
  const LocalBookParserInput({
    required this.book,
    required this.source,
    this.bytes,
    this.displayPath,
  });

  /// Native / managed 文件路径输入。
  ///
  /// 当前 TXT / EPUB / PDF / MOBI 等 parser 仍以 `LocalBook.storagePath` 为主，
  /// 这里先把“输入来自哪里”的语义集中起来。后续 Web 上传字节流、Native 文件路径、
  /// 受管文件恢复可以从这个 adapter 分流，而不用让每个 parser 自己判断平台。
  factory LocalBookParserInput.fromBook(LocalBook book) {
    final sourcePath = book.sourcePath?.trim() ?? '';
    final storagePath = book.storagePath.trim();
    return LocalBookParserInput(
      book: book,
      source:
          sourcePath.isEmpty || sourcePath == storagePath
              ? LocalBookParserInputSource.managedFile
              : LocalBookParserInputSource.nativeFilePath,
      displayPath: storagePath,
    );
  }

  final LocalBook book;
  final LocalBookParserInputSource source;
  final List<int>? bytes;
  final String? displayPath;

  bool get hasBytes => bytes != null;
  bool get usesPathBackedFile =>
      source == LocalBookParserInputSource.nativeFilePath ||
      source == LocalBookParserInputSource.managedFile;
}

class LocalParsedChapter {
  const LocalParsedChapter({
    required this.title,
    required this.content,
    this.imageUrls = const <String>[],
    this.sourceRef,
    this.contentType,
    this.startOffset,
    this.endOffset,
    this.document,
  });

  final String title;
  final String content;
  final List<String> imageUrls;
  final String? sourceRef;
  final String? contentType;
  final int? startOffset;
  final int? endOffset;
  final ReaderDocument? document;
}

class LocalParsedBook {
  const LocalParsedBook({
    required this.chapters,
    this.title,
    this.author,
    this.description,
    this.coverPath,
    this.charset,
  });

  final String? title;
  final String? author;
  final String? description;
  final String? coverPath;
  final String? charset;
  final List<LocalParsedChapter> chapters;
}

abstract class LocalBookParser {
  bool supports(LocalBookFormat format);

  Future<LocalParsedBook> parse(LocalBook book);
}

abstract class LocalBookParserInputAware {
  Future<LocalParsedBook> parseInput(LocalBookParserInput input) {
    throw UnimplementedError();
  }
}

Future<LocalParsedBook> parseLocalBookInput({
  required LocalBookParser parser,
  required LocalBookParserInput input,
}) {
  if (parser is LocalBookParserInputAware) {
    final inputAwareParser = parser as LocalBookParserInputAware;
    return inputAwareParser.parseInput(input);
  }
  return parser.parse(input.book);
}
