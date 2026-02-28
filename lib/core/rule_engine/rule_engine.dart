import 'dart:convert';

import '../errors/app_exception.dart';
import '../errors/error_stage.dart';
import '../logging/app_logger.dart';
import 'executors/html_executor.dart';
import 'executors/js_executor.dart';
import 'executors/json_executor.dart';
import 'executors/regex_executor.dart';
import 'executors/xpath_executor.dart';
import 'processors/legacy_rule_compat.dart';
import 'processors/legacy_script_rule_fallback.dart';
import 'processors/legacy_xpath_compat.dart';
import 'rule_parser.dart';

class RuleEngine {
  RuleEngine({
    RuleParser? parser,
    HtmlExecutor? htmlExecutor,
    RegexExecutor? regexExecutor,
    JsonExecutor? jsonExecutor,
    JsExecutor? jsExecutor,
    XPathExecutor? xpathExecutor,
    AppLogger? logger,
  }) : _parser = parser ?? const RuleParser(),
       _htmlExecutor = htmlExecutor ?? const HtmlExecutor(),
       _regexExecutor = regexExecutor ?? const RegexExecutor(),
       _jsonExecutor = jsonExecutor ?? const JsonExecutor(),
       _jsExecutor = jsExecutor ?? JsExecutor(),
       _xpathExecutor =
           xpathExecutor ??
           XPathExecutor(htmlExecutor: htmlExecutor ?? const HtmlExecutor()),
       _logger = logger ?? AppLogger.instance;

