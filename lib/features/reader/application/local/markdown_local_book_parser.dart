import 'package:markdown/markdown.dart' as markdown;

import '../../../../domain/entities/local_book.dart';
import 'local_book_parser.dart';
import 'local_markup_book_parser_support.dart';

class MarkdownLocalBookParser implements LocalBookParser {
  const MarkdownLocalBookParser({
    LocalMarkupBookParserSupport support = const LocalMarkupBookParserSupport(),
  }) : _support = support;

  final LocalMarkupBookParserSupport _support;

  @override
  bool supports(LocalBookFormat format) => format == LocalBookFormat.md;

  @override
  Future<LocalParsedBook> parse(LocalBook book) async {
    final markdownText = await _support.decodeTextFile(book);
    final html = markdown.markdownToHtml(
      markdownText,
      extensionSet: markdown.ExtensionSet.gitHubWeb,
    );
    return _support.parseHtmlBook(book: book, html: html, title: book.title);
  }
}
