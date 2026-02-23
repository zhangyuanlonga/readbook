import '../errors/app_exception.dart';
import '../errors/error_codes.dart';
import '../errors/error_stage.dart';

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

class ParsedJsonRule extends ParsedRule {
  const ParsedJsonRule({required this.expression});

  final String expression;
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

    if (text.startsWith('html:')) {
      return _parseHtmlRule(text.substring(5));
    }

    if (text.startsWith('regex:')) {
      return _parseRegexRule(text.substring(6));
    }

    if (text.startsWith('json:')) {
      return _parseJsonRule(text.substring(5));
    }

    throw _parseError('规则前缀不支持，仅支持 html:、regex: 或 json:');
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

  ParsedJsonRule _parseJsonRule(String source) {
    final text = source.trim();
    if (text.isEmpty) {
      throw _parseError('JSON 规则不能为空。');
    }

    return ParsedJsonRule(expression: text);
  }

  AppException _parseError(String message) {
    return AppException(
      code: ErrorCode.ruleParse,
      stage: ErrorStage.search,
      briefMessage: message,
    );
  }
}
