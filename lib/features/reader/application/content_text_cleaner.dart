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

  static final RegExp _htmlParagraphBreakPattern = RegExp(
    r'(<br\s*/?>\s*){2,}',
    caseSensitive: false,
  );

  static final RegExp _htmlLineBreakPattern = RegExp(
    r'<br\s*/?>',
    caseSensitive: false,
  );

  static final RegExp _htmlBlockClosePattern = RegExp(
    r'</(p|div|li|h[1-6])>',
    caseSensitive: false,
  );

  static final RegExp _invisibleCharPattern = RegExp(
    r'[\uFEFF\u200B\u200C\u200D\u2060]',
  );

  static final RegExp _controlCharPattern = RegExp(
    r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]',
  );

  static final RegExp _paragraphEndPattern = RegExp(
    r'[。！？!?…]+$|[”’」』）)\]]$',
  );

  String clean(String source) {
    if (source.trim().isEmpty) {
      return '';
    }

    final withoutScript = source.replaceAll(_removeTagPattern, ' ');

    // Inject explicit line breaks into HTML before extracting plain text.
    final normalizedHtml = withoutScript
        .replaceAll(_htmlParagraphBreakPattern, '\n\n')
        .replaceAll(_htmlLineBreakPattern, '\n')
        .replaceAll(_htmlBlockClosePattern, '\n\n');

    final extractedText = html_parser.parseFragment(normalizedHtml).text ?? '';

    var normalized = _normalizeLineBreaks(extractedText);

    normalized = normalized
        .replaceAll('\t', ' ')
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u2028', '\n')
        .replaceAll('\u2029', '\n')
        .replaceAll(_invisibleCharPattern, '')
        .replaceAll(_controlCharPattern, '')
        .replaceAll('\uFFFD', '');

    normalized = normalized.trim();
    if (normalized.isEmpty) {
      return '';
    }

    normalized = normalized.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    final paragraphs = _buildParagraphs(normalized);
    if (paragraphs.isEmpty) {
      return '';
    }

    return paragraphs.join('\n\n').trim();
  }

  List<String> _buildParagraphs(String text) {
    final hasExplicitParagraph = RegExp(r'\n{2,}').hasMatch(text);

    if (hasExplicitParagraph) {
      final rawParagraphs = text.split(RegExp(r'\n{2,}'));
      final paragraphs = <String>[];

      for (final raw in rawParagraphs) {
        final filtered = _filterAdLines(raw);
        final paragraph = _normalizeParagraph(filtered);
        if (paragraph.isEmpty) {
          continue;
        }
        if (_removeCommonAdPattern.hasMatch(paragraph)) {
          continue;
        }
        paragraphs.add(paragraph);
      }

      return paragraphs;
    }

    final rawLines = text
        .split('\n')
        .map(_normalizeParagraph)
        .where((line) => line.isNotEmpty)
        .where((line) => !_removeCommonAdPattern.hasMatch(line))
        .toList(growable: false);

    if (rawLines.isEmpty) {
      return const [];
    }

    if (rawLines.length == 1) {
      return rawLines;
    }

    final paragraphs = <String>[];
    var buffer = '';

    void flush() {
      final cleaned = _normalizeParagraph(buffer);
      if (cleaned.isNotEmpty && !_removeCommonAdPattern.hasMatch(cleaned)) {
        paragraphs.add(cleaned);
      }
      buffer = '';
    }

    for (final line in rawLines) {
      if (buffer.isEmpty) {
        buffer = line;
        continue;
      }

      final canBreak =
          buffer.length >= 60 && _paragraphEndPattern.hasMatch(buffer);
      final forceBreak = buffer.length >= 140;

      if (canBreak || forceBreak) {
        flush();
        buffer = line;
        continue;
      }

      buffer = buffer + _joinerBetween(buffer, line) + line;
    }

    if (buffer.isNotEmpty) {
      flush();
    }

    return paragraphs;
  }

  String _filterAdLines(String text) {
    final lines = text.split('\n');
    final kept = <String>[];

    for (final line in lines) {
      final normalized = line.trim();
      if (normalized.isEmpty) {
        kept.add('');
        continue;
      }
      if (_removeCommonAdPattern.hasMatch(normalized)) {
        continue;
      }
      kept.add(line);
    }

    return kept.join('\n');
  }

  String _normalizeParagraph(String text) {
    var normalized = _normalizeLineBreaks(text);
    normalized = normalized.replaceAll(RegExp(r'\n+'), ' ');
    normalized = normalized.trim();

    if (normalized.isEmpty) {
      return '';
    }

    normalized = normalized.replaceAll(RegExp(r'\s{2,}'), ' ');
    return normalized;
  }

  String _normalizeLineBreaks(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(r'\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\n');
  }

  String _joinerBetween(String left, String right) {
    if (left.isEmpty || right.isEmpty) {
      return '';
    }

    final leftLast = left.codeUnitAt(left.length - 1);
    final rightFirst = right.codeUnitAt(0);

    final leftAscii = (leftLast >= 0x30 && leftLast <= 0x39) ||
        (leftLast >= 0x41 && leftLast <= 0x5A) ||
        (leftLast >= 0x61 && leftLast <= 0x7A);

    final rightAscii = (rightFirst >= 0x30 && rightFirst <= 0x39) ||
        (rightFirst >= 0x41 && rightFirst <= 0x5A) ||
        (rightFirst >= 0x61 && rightFirst <= 0x7A);

    return leftAscii && rightAscii ? ' ' : '';
  }
}
