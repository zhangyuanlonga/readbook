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
    final nodes = _queryNodesWithCompat(document, selector);
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

  List<Element> _queryNodesWithCompat(Document document, String selector) {
    try {
      final matched = document.querySelectorAll(selector);
      if (matched.isNotEmpty) {
        return matched;
      }
    } catch (_) {
      // fall through and retry with compatibility selector.
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
