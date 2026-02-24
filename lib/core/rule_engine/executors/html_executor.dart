import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../processors/legacy_rule_compat.dart';

import '../../errors/app_exception.dart';
import '../../errors/error_codes.dart';
import '../../errors/error_stage.dart';
import '../rule_parser.dart';

class HtmlExecutor {
  const HtmlExecutor();

  List<String> execute({
    required String content,
    required ParsedHtmlRule rule,
    ErrorStage stage = ErrorStage.search,
  }) {
    final selector = rule.selector.trim();
    if (selector.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleParse,
        stage: stage,
        briefMessage: 'HTML selector 不能为空。',
      );
    }

    final document = html_parser.parse(content);
    var nodes = _queryNodesWithCompat(document, selector);

    if (nodes.isEmpty &&
        _shouldRetryWithTableContext(content: content, selector: selector)) {
      final tableDocument = _parseTableContextDocument(content);
      nodes = _queryNodesWithCompat(tableDocument, selector);
    }

    if (nodes.isEmpty) {
      throw RuleMatchEmptyException(
        briefMessage: 'HTML 规则未命中：$selector',
        stage: stage,
      );
    }

    final result = <String>[];
    for (final node in nodes) {
      switch (rule.extractor.type) {
        case HtmlExtractorType.text:
          final text = node.text.trim();
          if (text.isNotEmpty) {
            result.add(text);
          }
          break;
        case HtmlExtractorType.html:
          final html = node.innerHtml.trim();
          if (html.isNotEmpty) {
            result.add(html);
          }
          break;
        case HtmlExtractorType.outerHtml:
          final html = node.outerHtml.trim();
          if (html.isNotEmpty) {
            result.add(html);
          }
          break;
        case HtmlExtractorType.attr:
          final attr = node.attributes[rule.extractor.attributeName!]?.trim();
          if (attr != null && attr.isNotEmpty) {
            result.add(attr);
          }
          break;
      }
    }

    if (result.isEmpty) {
      throw RuleMatchEmptyException(
        briefMessage: 'HTML 提取结果为空：$selector',
        stage: stage,
      );
    }

    return result;
  }

  bool _shouldRetryWithTableContext({
    required String content,
    required String selector,
  }) {
    final lowerContent = content.toLowerCase();
    if (RegExp(r'<\s*(tr|td|th|tbody|thead|tfoot)\b').hasMatch(lowerContent)) {
      return true;
    }

    return RegExp(
      r'(^|[\s>+~])(?:tr|td|th|tbody|thead|tfoot)(?=$|[\s>+~.#[:])',
      caseSensitive: false,
    ).hasMatch(selector);
  }

  Document _parseTableContextDocument(String content) {
    final lowerContent = content.toLowerCase();

    if (lowerContent.contains('<tbody') ||
        lowerContent.contains('<thead') ||
        lowerContent.contains('<tfoot')) {
      return html_parser.parse('<table>$content</table>');
    }

    if (lowerContent.contains('<tr') ||
        lowerContent.contains('<td') ||
        lowerContent.contains('<th')) {
      return html_parser.parse('<table><tbody>$content</tbody></table>');
    }

    return html_parser.parse(content);
  }

  List<Element> _queryNodesWithCompat(Document document, String selector) {
    try {
      final matched = document.querySelectorAll(selector);
      if (matched.isNotEmpty) {
        return matched;
      }
    } catch (_) {
      // fall through and retry with compatibility selector.
    }

    final legacyIndexed = _queryLegacyIndexedSelector(
      document: document,
      selector: selector,
    );
    if (legacyIndexed.isNotEmpty) {
      return legacyIndexed;
    }

    final fallbackSelector = LegacyRuleCompat.sanitizeSelector(selector);
    if (fallbackSelector.isEmpty || fallbackSelector == selector) {
      return const <Element>[];
    }

    try {
      return document.querySelectorAll(fallbackSelector);
    } catch (_) {
      return const <Element>[];
    }
  }

  List<Element> _queryLegacyIndexedSelector({
    required Document document,
    required String selector,
  }) {
    final match = RegExp(
      r'^(.*?):(eq|gt|lt)\((\d+)\)\s*$',
    ).firstMatch(selector.trim());
    if (match == null) {
      return const <Element>[];
    }

    final baseSelector = match.group(1)?.trim() ?? '';
    final op = match.group(2) ?? '';
    final index = int.tryParse(match.group(3) ?? '');
    if (baseSelector.isEmpty || index == null || index < 0) {
      return const <Element>[];
    }

    final baseNodes = _queryWithFallbackSelector(document, baseSelector);
    if (baseNodes.isEmpty) {
      return const <Element>[];
    }

    return switch (op) {
      'eq' =>
        index < baseNodes.length
            ? <Element>[baseNodes[index]]
            : const <Element>[],
      'gt' =>
        index + 1 < baseNodes.length
            ? baseNodes.sublist(index + 1)
            : const <Element>[],
      'lt' =>
        index == 0
            ? const <Element>[]
            : baseNodes.take(index).toList(growable: false),
      _ => const <Element>[],
    };
  }

  List<Element> _queryWithFallbackSelector(Document document, String selector) {
    try {
      final matched = document.querySelectorAll(selector);
      if (matched.isNotEmpty) {
        return matched;
      }
    } catch (_) {
      // continue with sanitized selector
    }

    final fallbackSelector = LegacyRuleCompat.sanitizeSelector(selector);
    if (fallbackSelector.isEmpty || fallbackSelector == selector) {
      return const <Element>[];
    }

    try {
      return document.querySelectorAll(fallbackSelector);
    } catch (_) {
      return const <Element>[];
    }
  }
}
