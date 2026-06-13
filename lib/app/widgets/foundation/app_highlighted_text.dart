import 'package:flutter/material.dart';

class AppHighlightedText extends StatelessWidget {
  const AppHighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow,
    this.caseSensitive = false,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool caseSensitive;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveHighlightStyle =
        highlightStyle ??
        effectiveStyle.copyWith(
          color: colorScheme.onTertiaryContainer,
          backgroundColor: colorScheme.tertiaryContainer,
          fontWeight: FontWeight.w700,
        );
    final spans = _buildSpans(effectiveStyle, effectiveHighlightStyle);

    return Text.rich(
      TextSpan(style: effectiveStyle, children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }

  List<TextSpan> _buildSpans(TextStyle baseStyle, TextStyle matchedStyle) {
    if (query.trim().isEmpty || text.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final source = caseSensitive ? text : text.toLowerCase();
    final target = caseSensitive ? query : query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (start < text.length) {
      final index = source.indexOf(target, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }
      if (index > start) {
        spans.add(
          TextSpan(text: text.substring(start, index), style: baseStyle),
        );
      }
      final end = index + target.length;
      spans.add(
        TextSpan(text: text.substring(index, end), style: matchedStyle),
      );
      start = end;
    }
    return spans;
  }
}
