import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'html_helpers.dart';

abstract class HtmlRuntime {
  dom.Document parse(String source);
  String text(dom.Node? node);
  String innerHtml(dom.Element? element);
  String attr(dom.Element? element, String name);
  List<T> collect<T>(
    Iterable<dom.Element> elements,
    T Function(dom.Element element, int index) mapper,
  );
}

class DefaultHtmlRuntime implements HtmlRuntime {
  const DefaultHtmlRuntime();

  @override
  dom.Document parse(String source) {
    return html_parser.parse(source);
  }

  @override
  String text(dom.Node? node) {
    if (node == null) {
      return '';
    }
    return normalizeHtmlText(node.text ?? '');
  }

  @override
  String innerHtml(dom.Element? element) {
    if (element == null) {
      return '';
    }
    return element.innerHtml;
  }

  @override
  String attr(dom.Element? element, String name) {
    return element?.attributes[name]?.trim() ?? '';
  }

  @override
  List<T> collect<T>(
    Iterable<dom.Element> elements,
    T Function(dom.Element element, int index) mapper,
  ) {
    final results = <T>[];
    var index = 0;
    for (final element in elements) {
      results.add(mapper(element, index));
      index += 1;
    }
    return results;
  }
}
