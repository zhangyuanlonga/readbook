import 'package:flutter/material.dart';

// UI-GOV-EXEMPT-FILE: theme-asset
// reason: Generated text covers are content artwork palettes, not app surfaces.
// owner: app-ui
// review-after: 2026-09-20
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
    final seed = '$normalizedTitle|$normalizedAuthor';
    final hash = _resolveSeedHash(seed);
    final palette = _coverPalettes[hash % _coverPalettes.length];
    final template = _CoverTemplate.values[hash % _CoverTemplate.values.length];
    final textColor = palette.primaryText;
    final secondaryTextColor = palette.secondaryText;
    final showAuthor = normalizedAuthor.isNotEmpty && resolvedHeight >= 82;
    final compact = resolvedHeight < 82 || resolvedWidth < 56;
    final displayTitle =
        normalizedTitle.isEmpty
            ? '未命名书籍'
            : _formatTitleForCover(normalizedTitle);
    final titleMaxLines =
        compact
            ? 2
            : resolvedHeight >= 120
            ? 4
            : 3;
    final titleAlign = TextAlign.left;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: textColor,
      fontWeight: FontWeight.w700,
      height: compact ? 1.05 : 1.08,
      fontSize:
          compact
              ? (resolvedWidth * 0.12).clamp(7.6, 9.4)
              : (resolvedWidth * 0.12).clamp(9.0, 14.0),
      letterSpacing: compact ? 0.1 : 0.2,
    );
    final authorStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: secondaryTextColor,
      fontWeight: FontWeight.w500,
      height: 1.0,
      fontSize: compact ? 7.0 : 8.8,
      letterSpacing: 0.2,
    );
    final contentPadding = EdgeInsets.fromLTRB(
      resolvedWidth * (compact ? 0.11 : 0.13),
      resolvedHeight * (compact ? 0.10 : 0.12),
      resolvedWidth * (compact ? 0.11 : 0.13),
      resolvedHeight * (compact ? 0.08 : 0.10),
    );

    return Container(
      width: resolvedWidth,
      height: resolvedHeight,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.background,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.02),
                    Colors.black.withValues(alpha: 0.08),
                  ],
                ),
              ),
            ),
          ),
          ..._buildTemplateDecorations(
            template: template,
            palette: palette,
            width: resolvedWidth,
            height: resolvedHeight,
            borderRadius: borderRadius,
          ),
          Padding(
            padding: contentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTemplateHeader(
                  template: template,
                  palette: palette,
                  compact: compact,
                ),
                SizedBox(height: compact ? 4 : 8),
                Expanded(
                  child: Text(
                    displayTitle,
                    maxLines: titleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    textAlign: titleAlign,
                    style: titleStyle,
                  ),
                ),
                if (showAuthor)
                  Padding(
                    padding: EdgeInsets.only(top: compact ? 4 : 6),
                    child: Text(
                      normalizedAuthor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: titleAlign,
                      style: authorStyle,
                    ),
                  )
                else
                  const SizedBox.shrink(),
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

  static int _resolveSeedHash(String seed) {
    var hash = 0;
    for (final codeUnit in seed.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  static String _formatTitleForCover(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return '未命名书籍';
    }
    final normalized = trimmed.replaceAll(RegExp(r'[·•｜|]'), '\n');
    if (normalized.contains('\n')) {
      return normalized;
    }
    final buffer = StringBuffer();
    final chars = trimmed.characters.toList();
    final breakEvery =
        chars.length <= 6
            ? chars.length
            : chars.length <= 10
            ? 4
            : 5;
    for (var index = 0; index < chars.length; index++) {
      buffer.write(chars[index]);
      final isLast = index == chars.length - 1;
      final shouldBreak =
          !isLast &&
          (chars[index] == '：' ||
              chars[index] == ':' ||
              chars[index] == '·' ||
              ((index + 1) % breakEvery == 0));
      if (shouldBreak) {
        buffer.write('\n');
      }
    }
    return buffer.toString();
  }
}

enum _CoverTemplate { classic, band, seal }

class _CoverPalette {
  const _CoverPalette({
    required this.background,
    required this.accent,
    required this.secondaryAccent,
    required this.primaryText,
    required this.secondaryText,
  });

  final List<Color> background;
  final Color accent;
  final Color secondaryAccent;
  final Color primaryText;
  final Color secondaryText;
}

const List<_CoverPalette> _coverPalettes = [
  _CoverPalette(
    background: [Color(0xFFF2E8D7), Color(0xFFE5D2B2)],
    accent: Color(0xFF3C312B),
    secondaryAccent: Color(0xFF9E7B4F),
    primaryText: Color(0xFF2E241E),
    secondaryText: Color(0xFF5D4A3B),
  ),
  _CoverPalette(
    background: [Color(0xFF23354A), Color(0xFF182534)],
    accent: Color(0xFFF1D08A),
    secondaryAccent: Color(0xFF8BA7C8),
    primaryText: Color(0xFFF7F2E6),
    secondaryText: Color(0xFFD6C8AB),
  ),
  _CoverPalette(
    background: [Color(0xFFEEE8E0), Color(0xFFD6C9BC)],
    accent: Color(0xFF6E3D35),
    secondaryAccent: Color(0xFFC38D6A),
    primaryText: Color(0xFF342925),
    secondaryText: Color(0xFF6A5750),
  ),
  _CoverPalette(
    background: [Color(0xFF1F2E28), Color(0xFF15201C)],
    accent: Color(0xFFD6C07F),
    secondaryAccent: Color(0xFF7E9A88),
    primaryText: Color(0xFFF2EEE3),
    secondaryText: Color(0xFFCBBE97),
  ),
  _CoverPalette(
    background: [Color(0xFF4A1F26), Color(0xFF2E1217)],
    accent: Color(0xFFE7C9A3),
    secondaryAccent: Color(0xFFB8717D),
    primaryText: Color(0xFFF8EFE7),
    secondaryText: Color(0xFFE2C4BB),
  ),
  _CoverPalette(
    background: [Color(0xFFE9EDF2), Color(0xFFD2DCE8)],
    accent: Color(0xFF2E4967),
    secondaryAccent: Color(0xFF8CA3BB),
    primaryText: Color(0xFF1F3044),
    secondaryText: Color(0xFF50667E),
  ),
];

List<Widget> _buildTemplateDecorations({
  required _CoverTemplate template,
  required _CoverPalette palette,
  required double width,
  required double height,
  required BorderRadius borderRadius,
}) {
  return switch (template) {
    _CoverTemplate.classic => <Widget>[
      Positioned(
        left: width * 0.08,
        top: height * 0.08,
        right: width * 0.08,
        bottom: height * 0.08,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: palette.accent.withValues(alpha: 0.14),
              width: 1.0,
            ),
          ),
        ),
      ),
      Positioned(
        top: height * 0.11,
        left: width * 0.12,
        child: Container(
          width: width * 0.26,
          height: 2,
          color: palette.secondaryAccent.withValues(alpha: 0.45),
        ),
      ),
    ],
    _CoverTemplate.band => <Widget>[
      Positioned(
        left: 0,
        top: height * 0.18,
        child: Container(
          width: width * 0.2,
          height: height * 0.64,
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(width * 0.12),
              bottomRight: Radius.circular(width * 0.12),
            ),
          ),
        ),
      ),
      Positioned(
        right: width * 0.08,
        top: height * 0.08,
        child: Container(
          width: width * 0.32,
          height: width * 0.32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
    ],
    _CoverTemplate.seal => <Widget>[
      Positioned(
        right: width * 0.11,
        top: height * 0.10,
        child: Transform.rotate(
          angle: -0.16,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: width * 0.05,
              vertical: height * 0.016,
            ),
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: palette.accent.withValues(alpha: 0.18)),
            ),
            child: Text(
              '藏书',
              style: TextStyle(
                color: palette.accent.withValues(alpha: 0.62),
                fontSize: (width * 0.07).clamp(7.0, 10.0),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
      Positioned(
        left: width * 0.10,
        bottom: height * 0.13,
        child: Container(
          width: width * 0.22,
          height: 2,
          color: palette.secondaryAccent.withValues(alpha: 0.38),
        ),
      ),
    ],
  };
}

Widget _buildTemplateHeader({
  required _CoverTemplate template,
  required _CoverPalette palette,
  required bool compact,
}) {
  return switch (template) {
    _CoverTemplate.classic => Row(
      children: [
        Expanded(
          child: Container(
            height: 1.2,
            color: palette.accent.withValues(alpha: 0.28),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '精选',
          style: TextStyle(
            color: palette.secondaryText,
            fontSize: compact ? 5.8 : 7.8,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ],
    ),
    _CoverTemplate.band => Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'SERIES',
          style: TextStyle(
            color: palette.secondaryText,
            fontSize: compact ? 5.8 : 7.4,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    ),
    _CoverTemplate.seal => Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'BOOK',
        style: TextStyle(
          color: palette.secondaryText,
          fontSize: compact ? 5.8 : 7.2,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    ),
  };
}