  final RuleParser _parser;
  final HtmlExecutor _htmlExecutor;
  final RegexExecutor _regexExecutor;
  final JsonExecutor _jsonExecutor;
  final JsExecutor _jsExecutor;
  final XPathExecutor _xpathExecutor;
  final AppLogger _logger;
  static const int _maxTemplateResolveDepth = 4;
  static final RegExp _inlineJsPattern = RegExp(
    r'^(.*?)<js>([\s\S]*?)</js>(.*)$',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _templateTokenPattern = RegExp(
    r'\{\{\s*([\s\S]*?)\s*\}\}',
    dotAll: true,
  );
  static const String _allInOnePayloadPrefix = '__appread_all_in_one__:';

  Future<List<String>> executeAll({
    required String content,
    required String expression,
    ErrorStage stage = ErrorStage.search,
    JsExecutionContext? jsContext,
    int templateDepth = 0,
  }) async {
    final trimmedExpression = expression.trim();
    if (trimmedExpression.isEmpty) {
      return const [];
    }

    final templateResolved = await _resolveNestedRuleTemplates(
      content: content,
      expression: trimmedExpression,
      stage: stage,
      jsContext: jsContext,
      templateDepth: templateDepth,
    );
    final resolvedExpression = templateResolved.expression.trim();
    if (resolvedExpression.isEmpty) {
      return const [];
    }

    final logicalValues = await _tryExecuteLogicalOperators(
      content: content,
      expression: resolvedExpression,
      stage: stage,
      jsContext: jsContext,
      templateDepth: templateDepth,
    );
    if (logicalValues != null) {
      return logicalValues;
    }

    final interleavedValues = await _tryExecuteInterleaveOperator(
      content: content,
      expression: resolvedExpression,
      stage: stage,
      jsContext: jsContext,
      templateDepth: templateDepth,
    );
    if (interleavedValues != null) {
      return interleavedValues;
    }

    final inlineJsValues = await _tryExecuteInlineJsPipeline(
      content: content,
      expression: resolvedExpression,
      stage: stage,
      jsContext: jsContext,
      templateDepth: templateDepth,
    );
    if (inlineJsValues != null) {
      return inlineJsValues;
    }

    late final ParsedRule parsed;
    try {
      parsed = _parser.parse(resolvedExpression);
    } on AppException {
      if (!templateResolved.replacedAny) {
        rethrow;
      }

      final literal = resolvedExpression.trim();
      if (literal.isEmpty) {
        return const [];
      }
      return <String>[literal];
    }
    if (parsed is ParsedHtmlRule) {
      return _htmlExecutor.execute(
        content: content,
        rule: parsed,
        stage: stage,
      );
    }

    if (parsed is ParsedRegexRule) {
      return _regexExecutor.execute(
        content: content,
        rule: parsed,
        stage: stage,
      );
    }

    if (parsed is ParsedAllInOneRegexRule) {
      return _executeAllInOneRegex(
        content: content,
        parsed: parsed,
        stage: stage,
      );
    }

    if (parsed is ParsedJsonRule) {
      return _jsonExecutor.execute(
        content: content,
        rule: parsed,
        stage: stage,
      );
    }

    if (parsed is ParsedXPathRule) {
      return _xpathExecutor.execute(
        content: content,
        rule: parsed,
        stage: stage,
      );
    }

    if (parsed is ParsedJsRule) {
      return _executeParsedJsRule(
        content: content,
        parsed: parsed,
        stage: stage,
        jsContext: jsContext,
        templateDepth: templateDepth,
      );
    }

    if (parsed is ParsedRegexGroupReferenceRule) {
      return _executeRegexGroupReference(
        content: content,
        parsed: parsed,
        stage: stage,
      );
    }

    return const [];
  }

  Future<List<String>?> _tryExecuteLogicalOperators({
    required String content,
    required String expression,
    required ErrorStage stage,
    JsExecutionContext? jsContext,
    int templateDepth = 0,
  }) async {
    final orGroups = _splitByOperatorPreservingBlocks(
      expression: expression,
      operator: '||',
    );
    if (orGroups.length > 1) {
      for (final group in orGroups) {
        List<String> values;
        try {
          values = await executeAll(
            content: content,
            expression: group,
            stage: stage,
            jsContext: jsContext,
            templateDepth: templateDepth,
          );
        } on AppException {
          values = const <String>[];
        }
        if (values.isNotEmpty) {
          return values;
        }
      }
      return const <String>[];
    }

    final andSegments = _splitByOperatorPreservingBlocks(
      expression: expression,
      operator: '&&',
    );
    if (andSegments.length > 1) {
      final merged = <String>[];
      for (final segment in andSegments) {
        List<String> values;
        try {
          values = await executeAll(
            content: content,
            expression: segment,
            stage: stage,
            jsContext: jsContext,
            templateDepth: templateDepth,
          );
        } on AppException {
          values = const <String>[];
        }
        if (values.isNotEmpty) {
          merged.addAll(values);
        }
      }
      return merged;
    }
    return null;
  }

  List<String> _executeAllInOneRegex({
    required String content,
    required ParsedAllInOneRegexRule parsed,
    required ErrorStage stage,
  }) {
    final pattern = parsed.pattern.trim();
    if (pattern.isEmpty) {
      throw RuleMatchEmptyException(
        briefMessage: 'AllInOne Regex 规则未命中：$pattern',
        stage: stage,
      );
    }

    final regex = RegExp(
      pattern,
      caseSensitive: parsed.caseSensitive,
      multiLine: parsed.multiLine,
      dotAll: parsed.dotAll,
    );
    final matches = regex.allMatches(content).toList(growable: false);
    if (matches.isEmpty) {
      throw RuleMatchEmptyException(
        briefMessage: 'AllInOne Regex 规则未命中：$pattern',
        stage: stage,
      );
    }

    return matches
        .map((match) {
          final groups = List<String>.generate(
            match.groupCount + 1,
            (index) => match.group(index) ?? '',
            growable: false,
          );
          return '$_allInOnePayloadPrefix${jsonEncode(groups)}';
        })
        .toList(growable: false);
  }

  List<String> _executeRegexGroupReference({
    required String content,
    required ParsedRegexGroupReferenceRule parsed,
    required ErrorStage stage,
  }) {
    final groups = _decodeAllInOnePayload(content);
    if (groups == null || parsed.group >= groups.length) {
      throw RuleMatchEmptyException(
        briefMessage: 'Regex 分组引用未命中：\$${parsed.group}',
        stage: stage,
      );
    }

    final value = groups[parsed.group].trim();
    if (value.isEmpty) {
      throw RuleMatchEmptyException(
        briefMessage: 'Regex 分组引用结果为空：\$${parsed.group}',
        stage: stage,
      );
    }
    return <String>[value];
  }

  List<String>? _decodeAllInOnePayload(String content) {
    final normalized = content.trim();
    if (!normalized.startsWith(_allInOnePayloadPrefix)) {
      return null;
    }

    final raw = normalized.substring(_allInOnePayloadPrefix.length).trim();
    if (raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return null;
      }
      return decoded
          .map((item) => item?.toString() ?? '')
          .toList(growable: false);
    } on FormatException {
      return null;
    }
  }

