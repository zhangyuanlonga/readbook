import '../errors/app_exception.dart';
import '../errors/error_codes.dart';
import '../errors/error_stage.dart';
import 'processors/legacy_xpath_compat.dart';

sealed class ParsedRule {
  const ParsedRule();
}

class ParsedHtmlRule extends ParsedRule {
  const ParsedHtmlRule({required this.selector, required this.extractor});

  final String selector;
  final HtmlExtractor extractor;
}

class ParsedRegexRule extends ParsedRule {
  const ParsedRegexRule({
    required this.pattern,
    required this.group,
    required this.caseSensitive,
    required this.multiLine,
    required this.dotAll,
  });

  final String pattern;
  final int group;
  final bool caseSensitive;
  final bool multiLine;
  final bool dotAll;
}

class ParsedAllInOneRegexRule extends ParsedRule {
  const ParsedAllInOneRegexRule({
    required this.pattern,
    required this.caseSensitive,
    required this.multiLine,
    required this.dotAll,
  });

  final String pattern;
  final bool caseSensitive;
  final bool multiLine;
  final bool dotAll;
}

class ParsedRegexGroupReferenceRule extends ParsedRule {
  const ParsedRegexGroupReferenceRule({required this.group});

  final int group;
}

class ParsedJsonRule extends ParsedRule {
  const ParsedJsonRule({required this.expression});

  final String expression;
}

class ParsedJsRule extends ParsedRule {
  const ParsedJsRule({required this.script, this.precedingRule});

  final String script;
  final String? precedingRule;
}

class ParsedXPathRule extends ParsedRule {
  const ParsedXPathRule({required this.expression, required this.extractor});

  final String expression;
  final HtmlExtractor extractor;
}

enum HtmlExtractorType { text, html, outerHtml, attr }

class HtmlExtractor {
  const HtmlExtractor.text()
    : type = HtmlExtractorType.text,
      attributeName = null;

  const HtmlExtractor.html()
    : type = HtmlExtractorType.html,
      attributeName = null;

  const HtmlExtractor.outerHtml()
    : type = HtmlExtractorType.outerHtml,
      attributeName = null;

  const HtmlExtractor.attr(this.attributeName) : type = HtmlExtractorType.attr;

  final HtmlExtractorType type;
  final String? attributeName;
}

class RuleParser {
  const RuleParser();

  ParsedRule parse(String expression) {
    final text = expression.trim();
    if (text.isEmpty) {
      throw _parseError('规则不能为空。');
    }

    final directScript = _extractDirectScript(text);
    if (directScript != null) {
      return ParsedJsRule(script: directScript);
    }

    final jsMarkerIndex = _indexOfJsMarker(text);
    if (jsMarkerIndex > 0) {
      final precedingRule = text.substring(0, jsMarkerIndex).trim();
      final script = text.substring(jsMarkerIndex + 4).trim();
      if (script.isEmpty) {
        throw _parseError('JS 规则不能为空。');
      }
      return ParsedJsRule(
        script: script,
        precedingRule: precedingRule.isEmpty ? null : precedingRule,
      );
    }

    if (_isAllInOneRegexRule(text)) {
      return _parseAllInOneRegexRule(text.substring(1));
    }

    if (text.startsWith('html:')) {
      return _parseHtmlRule(text.substring(5));
    }

    if (text.startsWith('regex:')) {
      return _parseRegexRule(text.substring(6));
    }

    if (text.startsWith('json:')) {
      return _parseJsonRule(text.substring(5));
    }

    if (text.startsWith('xpath:')) {
      return _parseXPathRule(text.substring(6));
    }

    if (text.startsWith('@xpath:')) {
      return _parseXPathRule(text.substring(7));
    }

    if (LegacyXPathCompat.looksLikeXPathExpression(text)) {
      return _parseXPathRule(text);
    }

    if (_isRegexGroupReference(text)) {
      return _parseRegexGroupReferenceRule(text);
    }

    throw _parseError('规则前缀不支持，仅支持 html:、regex:、json:、xpath: 或 js:');
  }

