import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/reader_settings.dart';

class ReaderTextAnnotationRange {
  const ReaderTextAnnotationRange(
    this.start,
    this.end, {
    required this.hasHighlight,
    required this.isBold,
    required this.isUnderline,
    required this.isWavy,
  });

  final int start;
  final int end;
  final bool hasHighlight;
  final bool isBold;
  final bool isUnderline;
  final bool isWavy;
}

class ReaderAnnotatedText extends StatelessWidget {
  const ReaderAnnotatedText({
    super.key,
    required this.displayText,
    required this.indentLength,
    required this.baseStyle,
    required this.textAlign,
    required this.textDirection,
    required this.highlightColor,
    required this.wavyColor,
    this.annotationRanges = const <ReaderTextAnnotationRange>[],
    this.bodyDecorationEnabled = false,
    this.bodyDecorationColor,
    this.bodyDecorationStyle = ReaderBodyTextDecorationStyle.none,
    this.bodyDecorationThickness = 2.2,
    this.bodyDecorationGap = 2,
    this.bodyDecorationDashLength = 6,
    this.bodyDecorationDashGapRatio = 6,
    this.onTapUp,
  });

  final String displayText;
  final int indentLength;
  final TextStyle baseStyle;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final Color highlightColor;
  final Color wavyColor;
  final List<ReaderTextAnnotationRange> annotationRanges;
  final bool bodyDecorationEnabled;
  final Color? bodyDecorationColor;
  final ReaderBodyTextDecorationStyle bodyDecorationStyle;
  final double bodyDecorationThickness;
  final double bodyDecorationGap;
  final double bodyDecorationDashLength;
  final double bodyDecorationDashGapRatio;
  final GestureTapUpCallback? onTapUp;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mergedRanges =
              annotationRanges.isNotEmpty
                  ? _mergeRanges(annotationRanges)
                  : const <ReaderTextAnnotationRange>[];
          final textSpan =
              mergedRanges.isNotEmpty
                  ? _buildAnnotatedTextSpan(mergedRanges)
                  : _buildDisplayTextSpan();

          final wavyRanges = <ReaderWavyRange>[];
          if (mergedRanges.isNotEmpty) {
            for (final range in mergedRanges) {
              if (!range.isWavy) {
                continue;
              }
              final startDisplay = _clampInt(
                range.start + indentLength,
                0,
                displayText.length,
              );
              final endDisplay = _clampInt(
                range.end + indentLength,
                0,
                displayText.length,
              );
              if (endDisplay > startDisplay) {
                wavyRanges.add(ReaderWavyRange(startDisplay, endDisplay));
              }
            }
          }

          final needsPainter = wavyRanges.isNotEmpty || bodyDecorationEnabled;
          final textPainter =
              needsPainter
                  ? _buildTextPainter(maxWidth: constraints.maxWidth)
                  : null;

          Widget textWidget = Text.rich(
            textSpan,
            textAlign: textAlign,
            textDirection: textDirection,
          );

          if (needsPainter && textPainter != null) {
            final painters = <CustomPainter>[];
            if (bodyDecorationEnabled) {
              painters.add(
                ReaderBodyUnderlinePainter(
                  text: displayText,
                  textPainter: textPainter,
                  start: indentLength,
                  end: displayText.length,
                  excludedLeadingLength: indentLength,
                  color: bodyDecorationColor ?? baseStyle.color ?? Colors.black,
                  style: bodyDecorationStyle,
                  thickness: bodyDecorationThickness,
                  gap: bodyDecorationGap,
                  dashLength: bodyDecorationDashLength,
                  dashGapRatio: bodyDecorationDashGapRatio,
                ),
              );
            }
            if (wavyRanges.isNotEmpty) {
              painters.add(
                ReaderWavyUnderlinePainter(
                  textPainter: textPainter,
                  ranges: wavyRanges,
                  color: wavyColor,
                  amplitude: (baseStyle.fontSize ?? 18) * 0.26,
                  wavelength: (baseStyle.fontSize ?? 18) * 1.6,
                  thickness: _decorationThickness(baseStyle, wavy: true),
                ),
              );
            }
            textWidget = CustomPaint(
              foregroundPainter: ReaderCompositeTextDecorationPainter(
                painters: painters,
              ),
              child: textWidget,
            );
          }