  Future<String> executeFirst({
    required String content,
    required String expression,
    ErrorStage stage = ErrorStage.search,
    JsExecutionContext? jsContext,
    int templateDepth = 0,
  }) async {
    final values = await executeAll(
      content: content,
      expression: expression,
      stage: stage,
      jsContext: jsContext,
      templateDepth: templateDepth,
    );

    return values.first;
  }

  Future<List<String>> _executeParsedJsRule({
    required String content,
    required ParsedJsRule parsed,
    required ErrorStage stage,
    JsExecutionContext? jsContext,
    int templateDepth = 0,
  }) async {
    final precedingRule = parsed.precedingRule?.trim();
    final inputs =
        precedingRule == null || precedingRule.isEmpty
            ? <String>[content]
            : await executeAll(
              content: content,
              expression: precedingRule,
              stage: stage,
              jsContext: jsContext,
              templateDepth: templateDepth,
            );

    if (inputs.isEmpty) {
      return const [];
    }

    final values = <String>[];
    for (final item in inputs) {
      final resolved = await _executeJsWithFallback(
        input: item,
        script: parsed.script,
        stage: stage,
        jsContext: jsContext,
      );
      if (resolved != null && resolved.trim().isNotEmpty) {
        values.add(resolved);
      }
    }

    return values;
  }

  Future<List<String>?> _tryExecuteInlineJsPipeline({
    required String content,
    required String expression,
    required ErrorStage stage,
    JsExecutionContext? jsContext,
    int templateDepth = 0,
  }) async {
    if (expression.startsWith('json:')) {
      return null;
    }

    final match = _inlineJsPattern.firstMatch(expression);
    if (match == null) {
      return null;
    }

    final beforeSegment = match.group(1)?.trim() ?? '';
    final scriptSegment = match.group(2)?.trim() ?? '';
    final afterSegment = match.group(3)?.trim() ?? '';

    if (scriptSegment.isEmpty) {
      return const [];
    }

    final inputs =
        beforeSegment.isEmpty
            ? <String>[content]
            : await executeAll(
              content: content,
              expression: beforeSegment,
              stage: stage,
              jsContext: jsContext,
              templateDepth: templateDepth,
            );
    if (inputs.isEmpty) {
      return const [];
    }

    final transformed = <String>[];
    for (final item in inputs) {
      final resolved = await _executeJsWithFallback(
        input: item,
        script: scriptSegment,
        stage: stage,
        jsContext: jsContext,
      );
      if (resolved != null && resolved.trim().isNotEmpty) {
        transformed.add(resolved);
      }
    }

    if (afterSegment.isEmpty || transformed.isEmpty) {
      return transformed;
    }

    final output = <String>[];
    for (final item in transformed) {
      output.addAll(
        await executeAll(
          content: item,
          expression: afterSegment,
          stage: stage,
          jsContext: jsContext,
          templateDepth: templateDepth,
        ),
      );
    }
    return output;
  }

  Future<List<String>?> _tryExecuteInterleaveOperator({
    required String content,
    required String expression,
    required ErrorStage stage,
    JsExecutionContext? jsContext,
    int templateDepth = 0,
  }) async {
    final segments = _splitByOperatorPreservingBlocks(
      expression: expression,
      operator: '%%',
    );
    if (segments.length <= 1) {
      return null;
    }

    final groupedValues = <List<String>>[];
    for (final segment in segments) {
      List<String> values;
      try {
        values = await executeAll(
          content: content,
          expression: segment,
          stage: stage,
          jsContext: jsContext,
          templateDepth: templateDepth,
        );
      } on AppException {
        values = const <String>[];
      }
      groupedValues.add(values);
    }

    return _interleaveRoundRobin(groupedValues);
  }

  List<String> _interleaveRoundRobin(List<List<String>> source) {
    if (source.isEmpty) {
      return const [];
    }

    final maxLength = source
        .map((items) => items.length)
        .fold<int>(
          0,
          (maxValue, current) => current > maxValue ? current : maxValue,
        );
    if (maxLength == 0) {
      return const [];
    }

    final output = <String>[];
    for (var index = 0; index < maxLength; index += 1) {
      for (final values in source) {
        if (index < values.length) {
          output.add(values[index]);
        }
      }
    }
    return output;
  }

