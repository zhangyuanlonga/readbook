import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';
import 'package:xml/xpath.dart';

import '../../errors/app_exception.dart';
import '../../errors/error_codes.dart';
import '../../errors/error_stage.dart';
import '../processors/legacy_xpath_compat.dart';
import '../rule_parser.dart';
import 'html_executor.dart';

class XPathExecutor {
  const XPathExecutor({HtmlExecutor? htmlExecutor, RuleParser? parser})
    : _htmlExecutor = htmlExecutor ?? const HtmlExecutor(),
      _parser = parser ?? const RuleParser();

  final HtmlExecutor _htmlExecutor;
  final RuleParser _parser;

  List<String> execute({
    required String content,
    required ParsedXPathRule rule,
    ErrorStage stage = ErrorStage.search,
  }) {
    final expression = rule.expression.trim();
    if (expression.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleParse,
        stage: stage,
        briefMessage: 'XPath expression 不能为空。',
      );
    }

    Object? nativeFailure;
    StackTrace? nativeStackTrace;
    try {
      final xmlDocument = _parseHtmlAsXml(content);
      final value = xmlDocument.xpathEvaluate(expression);
      final extracted = _extractXPathValue(value, rule.extractor);
      if (extracted.isNotEmpty) {
        return extracted;
      }
    } catch (error, stackTrace) {
      nativeFailure = error;
      nativeStackTrace = stackTrace;
    }

    final fallbackValues = _executeLegacyFallback(
      content: content,
      expression: expression,
      extractor: rule.extractor,
      stage: stage,
    );
    if (fallbackValues.isNotEmpty) {
      return fallbackValues;
    }

    if (nativeFailure != null) {
      throw _mapNativeFailure(
        error: nativeFailure,
        stackTrace: nativeStackTrace,
        expression: expression,
        stage: stage,
      );
    }

    throw RuleMatchEmptyException(
      briefMessage: 'XPath 规则未命中：$expression',
      stage: stage,
    );
  }

  XmlDocument _parseHtmlAsXml(String content) {
    final htmlDocument = html_parser.parse(content);
    final builder = XmlBuilder();
    builder.element(
      'document',
      nest: () {
        final root = htmlDocument.documentElement;
        if (root != null) {
          _appendHtmlNode(builder, root);
          return;
        }

        for (final node in htmlDocument.nodes) {
          _appendHtmlNode(builder, node);
        }
      },
    );

    return builder.buildDocument();
  }

  void _appendHtmlNode(XmlBuilder builder, html_dom.Node node) {
    if (node is html_dom.Element) {
      final tag = node.localName?.trim();
      if (tag == null || tag.isEmpty) {
        return;
      }

      builder.element(
        tag,
        nest: () {
          for (final entry in node.attributes.entries) {
            final name = entry.key.toString().trim();
            if (name.isEmpty) {
              continue;
            }
            builder.attribute(name, entry.value);
          }
          for (final child in node.nodes) {
            _appendHtmlNode(builder, child);
          }
        },
      );
      return;
    }

    if (node is html_dom.Text) {
      if (node.text.isEmpty) {
        return;
      }
      builder.text(node.text);
      return;
    }

    if (node is html_dom.Document) {
      for (final child in node.nodes) {
        _appendHtmlNode(builder, child);
      }
    }
  }

  List<String> _extractXPathValue(XPathValue value, HtmlExtractor extractor) {
    final output = <String>[];
    if (value is XPathNodeSet) {
      for (final node in value.nodes) {
        final resolved = _extractNode(node, extractor);
        if (resolved != null && resolved.trim().isNotEmpty) {
          output.add(resolved.trim());
        }
      }
      return output;
    }

    final scalar = value.string.trim();
    if (scalar.isNotEmpty) {
      output.add(scalar);
    }
    return output;
  }

  String? _extractNode(XmlNode node, HtmlExtractor extractor) {
    switch (extractor.type) {
      case HtmlExtractorType.text:
        if (node is XmlAttribute) {
          return node.value;
        }
        if (node is XmlText || node is XmlCDATA) {
          return node.value;
        }
        return node.innerText;
      case HtmlExtractorType.html:
        if (node is XmlAttribute) {
          return node.value;
        }
        if (node is XmlText || node is XmlCDATA) {
          return node.value;
        }
        return node.innerXml;
      case HtmlExtractorType.outerHtml:
        if (node is XmlAttribute) {
          return node.value;
        }
        if (node is XmlText || node is XmlCDATA) {
          return node.value;
        }
        return node.outerXml;
      case HtmlExtractorType.attr:
        final attributeName = extractor.attributeName;
        if (attributeName == null || attributeName.trim().isEmpty) {
          return null;
        }
        final expected = attributeName.trim();
        if (node is XmlAttribute) {
          final localName = node.name.local;
          final qualifiedName = node.name.qualified;
          if (localName == expected || qualifiedName == expected) {
            return node.value;
          }
          return null;
        }
        if (node is XmlElement) {
          final direct = node.getAttribute(expected);
          if (direct != null) {
            return direct;
          }
          for (final attribute in node.attributes) {
            if (attribute.name.local == expected ||
                attribute.name.qualified == expected) {
              return attribute.value;
            }
          }
          return null;
        }
        return null;
    }
  }

  List<String> _executeLegacyFallback({
    required String content,
    required String expression,
    required HtmlExtractor extractor,
    required ErrorStage stage,
  }) {
    final preferredAttribute =
        extractor.type == HtmlExtractorType.attr
            ? extractor.attributeName
            : null;
    final fallbackExpression = LegacyXPathCompat.buildRuleExpression(
      expression: 'xpath:$expression',
      fallbackExtractor: _extractorToLegacy(extractor),
      preferredAttribute: preferredAttribute,
    );
    if (fallbackExpression == null || fallbackExpression.isEmpty) {
      return const [];
    }

    final output = <String>[];
    for (final candidate in fallbackExpression
        .split('||')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)) {
      ParsedRule parsed;
      try {
        parsed = _parser.parse(candidate);
      } on AppException {
        continue;
      }
      if (parsed is! ParsedHtmlRule) {
        continue;
      }

      try {
        output.addAll(
          _htmlExecutor.execute(content: content, rule: parsed, stage: stage),
        );
      } on AppException {
        continue;
      }
    }
    return output;
  }

  String _extractorToLegacy(HtmlExtractor extractor) {
    return switch (extractor.type) {
      HtmlExtractorType.text => 'text',
      HtmlExtractorType.html => 'html',
      HtmlExtractorType.outerHtml => 'outerhtml',
      HtmlExtractorType.attr => 'attr(${extractor.attributeName ?? ''})',
    };
  }

  AppException _mapNativeFailure({
    required Object error,
    required StackTrace? stackTrace,
    required String expression,
    required ErrorStage stage,
  }) {
    if (error is AppException) {
      return error;
    }

    if (error is XPathParserException) {
      return AppException(
        code: ErrorCode.ruleParse,
        stage: stage,
        briefMessage: 'XPath 规则解析失败：$expression',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is XPathEvaluationException) {
      return AppException(
        code: ErrorCode.ruleParse,
        stage: stage,
        briefMessage: 'XPath 规则执行失败：$expression',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is XmlParserException) {
      return AppException(
        code: ErrorCode.decode,
        stage: stage,
        briefMessage: 'XPath 内容解析失败。',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return AppException(
      code: ErrorCode.unknown,
      stage: stage,
      briefMessage: 'XPath 执行异常：$expression',
      cause: error,
      stackTrace: stackTrace,
    );
  }
}
