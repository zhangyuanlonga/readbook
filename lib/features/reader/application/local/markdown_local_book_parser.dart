import 'package:markdown/markdown.dart' as markdown;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_codes.dart';
import '../../../../core/errors/error_stage.dart';
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
    final frontMatter = _extractFrontMatter(markdownText);
    final html = markdown.markdownToHtml(
      frontMatter.content,
      extensionSet: markdown.ExtensionSet.gitHubWeb,
    );
    try {
      return await _support.parseHtmlBook(
        book: book,
        html: html,
        title: frontMatter.title ?? book.title,
        preferProvidedTitle: frontMatter.title != null,
        preferredAuthor: frontMatter.author,
        preferredDescription: frontMatter.description,
        preferredCoverSource: frontMatter.cover,
      );
    } on AppException catch (error) {
      if (error.code == ErrorCode.ruleMatchEmpty) {
        throw AppException(
          code: error.code,
          stage: ErrorStage.content,
          briefMessage: '本地 Markdown 未解析出可读内容。',
          cause: error,
        );
      }
      rethrow;
    }
  }

  _MarkdownFrontMatter _extractFrontMatter(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (!normalized.startsWith('---\n')) {
      return _MarkdownFrontMatter(content: normalized);
    }
    final end = normalized.indexOf('\n---\n', 4);
    if (end < 0) {
      return _MarkdownFrontMatter(content: normalized);
    }
    final header = normalized.substring(4, end);
    final content = normalized.substring(end + 5);
    final values = <String, String>{};
    for (final line in header.split('\n')) {
      final index = line.indexOf(':');
      if (index <= 0) {
        continue;
      }
      final key = line.substring(0, index).trim().toLowerCase();
      final rawValue = line.substring(index + 1).trim();
      final value = rawValue.replaceAll(RegExp("^['\"]|['\"]\$"), '');
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      values[key] = value;
    }
    return _MarkdownFrontMatter(
      content: content,
      title: values['title'],
      author: values['author'],
      description: values['description'],
      cover: values['cover'],
    );
  }
}

class _MarkdownFrontMatter {
  const _MarkdownFrontMatter({
    required this.content,
    this.title,
    this.author,
    this.description,
    this.cover,
  });

  final String content;
  final String? title;
  final String? author;
  final String? description;
  final String? cover;
}
