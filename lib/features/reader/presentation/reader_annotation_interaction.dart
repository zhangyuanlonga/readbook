import 'package:flutter/material.dart';

import 'reader_annotated_text.dart';

ReaderTextAnnotationRange? resolveTappedAnnotationRange({
  required List<ReaderTextAnnotationRange> ranges,
  required String displayText,
  required int indentLength,
  required int rawTextLength,
  required Offset localPosition,
  required double maxWidth,
  required TextStyle textStyle,
  required TextDirection textDirection,
  required TextAlign textAlign,
}) {
  if (ranges.isEmpty || displayText.isEmpty) {
    return null;
  }

  final painter = TextPainter(
    text: TextSpan(text: displayText, style: textStyle),
    textAlign: textAlign,
    textDirection: textDirection,
  )..layout(maxWidth: maxWidth);

  final position = painter.getPositionForOffset(localPosition);
  final displayIndex = _clampInt(position.offset, 0, displayText.length);
  final rawIndex = _clampInt(displayIndex - indentLength, 0, rawTextLength);

  ReaderTextAnnotationRange? hitRange;
  for (final range in ranges) {
    if (rawIndex >= range.start && rawIndex <= range.end) {
      if (hitRange == null ||
          (range.end - range.start) < (hitRange.end - hitRange.start)) {
        hitRange = range;
      }
    }
  }
  return hitRange;
}

int _clampInt(int value, int min, int max) {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}