  List<String> _splitByOperatorPreservingBlocks({
    required String expression,
    required String operator,
  }) {
    final normalized = expression.trim();
    if (normalized.isEmpty || operator.isEmpty) {
      return const [];
    }

    final lower = normalized.toLowerCase();
    final output = <String>[];
    var cursor = 0;
    var segmentStart = 0;
    var jsDepth = 0;
    var templateDepth = 0;
    var inString = false;
    var quote = '';
    var escaped = false;
    final opLength = operator.length;

    while (cursor < normalized.length) {
      final currentChar = normalized[cursor];

      if (inString) {
        if (escaped) {
          escaped = false;
          cursor += 1;
          continue;
        }
        if (currentChar == r'\') {
          escaped = true;
          cursor += 1;
          continue;
        }
        if (currentChar == quote) {
          inString = false;
          quote = '';
        }
        cursor += 1;
        continue;
      }

      if (currentChar == '"' || currentChar == "'" || currentChar == '`') {
        inString = true;
        quote = currentChar;
        cursor += 1;
        continue;
      }

      if (lower.startsWith('<js>', cursor)) {
        jsDepth += 1;
        cursor += 4;
        continue;
      }
      if (lower.startsWith('</js>', cursor)) {
        if (jsDepth > 0) {
          jsDepth -= 1;
        }
        cursor += 5;
        continue;
      }
      if (normalized.startsWith('{{', cursor)) {
        templateDepth += 1;
        cursor += 2;
        continue;
      }
      if (normalized.startsWith('}}', cursor)) {
        if (templateDepth > 0) {
          templateDepth -= 1;
        }
        cursor += 2;
        continue;
      }

      final canSplit = jsDepth == 0 && templateDepth == 0;
      if (canSplit && normalized.startsWith(operator, cursor)) {
        final segment = normalized.substring(segmentStart, cursor).trim();
        if (segment.isNotEmpty) {
          output.add(segment);
        }
        cursor += opLength;
        segmentStart = cursor;
        continue;
      }

      cursor += 1;
    }

    final tail = normalized.substring(segmentStart).trim();
    if (tail.isNotEmpty) {
      output.add(tail);
    }

    if (output.isEmpty) {
      return <String>[normalized];
    }
    return output;
  }

  Future<_TemplateResolveResult> _resolveNestedRuleTemplates({
    required String content,
    required String expression,
    required ErrorStage stage,
    JsExecutionContext? jsContext,
    int templateDepth = 0,
  }) async {
    if (templateDepth >= _maxTemplateResolveDepth ||
        !expression.contains('{{') ||
        !expression.contains('}}')) {
      return _TemplateResolveResult(expression: expression, replacedAny: false);
    }

    final matches = _templateTokenPattern
        .allMatches(expression)
        .toList(growable: false);
    if (matches.isEmpty) {
      return _TemplateResolveResult(expression: expression, replacedAny: false);
    }

    final buffer = StringBuffer();
    var cursor = 0;
    var replacedAny = false;

    for (final match in matches) {
      buffer.write(expression.substring(cursor, match.start));
      cursor = match.end;

      final rawMatch = match.group(0) ?? '';
      final token = match.group(1)?.trim() ?? '';
      final replacement = await _resolveNestedTemplateToken(
        content: content,
        token: token,
        stage: stage,
        jsContext: jsContext,
        templateDepth: templateDepth,
      );
      if (replacement == null) {
        buffer.write(rawMatch);
        continue;
      }

      replacedAny = true;
      buffer.write(replacement);
    }

    buffer.write(expression.substring(cursor));
    return _TemplateResolveResult(
      expression: buffer.toString(),
      replacedAny: replacedAny,
    );
  }

  Future<String?> _resolveNestedTemplateToken({
    required String content,
    required String token,
    required ErrorStage stage,
    JsExecutionContext? jsContext,
    int templateDepth = 0,
  }) async {
    final nestedExpression = _normalizeNestedTemplateRule(token);
    if (nestedExpression == null || nestedExpression.isEmpty) {
      return null;
    }

    List<String> values;
    try {
      values = await executeAll(
        content: content,
        expression: nestedExpression,
        stage: stage,
        jsContext: jsContext,
        templateDepth: templateDepth + 1,
      );
    } on AppException {
      return '';
    }
    if (values.isEmpty) {
      return '';
    }
    return values.first.trim();
  }

