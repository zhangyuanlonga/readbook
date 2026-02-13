import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/rule_engine/rule_engine.dart';
import '../../../domain/entities/book.dart';

class SearchParseRules {
  const SearchParseRules({
    required this.listRule,
    required this.titleRule,
    required this.detailUrlRule,
    this.authorRule,
    this.introRule,
    this.coverUrlRule,
    this.latestChapterRule,
  });

  final String listRule;
  final String titleRule;
  final String detailUrlRule;
  final String? authorRule;
  final String? introRule;
  final String? coverUrlRule;
  final String? latestChapterRule;
}

class SearchResultParser {
  SearchResultParser({RuleEngine? ruleEngine})
    : _ruleEngine = ruleEngine ?? RuleEngine();

  final RuleEngine _ruleEngine;

  List<Book> parse({
    required String htmlContent,
    required String sourceId,
    required String baseUrl,
    required SearchParseRules rules,
  }) {
    if (sourceId.trim().isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        briefMessage: 'sourceId 不能为空。',
      );
    }

    final baseUri = Uri.tryParse(baseUrl.trim());
    if (baseUri == null || !baseUri.hasScheme) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        briefMessage: 'baseUrl 非法：$baseUrl',
      );
    }

    final chunks = _executeAllWithFallback(
      content: htmlContent,
      expression: rules.listRule,
      stage: ErrorStage.search,
    );

    final booksById = <String, Book>{};

    for (final chunk in chunks) {
      final title = _tryRequired(content: chunk, expression: rules.titleRule);
      final detailUrlRaw = _tryRequired(
        content: chunk,
        expression: rules.detailUrlRule,
      );

      if (title == null || detailUrlRaw == null) {
        continue;
      }

      final detailUrl = _resolveUrl(baseUri, detailUrlRaw);
      final coverUrl = _tryOptional(
        content: chunk,
        expression: rules.coverUrlRule,
      );

      final book = Book(
        id: _buildBookId(sourceId: sourceId, detailUrl: detailUrl),
        sourceId: sourceId,
        title: title,
        detailUrl: detailUrl,
        author: _tryOptional(content: chunk, expression: rules.authorRule),
        intro: _tryOptional(content: chunk, expression: rules.introRule),
        latestChapter: _tryOptional(
          content: chunk,
          expression: rules.latestChapterRule,
        ),
        coverUrl: coverUrl == null ? null : _resolveUrl(baseUri, coverUrl),
      );

      booksById[book.id] = book;
    }

    if (booksById.isEmpty) {
      throw RuleMatchEmptyException(
        briefMessage: '搜索结果解析为空，请检查规则是否正确。',
        sourceId: sourceId,
        stage: ErrorStage.search,
      );
    }

    return booksById.values.toList(growable: false);
  }

  String? _tryRequired({required String content, required String expression}) {
    for (final candidate in _splitFallbackExpressions(expression)) {
      try {
        final value = _ruleEngine.executeFirst(
          content: content,
          expression: candidate,
          stage: ErrorStage.search,
        );
        final normalized = value.trim();
        if (normalized.isNotEmpty) {
          return normalized;
        }
      } on AppException {
        continue;
      }
    }

    return null;
  }

  String? _tryOptional({required String content, String? expression}) {
    if (expression == null || expression.trim().isEmpty) {
      return null;
    }

    return _tryRequired(content: content, expression: expression);
  }

  List<String> _executeAllWithFallback({
    required String content,
    required String expression,
    required ErrorStage stage,
  }) {
    for (final candidate in _splitFallbackExpressions(expression)) {
      try {
        final values = _ruleEngine.executeAll(
          content: content,
          expression: candidate,
          stage: stage,
        );
        if (values.isNotEmpty) {
          return values;
        }
      } on AppException {
        continue;
      }
    }

    return const [];
  }

  List<String> _splitFallbackExpressions(String expression) {
    return expression
        .split('||')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _resolveUrl(Uri baseUri, String url) {
    final trimmed = url.trim();
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      return trimmed;
    }
    return baseUri.resolve(trimmed).toString();
  }

  String _buildBookId({required String sourceId, required String detailUrl}) {
    final seed = '$sourceId|$detailUrl';
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    final hashText = hash.toRadixString(16).padLeft(8, '0');
    return 'book_$hashText';
  }
}
