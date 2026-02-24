import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/rule_engine/rule_engine.dart';
import '../../../core/rule_engine/processors/legacy_link_post_processor.dart';
import '../../../core/rule_engine/processors/legacy_rule_compat.dart';
import '../../../core/rule_engine/processors/legacy_rule_variable_processor.dart';
import '../../../core/rule_engine/processors/legacy_xpath_compat.dart';
import '../../../core/rule_engine/processors/legacy_script_rule_fallback.dart';
import '../../../domain/entities/book.dart';

class SearchParseRules {
  const SearchParseRules({
    required this.listRule,
    required this.titleRule,
    required this.detailUrlRule,
    this.rawListRule,
    this.rawTitleRule,
    this.rawDetailUrlRule,
    this.authorRule,
    this.rawAuthorRule,
    this.introRule,
    this.rawIntroRule,
    this.coverUrlRule,
    this.rawCoverUrlRule,
    this.latestChapterRule,
    this.rawLatestChapterRule,
  });

  final String listRule;
  final String titleRule;
  final String detailUrlRule;
  final String? rawListRule;
  final String? rawTitleRule;
  final String? rawDetailUrlRule;
  final String? authorRule;
  final String? rawAuthorRule;
  final String? introRule;
  final String? rawIntroRule;
  final String? coverUrlRule;
  final String? rawCoverUrlRule;
  final String? latestChapterRule;
  final String? rawLatestChapterRule;
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

    final booksById = <String, Book>{};