  String? _normalizeNestedTemplateRule(String token) {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      return null;
    }

    String candidate;
    if (normalized.startsWith('@@')) {
      candidate = normalized.substring(2).trim();
      if (candidate.isEmpty) {
        return '';
      }
    } else if (normalized.startsWith('@css:')) {
      candidate = normalized.substring(5).trim();
      if (candidate.isEmpty) {
        return '';
      }
      return LegacyRuleCompat.buildHtmlRuleExpression(
        expression: candidate,
        fallbackExtractor: 'text',
      );
    } else if (normalized.startsWith('@json:')) {
      candidate = normalized.substring(6).trim();
      if (candidate.isEmpty) {
        return '';
      }
      return 'json:$candidate';
    } else if (normalized.startsWith('@xpath:')) {
      candidate = normalized.substring(7).trim();
      if (candidate.isEmpty) {
        return '';
      }
      return 'xpath:$candidate';
    } else if (normalized.startsWith('@js:') || normalized.startsWith('js:')) {
      return normalized;
    } else {
      return null;
    }

    if (candidate.startsWith('html:') ||
        candidate.startsWith('regex:') ||
        candidate.startsWith('json:') ||
        candidate.startsWith('xpath:') ||
        candidate.startsWith('@xpath:') ||
        candidate.startsWith('js:') ||
        candidate.startsWith('@js:')) {
      return candidate;
    }

    if (candidate.startsWith('@json:')) {
      final text = candidate.substring(6).trim();
      return text.isEmpty ? null : 'json:$text';
    }

    if (candidate.startsWith(r'$.') ||
        candidate.startsWith(r'$[') ||
        candidate == r'$') {
      return 'json:$candidate';
    }

    final xpathCandidate = LegacyXPathCompat.buildNativeRuleExpression(
      expression: candidate,
      fallbackExtractor: 'text',
    );
    if (xpathCandidate != null && xpathCandidate.trim().isNotEmpty) {
      return xpathCandidate;
    }

    return LegacyRuleCompat.buildHtmlRuleExpression(
      expression: candidate,
      fallbackExtractor: 'text',
    );
  }

  Future<String?> _executeJsWithFallback({
    required String input,
    required String script,
    required ErrorStage stage,
    JsExecutionContext? jsContext,
  }) async {
    final context = (jsContext ?? const JsExecutionContext()).copyWith(
      result: input,
      stage: stage,
    );
    final jsResult = await _jsExecutor.execute(
      script: script,
      context: context,
    );
    final normalizedJsResult = jsResult?.trim();
    final unresolvedTemplate =
        normalizedJsResult != null &&
        normalizedJsResult.isNotEmpty &&
        _looksLikeUnresolvedLegacyTemplate(normalizedJsResult);
    if (jsResult != null && jsResult.trim().isNotEmpty) {
      if (!unresolvedTemplate) {
        return normalizedJsResult;
      }
    }

    final fallback = LegacyScriptRuleFallback.evaluateFieldValue(
      content: input,
      rawRule: '@js:$script',
    );
    if (fallback != null && fallback.trim().isNotEmpty) {
      final fallbackReason =
          unresolvedTemplate ? 'js_unresolved_template' : 'js_empty_result';
      _logger.warn(
        'RuleEngine JS fallback used',
        context: <String, Object?>{
          'sourceId': context.sourceId,
          'stage': stage.name,
          'fallbackReason': fallbackReason,
          'diagnostic': 'js_fallback_legacy',
        },
      );
      return fallback;
    }

    _logger.warn(
      'RuleEngine JS returned empty value',
      context: <String, Object?>{
        'sourceId': context.sourceId,
        'stage': stage.name,
        'fallbackReason':
            unresolvedTemplate ? 'js_unresolved_template' : 'js_empty_result',
        'diagnostic': 'js_empty_result',
      },
    );
    return null;
  }

  bool _looksLikeUnresolvedLegacyTemplate(String value) {
    return value.contains('{{') &&
        value.contains('}}') &&
        (value.contains(r'$.') || value.contains(r'$['));
  }
}

class _TemplateResolveResult {
  const _TemplateResolveResult({
    required this.expression,
    required this.replacedAny,
  });

  final String expression;
  final bool replacedAny;
}
