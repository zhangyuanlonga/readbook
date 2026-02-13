import 'package:html/parser.dart' as html_parser;

class ContentTextCleaner {
  const ContentTextCleaner();

  static final RegExp _removeTagPattern = RegExp(
    r'<(script|style|noscript)[^>]*>[\s\S]*?<\/\1>',
    caseSensitive: false,
  );
  static final RegExp _removeCommonAdPattern = RegExp(
    r'(最新网址|请记住本站域名|手机用户请|收藏本站|一秒记住|本章未完|广告)',
    caseSensitive: false,
  );

  String clean(String source) {
    if (source.trim().isEmpty) {
      return '';
    }

    final withoutScript = source.replaceAll(_removeTagPattern, ' ');
    final normalizedBreaks = withoutScript
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n')
        .replaceAll('<br>', '\n')
        .replaceAll('</p>', '\n')
        .replaceAll('</div>', '\n');

    final extractedText =
        html_parser.parseFragment(normalizedBreaks).text ?? '';
    final compatibleText = _normalizeLineBreaks(extractedText);

    final lines = compatibleText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !_removeCommonAdPattern.hasMatch(line))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' '))
        .toList(growable: false);

    if (lines.isEmpty) {
      return '';
    }

    return lines.join('\n\n').trim();
  }

  String _normalizeLineBreaks(String text) {
    return text
        .replaceAll(r'\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\n')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
  }
}