    final listExpressions = _splitFallbackExpressions(rules.listRule);
    for (final listExpression in listExpressions) {
      final chunks = _executeAllSingleExpression(
        content: htmlContent,
        expression: listExpression,
        stage: ErrorStage.search,
        rawRule: rules.rawListRule,
      );
      if (chunks.isEmpty) {
        continue;
      }

      final parsedBooks = _parseBooksFromChunks(
        chunks: chunks,
        sourceId: sourceId,
        baseUri: baseUri,
        rules: rules,
      );
      for (final book in parsedBooks) {
        booksById[book.id] = book;
      }

      if (booksById.isNotEmpty) {
        break;
      }
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

  List<Book> _parseBooksFromChunks({
    required List<String> chunks,
    required String sourceId,
    required Uri baseUri,
    required SearchParseRules rules,
  }) {
    final output = <Book>[];

    for (final chunk in chunks) {
      final variableState = <String, String>{};

      final title = _tryRequired(
        content: chunk,
        expression: rules.titleRule,
        rawRule: rules.rawTitleRule,
        variables: variableState,
        fallbackExtractor: 'text',
      );
      final detailUrlRaw = _tryRequired(
        content: chunk,
        expression: rules.detailUrlRule,
        rawRule: rules.rawDetailUrlRule,
        variables: variableState,
        fallbackExtractor: 'attr(href)',
        preferredAttribute: 'href',
      );

      if (title == null || detailUrlRaw == null) {
        continue;
      }

      final detailUrlValue =
          rules.detailUrlRule == LegacyScriptRuleFallback.fieldExpression
              ? detailUrlRaw.trim()
              : LegacyLinkPostProcessor.apply(
                value: detailUrlRaw,
                rawRule: rules.rawDetailUrlRule,
              );
      if (detailUrlValue.trim().isEmpty) {
        continue;
      }

      final detailUrl = _resolveUrl(baseUri, detailUrlValue);
      final coverUrl = _tryOptional(
        content: chunk,
        expression: rules.coverUrlRule,
        rawRule: rules.rawCoverUrlRule,
        variables: variableState,
        fallbackExtractor: 'attr(src)',
        preferredAttribute: 'src',
      );

      output.add(
        Book(
          id: _buildBookId(sourceId: sourceId, detailUrl: detailUrl),
          sourceId: sourceId,
          title: title,
          detailUrl: detailUrl,
          author: _tryOptional(
            content: chunk,
            expression: rules.authorRule,
            rawRule: rules.rawAuthorRule,
            variables: variableState,
            fallbackExtractor: 'text',
          ),
          intro: _tryOptional(
            content: chunk,
            expression: rules.introRule,
            rawRule: rules.rawIntroRule,
            variables: variableState,
            fallbackExtractor: 'text',
          ),
          latestChapter: _tryOptional(
            content: chunk,
            expression: rules.latestChapterRule,
            rawRule: rules.rawLatestChapterRule,
            variables: variableState,
            fallbackExtractor: 'text',
          ),
          coverUrl: coverUrl == null ? null : _resolveUrl(baseUri, coverUrl),
        ),
      );
    }

    return output;
  }

  String? _tryRequired({
    required String content,
    required String expression,
    required Map<String, String> variables,
    required String fallbackExtractor,
    String? preferredAttribute,
    String? rawRule,
  }) {
    final variableAwareRaw =
        LegacyRuleVariableProcessor.containsVariableSyntax(rawRule)
            ? rawRule!.trim()
            : null;

    if (variableAwareRaw != null) {
      final resolvedRaw = LegacyRuleVariableProcessor.resolveExpression(
        expression: variableAwareRaw,
        variables: variables,
        resolvePutValue:
            (valueExpression) => _evaluatePutValue(
              content: content,
              valueExpression: valueExpression,
              fallbackExtractor: fallbackExtractor,
              preferredAttribute: preferredAttribute,
            ),
      );

      final variableRawResult = _executeRuleLikeExpression(
        content: content,
        expression: resolvedRaw,
        fallbackExtractor: fallbackExtractor,
        preferredAttribute: preferredAttribute,
        treatLiteralAsValue: true,
      );
      if (variableRawResult != null) {
        return variableRawResult;
      }
    }

    final variableAwareExpression =
        LegacyRuleVariableProcessor.replaceGetTokens(expression, variables);

    if (variableAwareExpression == LegacyScriptRuleFallback.fieldExpression) {
      return LegacyScriptRuleFallback.evaluateFieldValue(
        content: content,
        rawRule: rawRule,
      );
    }

    for (final candidate in _splitFallbackExpressions(
      variableAwareExpression,
    )) {
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

    return LegacyScriptRuleFallback.evaluateFieldValue(
      content: content,
      rawRule: rawRule,
    );
  }

  String? _tryOptional({
    required String content,
    required String? expression,
    required String fallbackExtractor,
    required Map<String, String> variables,
    String? preferredAttribute,
    String? rawRule,
  }) {
    if (expression == null || expression.trim().isEmpty) {
      final variableAwareRaw =
          LegacyRuleVariableProcessor.containsVariableSyntax(rawRule)
              ? rawRule!.trim()
              : null;

      if (variableAwareRaw == null) {
        return null;
      }

      return _tryRequired(
        content: content,
        expression: variableAwareRaw,
        rawRule: rawRule,
        variables: variables,
        fallbackExtractor: fallbackExtractor,
        preferredAttribute: preferredAttribute,
      );
    }

    return _tryRequired(
      content: content,
      expression: expression,
      rawRule: rawRule,
      variables: variables,
      fallbackExtractor: fallbackExtractor,
      preferredAttribute: preferredAttribute,
    );
  }

  String? _evaluatePutValue({
    required String content,
    required String valueExpression,
    required String fallbackExtractor,
    String? preferredAttribute,
  }) {
    final text = valueExpression.trim();
    if (text.isEmpty) {
      return null;
    }

    return _executeRuleLikeExpression(
      content: content,
      expression: text,
      fallbackExtractor: fallbackExtractor,
      preferredAttribute: preferredAttribute,
      treatLiteralAsValue: true,
    );
  }

  String? _executeRuleLikeExpression({
    required String content,
    required String expression,
    required String fallbackExtractor,
    String? preferredAttribute,
    bool treatLiteralAsValue = false,
  }) {
    final text = expression.trim();
    if (text.isEmpty) {
      return null;
    }

    if (treatLiteralAsValue && !_looksLikeRuleExpression(text)) {
      return text;
    }

    final normalizedExpression = _normalizeRuleExpression(
      text,
      fallbackExtractor: fallbackExtractor,
      preferredAttribute: preferredAttribute,
    );
    if (normalizedExpression == null || normalizedExpression.isEmpty) {
      if (treatLiteralAsValue && !_looksLikeRuleExpression(text)) {
        return text;
      }
      return null;
    }

    for (final candidate in _splitFallbackExpressions(normalizedExpression)) {
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

  String? _normalizeRuleExpression(
    String expression, {
    required String fallbackExtractor,
    String? preferredAttribute,
  }) {
    final text = expression.trim();
    if (text.isEmpty) {
      return null;
    }

    final staticRule = LegacyRuleCompat.extractStaticRuleExpression(text);
    if (staticRule == null || staticRule.isEmpty) {
      return null;
    }

    if (staticRule.startsWith('html:') ||
        staticRule.startsWith('json:') ||
        staticRule.startsWith('regex:')) {
      return staticRule;
    }

    final xpathCandidate = LegacyXPathCompat.buildRuleExpression(
      expression: staticRule,
      fallbackExtractor: fallbackExtractor,
      preferredAttribute: preferredAttribute,
    );
    if (xpathCandidate != null) {
      return xpathCandidate;
    }

    if (staticRule.startsWith('@json:')) {
      final candidate = staticRule.substring(6).trim();
      if (candidate.isNotEmpty) {
        return 'json:$candidate';
      }
    }

    if (staticRule.startsWith(r'$.') ||
        staticRule.startsWith(r'$[') ||
        staticRule == r'$') {
      return 'json:$staticRule';
    }

    final htmlCandidate = LegacyRuleCompat.buildHtmlRuleExpression(
      expression: staticRule,
      fallbackExtractor: fallbackExtractor,
      preferredAttribute: preferredAttribute,
    );

    return htmlCandidate;
  }

  bool _looksLikeRuleExpression(String expression) {
    final text = expression.trim();
    if (text.isEmpty) {
      return false;
    }

    if (text.startsWith('html:') ||
        text.startsWith('json:') ||
        text.startsWith('regex:') ||
        text.startsWith('js:') ||
        text.startsWith('@js:') ||
        text.startsWith(r'$.') ||
        text.startsWith(r'$[') ||
        text.startsWith('@json:')) {
      return true;
    }

    if (text.contains('@') ||
        text.contains('##') ||
        text.contains('||') ||
        text.contains('&&')) {
      return true;
    }

    return false;
  }

  List<String> _executeAllSingleExpression({
    required String content,
    required String expression,
    required ErrorStage stage,
    String? rawRule,
  }) {
    if (expression == LegacyScriptRuleFallback.listExpression) {
      return LegacyScriptRuleFallback.evaluateListChunks(
        content: content,
        rawRule: rawRule,
      );
    }

    try {
      return _ruleEngine.executeAll(
        content: content,
        expression: expression,
        stage: stage,
      );
    } on AppException {
      return const [];
    }
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
