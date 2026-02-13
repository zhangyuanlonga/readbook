import 'package:html/parser.dart' as html_parser;

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
    final nodes = document.querySelectorAll(selector);
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
}
