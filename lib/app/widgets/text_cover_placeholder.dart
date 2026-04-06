import 'package:flutter/material.dart';

class TextCoverPlaceholder extends StatelessWidget {
  const TextCoverPlaceholder({
    super.key,
    required this.title,
    this.author,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final String? title;
  final String? author;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final resolvedWidth = width.isFinite && width > 0 ? width : 56.0;
    final resolvedHeight = height.isFinite && height > 0 ? height : 80.0;
    final normalizedTitle = _normalizeText(title);
    final normalizedAuthor = _normalizeText(author);
    final baseColor = _resolveSeedColor(normalizedTitle, normalizedAuthor);
    final textColor = Colors.white.withValues(alpha: 0.96);
    final showAuthor = normalizedAuthor.isNotEmpty && resolvedHeight >= 82;
    final compact = resolvedHeight < 82 || resolvedWidth < 56;
    final titleMaxLines =
        compact
            ? 3
            : resolvedHeight >= 120
            ? 4
            : 3;
    final titleAlign = compact ? TextAlign.center : TextAlign.left;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: textColor.withValues(alpha: 0.94),
      fontWeight: FontWeight.w800,
      height: 1.1,
      fontSize:
          compact
              ? (resolvedWidth * 0.18).clamp(10.0, 14.0)
              : (resolvedWidth * 0.16).clamp(11.0, 18.0),
    );
    final authorStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: textColor.withValues(alpha: 0.88),
      fontWeight: FontWeight.w600,
      height: 1.0,
      fontSize: compact ? 9 : 10.5,
    );

    return Container(
      width: resolvedWidth,
      height: resolvedHeight,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _shiftLightness(baseColor, 0.12),
            baseColor,
            _shiftLightness(baseColor, -0.08),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: resolvedHeight * 0.16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: borderRadius.topLeft,
                  topRight: borderRadius.topRight,
                ),
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              resolvedWidth * 0.12,
              resolvedHeight * 0.12,
              resolvedWidth * 0.12,
              resolvedHeight * 0.10,
            ),
            child: Column(
              crossAxisAlignment:
                  compact
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Align(
                    alignment: compact ? Alignment.center : Alignment.topLeft,
                    child: Text(
                      normalizedTitle.isEmpty ? '未命名书籍' : normalizedTitle,
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      textAlign: titleAlign,
                      style: titleStyle,
                    ),
                  ),
                ),
                if (showAuthor)
                  Padding(
                    padding: EdgeInsets.only(top: compact ? 4 : 8),
                    child: Text(
                      normalizedAuthor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: titleAlign,
                      style: authorStyle,
                    ),
                  )
                else
                  Text(
                    '',
                    style: authorStyle?.copyWith(color: Colors.transparent),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _normalizeText(String? value) {
    return (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static Color _resolveSeedColor(String title, String author) {
    final seed = '$title|$author';
    var hash = 0;
    for (final codeUnit in seed.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.42, 0.48).toColor();
  }

  static Color _shiftLightness(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}