  ParsedHtmlRule _parseHtmlRule(String source) {
    final text = source.trim();
    if (text.isEmpty) {
      throw _parseError('HTML 规则不能为空。');
    }

    final delimiterIndex = text.lastIndexOf('@');
    if (delimiterIndex < 0) {
      return ParsedHtmlRule(
        selector: text,
        extractor: const HtmlExtractor.text(),
      );
    }

    final selector = text.substring(0, delimiterIndex).trim();
    final extractorText = text.substring(delimiterIndex + 1).trim();
    if (selector.isEmpty) {
      throw _parseError('HTML 规则 selector 不能为空。');
    }

    if (extractorText.isEmpty || extractorText == 'text') {
      return ParsedHtmlRule(
        selector: selector,
        extractor: const HtmlExtractor.text(),
      );
    }

    if (extractorText == 'html' || extractorText == 'innerhtml') {
      return ParsedHtmlRule(
        selector: selector,
        extractor: const HtmlExtractor.html(),
      );
    }

    if (extractorText == 'outerhtml') {
      return ParsedHtmlRule(
        selector: selector,
        extractor: const HtmlExtractor.outerHtml(),
      );
    }

    if (extractorText.startsWith('attr(') && extractorText.endsWith(')')) {
      final attribute =
          extractorText.substring(5, extractorText.length - 1).trim();
      if (attribute.isEmpty) {
        throw _parseError('HTML attr() 属性名不能为空。');
      }

      return ParsedHtmlRule(
        selector: selector,
        extractor: HtmlExtractor.attr(attribute),
      );
    }

    throw _parseError('HTML 提取器不支持：$extractorText');
  }

  ParsedRegexRule _parseRegexRule(String source) {
    final text = source.trim();
    if (text.isEmpty) {
      throw _parseError('Regex 规则不能为空。');
    }

    final segments = text.split('::');
    final pattern = segments.first.trim();
    if (pattern.isEmpty) {
      throw _parseError('Regex pattern 不能为空。');
    }

    var group = 0;
    var caseSensitive = true;
    var multiLine = false;
    var dotAll = false;

    for (final segment in segments.skip(1)) {
      final item = segment.trim();
      if (item.isEmpty) {
        continue;
      }

      final separator = item.indexOf('=');
      if (separator <= 0 || separator >= item.length - 1) {
        throw _parseError('Regex 参数格式错误：$item');
      }

      final key = item.substring(0, separator).trim();
      final value = item.substring(separator + 1).trim();

      switch (key) {
        case 'group':
          final parsed = int.tryParse(value);
          if (parsed == null || parsed < 0) {
            throw _parseError('Regex group 必须是大于等于 0 的整数。');
          }
          group = parsed;
          break;
        case 'flags':
          caseSensitive = !value.contains('i');
          multiLine = value.contains('m');
          dotAll = value.contains('s');
          break;
        default:
          throw _parseError('Regex 参数不支持：$key');
      }
    }

    return ParsedRegexRule(
      pattern: pattern,
      group: group,
      caseSensitive: caseSensitive,
      multiLine: multiLine,
      dotAll: dotAll,
    );
  }

  ParsedAllInOneRegexRule _parseAllInOneRegexRule(String source) {
    final text = source.trim();
    if (text.isEmpty) {
      throw _parseError('AllInOne Regex 规则不能为空。');
    }

    final segments = text.split('::');
    final pattern = segments.first.trim();
    if (pattern.isEmpty) {
      throw _parseError('AllInOne Regex pattern 不能为空。');
    }

    var caseSensitive = true;
    var multiLine = false;
    var dotAll = false;

    for (final segment in segments.skip(1)) {
      final item = segment.trim();
      if (item.isEmpty) {
        continue;
      }

      final separator = item.indexOf('=');
      if (separator <= 0 || separator >= item.length - 1) {
        throw _parseError('AllInOne Regex 参数格式错误：$item');
      }

      final key = item.substring(0, separator).trim();
      final value = item.substring(separator + 1).trim();
      if (key != 'flags') {
        throw _parseError('AllInOne Regex 参数不支持：$key');
      }
      caseSensitive = !value.contains('i');
      multiLine = value.contains('m');
      dotAll = value.contains('s');
    }

    return ParsedAllInOneRegexRule(
      pattern: pattern,
      caseSensitive: caseSensitive,
      multiLine: multiLine,
      dotAll: dotAll,
    );
  }

