import '../../../../domain/entities/local_book.dart';
import 'local_book_parser.dart';
import 'local_markup_book_parser_support.dart';

class HtmlLocalBookParser implements LocalBookParser {
  const HtmlLocalBookParser({
    LocalMarkupBookParserSupport support = const LocalMarkupBookParserSupport(),
  }) : _support = support;

  final LocalMarkupBookParserSupport _support;

  @override
  bool supports(LocalBookFormat format) => format == LocalBookFormat.html;

  @override
  Future<LocalParsedBook> parse(LocalBook book) async {
    final html = await _support.decodeHtmlFile(book);
    return _support.parseHtmlBook(book: book, html: html, title: book.title);
  }
}