          if (onTapUp == null) {
            return textWidget;
          }
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: onTapUp,
            child: textWidget,
          );
        },
      ),
    );
  }

  TextSpan _buildAnnotatedTextSpan(List<ReaderTextAnnotationRange> ranges) {
    final spans = <TextSpan>[];
    if (indentLength > 0) {
      spans.add(
        TextSpan(
          text: displayText.substring(0, indentLength),
          style: _indentTextStyle(baseStyle),
        ),
      );
    }

    var cursor = indentLength;
    for (final range in ranges) {
      final start = _clampInt(
        range.start + indentLength,
        0,
        displayText.length,
      );
      final end = _clampInt(range.end + indentLength, 0, displayText.length);
      if (start > cursor) {
        spans.add(
          TextSpan(
            text: displayText.substring(cursor, start),
            style: baseStyle,
          ),
        );
      }
      if (end > start) {
        spans.add(
          TextSpan(
            text: displayText.substring(start, end),
            style: _highlightStyle(range),
          ),
        );
        cursor = end;
      }
    }

    if (cursor < displayText.length) {
      spans.add(
        TextSpan(text: displayText.substring(cursor), style: baseStyle),
      );
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  TextSpan _buildDisplayTextSpan() {
    if (indentLength <= 0 || indentLength >= displayText.length) {
      return TextSpan(text: displayText, style: baseStyle);
    }
    return TextSpan(
      style: baseStyle,
      children: [
        TextSpan(
          text: displayText.substring(0, indentLength),
          style: _indentTextStyle(baseStyle),
        ),
        TextSpan(text: displayText.substring(indentLength)),
      ],
    );
  }

  TextStyle _highlightStyle(ReaderTextAnnotationRange range) {
    final decorationEnabled = range.isUnderline && !range.isWavy;
    final preserveBaseDecoration = !decorationEnabled && !range.isWavy;
    return baseStyle.copyWith(
      backgroundColor:
          range.hasHighlight ? highlightColor.withValues(alpha: 0.12) : null,
      fontWeight: range.isBold ? FontWeight.w800 : baseStyle.fontWeight,
      decoration:
          decorationEnabled
              ? TextDecoration.underline
              : preserveBaseDecoration
              ? baseStyle.decoration
              : TextDecoration.none,
      decorationStyle:
          decorationEnabled
              ? TextDecorationStyle.solid
              : preserveBaseDecoration
              ? baseStyle.decorationStyle
              : TextDecorationStyle.solid,
      decorationColor:
          decorationEnabled
              ? highlightColor.withValues(alpha: 0.55)
              : preserveBaseDecoration
              ? baseStyle.decorationColor
              : null,
      decorationThickness:
          decorationEnabled
              ? _decorationThickness(baseStyle, wavy: false)
              : preserveBaseDecoration
              ? baseStyle.decorationThickness
              : null,
    );
  }

  TextPainter _buildTextPainter({required double maxWidth}) {
    final painter = TextPainter(
      text: TextSpan(text: displayText, style: baseStyle),
      textAlign: textAlign,
      textDirection: textDirection,
    );
    painter.layout(maxWidth: maxWidth);
    return painter;
  }
}

class ReaderCompositeTextDecorationPainter extends CustomPainter {
  ReaderCompositeTextDecorationPainter({required this.painters});

  final List<CustomPainter> painters;

  @override
  void paint(Canvas canvas, Size size) {
    for (final painter in painters) {
      painter.paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(
    covariant ReaderCompositeTextDecorationPainter oldDelegate,
  ) {
    return true;
  }
}

class ReaderBodyUnderlinePainter extends CustomPainter {
  ReaderBodyUnderlinePainter({
    required this.text,
    required this.textPainter,
    required this.start,
    required this.end,
    required this.excludedLeadingLength,
    required this.color,
    required this.style,
    required this.thickness,
    required this.gap,
    required this.dashLength,
    required this.dashGapRatio,
  });

  final String text;
  final TextPainter textPainter;
  final int start;
  final int end;
  final int excludedLeadingLength;
  final Color color;
  final ReaderBodyTextDecorationStyle style;
  final double thickness;
  final double gap;
  final double dashLength;
  final double dashGapRatio;

  @override
  void paint(Canvas canvas, Size size) {
    if (style == ReaderBodyTextDecorationStyle.none || end <= start) {
      return;
    }

    final boxes = _visibleUnderlineBoxes(
      text: text,
      textPainter: textPainter,
      start: start,
      end: end,
    );
    if (boxes.isEmpty) {
      return;
    }

    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.round;
    final dashGap = math.max(1.0, dashLength * (dashGapRatio / 6));
    final lineMetrics = textPainter.computeLineMetrics();
    final excludedBoxes =
        excludedLeadingLength <= 0
            ? const <TextBox>[]
            : textPainter.getBoxesForSelection(
              TextSelection(
                baseOffset: 0,
                extentOffset: excludedLeadingLength.clamp(0, end),
              ),
            );

    for (final box in boxes) {
      final adjustedRect = _trimLeadingExcludedRange(
        box.toRect(),
        excludedBoxes,
      );
      if (adjustedRect == null) {
        continue;
      }
      final rect = adjustedRect;
      if (rect.width <= 0) {
        continue;
      }
      final baselineY = _resolveBaselineY(rect: rect, lineMetrics: lineMetrics);
      if (style == ReaderBodyTextDecorationStyle.solid) {
        canvas.drawLine(
          Offset(rect.left, baselineY),
          Offset(rect.right, baselineY),
          paint,
        );
        continue;
      }

      double x = rect.left;
      while (x < rect.right) {
        final nextX = math.min(rect.right, x + dashLength);
        canvas.drawLine(Offset(x, baselineY), Offset(nextX, baselineY), paint);
        x = nextX + dashGap;
      }
    }
  }

  Rect? _trimLeadingExcludedRange(Rect rect, List<TextBox> excludedBoxes) {
    if (excludedBoxes.isEmpty) {
      return rect;
    }

    double? trimmedLeft;
    for (final excluded in excludedBoxes) {
      final excludedRect = excluded.toRect();
      final verticallyOverlaps =
          rect.bottom > excludedRect.top && rect.top < excludedRect.bottom;
      if (!verticallyOverlaps) {
        continue;
      }
      trimmedLeft = math.max(trimmedLeft ?? rect.left, excludedRect.right);
    }

    if (trimmedLeft == null) {
      return rect;
    }
    if (trimmedLeft >= rect.right) {
      return null;
    }
    return Rect.fromLTRB(trimmedLeft, rect.top, rect.right, rect.bottom);
  }

  double _resolveBaselineY({
    required Rect rect,
    required List<LineMetrics> lineMetrics,
  }) {
    if (lineMetrics.isEmpty) {
      return rect.bottom - math.max(thickness * 0.5, 1.0);
    }
    final centerY = rect.center.dy;
    for (final line in lineMetrics) {
      final lineTop = line.baseline - line.ascent;
      final lineBottom = line.baseline + line.descent;
      if (centerY >= lineTop - 0.5 && centerY <= lineBottom + 0.5) {
        final desired = line.baseline + math.min(gap, line.descent * 0.25);
        final maxY = rect.bottom - math.max(thickness * 0.5, 1.0);
        return math.min(desired, maxY);
      }
    }
    return rect.bottom - math.max(thickness * 0.5, 1.0);
  }

  @override
  bool shouldRepaint(covariant ReaderBodyUnderlinePainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.start != start ||
        oldDelegate.end != end ||
        oldDelegate.excludedLeadingLength != excludedLeadingLength ||
        oldDelegate.color != color ||
        oldDelegate.style != style ||
        oldDelegate.thickness != thickness ||
        oldDelegate.gap != gap ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.dashGapRatio != dashGapRatio;
  }
}

List<TextBox> _visibleUnderlineBoxes({
  required String text,
  required TextPainter textPainter,
  required int start,
  required int end,
}) {
  final boxes = <TextBox>[];
  final safeStart = _clampInt(start, 0, text.length);
  final safeEnd = _clampInt(end, 0, text.length);
  if (safeEnd <= safeStart) {
    return boxes;
  }

  for (var index = safeStart; index < safeEnd; index += 1) {
    final char = text[index];
    if (!_isUnderlineVisibleCharacter(char)) {
      continue;
    }
    boxes.addAll(
      textPainter.getBoxesForSelection(
        TextSelection(baseOffset: index, extentOffset: index + 1),
      ),
    );
  }
  if (boxes.length <= 1) {
    return boxes;
  }

  final merged = <TextBox>[];
  Rect? currentRect;
  TextDirection? currentDirection;
  for (final box in boxes) {
    final rect = box.toRect();
    if (currentRect == null) {
      currentRect = rect;
      currentDirection = box.direction;
      continue;
    }
    final verticallyOverlaps =
        currentRect.bottom > rect.top && currentRect.top < rect.bottom;
    final horizontalGap = rect.left - currentRect.right;
    if (verticallyOverlaps && horizontalGap <= 3.5) {
      currentRect = Rect.fromLTRB(
        currentRect.left,
        math.min(currentRect.top, rect.top),
        rect.right,
        math.max(currentRect.bottom, rect.bottom),
      );
      continue;
    }
    merged.add(
      TextBox.fromLTRBD(
        currentRect.left,
        currentRect.top,
        currentRect.right,
        currentRect.bottom,
        currentDirection ?? TextDirection.ltr,
      ),
    );
    currentRect = rect;
    currentDirection = box.direction;
  }
  if (currentRect != null) {
    merged.add(
      TextBox.fromLTRBD(
        currentRect.left,
        currentRect.top,
        currentRect.right,
        currentRect.bottom,
        currentDirection ?? TextDirection.ltr,
      ),
    );
  }
  return merged;
}

bool _isUnderlineVisibleCharacter(String char) {
  return char.trim().isNotEmpty;
}

class ReaderWavyUnderlinePainter extends CustomPainter {
  ReaderWavyUnderlinePainter({
    required this.textPainter,
    required this.ranges,
    required this.color,
    required this.amplitude,
    required this.wavelength,
    required this.thickness,
  });

  final TextPainter textPainter;
  final List<ReaderWavyRange> ranges;
  final Color color;
  final double amplitude;
  final double wavelength;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    if (ranges.isEmpty) {
      return;
    }

    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.round;

    for (final range in ranges) {
      final boxes = textPainter.getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end),
      );
      for (final box in boxes) {
        final rect = box.toRect();
        if (rect.width <= 0) {
          continue;
        }
        final baseY = rect.bottom - thickness;
        final path = Path();
        double x = rect.left;
        final endX = rect.right;
        final step = math.max(2.0, wavelength / 6);
        path.moveTo(x, baseY);
        while (x <= endX) {
          final t = (x - rect.left) / wavelength * 2 * math.pi;
          final y = baseY + math.sin(t) * amplitude;
          path.lineTo(x, y);
          x += step;
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ReaderWavyUnderlinePainter oldDelegate) {
    return oldDelegate.ranges != ranges ||
        oldDelegate.color != color ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.wavelength != wavelength ||
        oldDelegate.thickness != thickness;
  }
}

class ReaderWavyRange {
  const ReaderWavyRange(this.start, this.end);

  final int start;
  final int end;
}

TextStyle _indentTextStyle(TextStyle baseStyle) {
  return baseStyle.copyWith(
    decoration: TextDecoration.none,
    decorationStyle: TextDecorationStyle.solid,
    decorationColor: null,
    decorationThickness: null,
  );
}

List<ReaderTextAnnotationRange> _mergeRanges(
  List<ReaderTextAnnotationRange> ranges,
) {
  if (ranges.length <= 1) {
    return List<ReaderTextAnnotationRange>.from(ranges);
  }

  final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
  final merged = <ReaderTextAnnotationRange>[];
  var current = sorted.first;
  for (var i = 1; i < sorted.length; i++) {
    final next = sorted[i];
    if (_canMergeRanges(current, next)) {
      current = ReaderTextAnnotationRange(
        current.start,
        math.max(current.end, next.end),
        hasHighlight: current.hasHighlight,
        isBold: current.isBold,
        isUnderline: current.isUnderline,
        isWavy: current.isWavy,
      );
    } else {
      merged.add(current);
      current = next;
    }
  }
  merged.add(current);
  return merged;
}

bool _canMergeRanges(ReaderTextAnnotationRange a, ReaderTextAnnotationRange b) {
  if (b.start > a.end) {
    return false;
  }
  return a.hasHighlight == b.hasHighlight &&
      a.isBold == b.isBold &&
      a.isUnderline == b.isUnderline &&
      a.isWavy == b.isWavy;
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

double _decorationThickness(TextStyle baseStyle, {required bool wavy}) {
  final fontSize = baseStyle.fontSize ?? 18;
  final factor = wavy ? 0.28 : 0.14;
  return math.max(wavy ? 3.0 : 2.2, fontSize * factor);
}