  ParsedRegexGroupReferenceRule _parseRegexGroupReferenceRule(String source) {
    final text = source.trim();
    final group = int.tryParse(text.substring(1));
    if (group == null || group < 0) {
      throw _parseError('Regex 分组引用格式错误：$source');
    }
    return ParsedRegexGroupReferenceRule(group: group);
  }

  ParsedJsonRule _parseJsonRule(String source) {
    final text = source.trim();
    if (text.isEmpty) {
      throw _parseError('JSON 规则不能为空。');
    }

    return ParsedJsonRule(expression: text);
  }

  ParsedXPathRule _parseXPathRule(String source) {
    final text = source.trim();
    if (text.isEmpty) {
      throw _parseError('XPath 规则不能为空。');
    }

    final normalized = _parseXPathExplicitExtractor(text);
    if (normalized != null) {
      return ParsedXPathRule(
        expression: normalized.expression,
        extractor: normalized.extractor,
      );
    }

    return ParsedXPathRule(
      expression: text,
      extractor: const HtmlExtractor.text(),
    );
  }

  _ParsedXPathWithExtractor? _parseXPathExplicitExtractor(String source) {
    final text = source.trim();
    if (text.isEmpty) {
      return null;
    }

    final explicitExtractor = RegExp(
      r'@(text|html|innerhtml|outerhtml|attr\([^)]+\))$',
      caseSensitive: false,
    ).firstMatch(text);
    if (explicitExtractor == null) {
      return null;
    }

    final rawExtractor = explicitExtractor.group(1)?.trim().toLowerCase();
    if (rawExtractor == null || rawExtractor.isEmpty) {
      return null;
    }

    final expression = text.substring(0, explicitExtractor.start).trim();
    if (expression.isEmpty) {
      throw _parseError('XPath 规则 expression 不能为空。');
    }

    if (rawExtractor == 'text') {
      return _ParsedXPathWithExtractor(
        expression: expression,
        extractor: const HtmlExtractor.text(),
      );
    }

    if (rawExtractor == 'html' || rawExtractor == 'innerhtml') {
      return _ParsedXPathWithExtractor(
        expression: expression,
        extractor: const HtmlExtractor.html(),
      );
    }

    if (rawExtractor == 'outerhtml') {
      return _ParsedXPathWithExtractor(
        expression: expression,
        extractor: const HtmlExtractor.outerHtml(),
      );
    }

    if (rawExtractor.startsWith('attr(') && rawExtractor.endsWith(')')) {
      final attribute =
          rawExtractor.substring(5, rawExtractor.length - 1).trim();
      if (attribute.isEmpty) {
        throw _parseError('XPath attr() 属性名不能为空。');
      }

      return _ParsedXPathWithExtractor(
        expression: expression,
        extractor: HtmlExtractor.attr(attribute),
      );
    }

    return null;
  }

  String? _extractDirectScript(String expression) {
    final text = expression.trim();
    if (text.isEmpty) {
      return null;
    }

    if (text.startsWith('@js:')) {
      final script = text.substring(4).trim();
      return script.isEmpty ? null : script;
    }

    if (text.startsWith('js:')) {
      final script = text.substring(3).trim();
      return script.isEmpty ? null : script;
    }

    final blockMatch = RegExp(
      r'^<js>([\s\S]*?)</js>$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    final blockScript = blockMatch?.group(1)?.trim();
    if (blockScript != null && blockScript.isNotEmpty) {
      return blockScript;
    }

    return null;
  }

  int _indexOfJsMarker(String expression) {
    final lower = expression.toLowerCase();
    return lower.indexOf('@js:');
  }

  bool _isAllInOneRegexRule(String expression) {
    if (expression.length < 2) {
      return false;
    }
    if (expression.startsWith('://')) {
      return false;
    }
    return expression.startsWith(':') || expression.startsWith('+');
  }

  bool _isRegexGroupReference(String expression) {
    return RegExp(r'^\$\d+$').hasMatch(expression);
  }

  AppException _parseError(String message) {
    return AppException(
      code: ErrorCode.ruleParse,
      stage: ErrorStage.search,
      briefMessage: message,
    );
  }
}

class _ParsedXPathWithExtractor {
  const _ParsedXPathWithExtractor({
    required this.expression,
    required this.extractor,
  });

  final String expression;
  final HtmlExtractor extractor;
}
