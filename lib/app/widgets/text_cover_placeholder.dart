import 'package:flutter/material.dart';

import '../theme/app_component_theme_tokens.dart';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = appComponentThemeTokensOf(context);
    final variant = _CoverVariant.values[hash % _CoverVariant.values.length];
    final palette = _CoverPalette.fromTheme(
      colorScheme: colorScheme,
      seed: hash,
      variant: variant,
    );
    final resolvedRadius = _resolveBorderRadius(borderRadius, tokens);
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
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      color: palette.primaryText.withValues(alpha: 0.88),
      fontWeight: FontWeight.w700,
      height: compact ? 1.1 : 1.14,
      fontSize:
          compact
              ? (resolvedWidth * 0.108).clamp(7.0, 8.8)
              : (resolvedWidth * 0.105).clamp(8.6, 12.4),
      letterSpacing: 0,
    );
    final authorStyle = theme.textTheme.labelSmall?.copyWith(
      color: palette.secondaryText.withValues(alpha: 0.78),
      fontWeight: FontWeight.w600,
      height: 1.05,
      fontSize: compact ? 6.4 : 8.0,
      letterSpacing: 0,
    );
    final contentPadding = EdgeInsets.fromLTRB(
      resolvedWidth * (compact ? 0.14 : 0.16),
      resolvedHeight * (compact ? 0.12 : 0.13),
      resolvedWidth * (compact ? 0.11 : 0.13),
      resolvedHeight * (compact ? 0.09 : 0.10),
    );

    return Container(
      width: resolvedWidth,
      height: resolvedHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: resolvedRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            palette.backgroundStart,
            palette.backgroundMid,
            palette.backgroundEnd,
          ],
          stops: const <double>[0, 0.52, 1],
        ),
        border: Border.all(
          color: palette.border,
          width: tokens.card.borderWidth.clamp(0.8, 1.4),
        ),
        boxShadow: <BoxShadow>[
          // UI-GOV-EXEMPT: box-shadow theme-generated-cover
          BoxShadow(
            color: colorScheme.shadow.withValues(
              alpha: tokens.card.shadowAlpha.clamp(0.08, 0.18),
            ),
            blurRadius: tokens.card.shadowBlur.clamp(8, 18),
            offset: Offset(0, tokens.card.shadowOffsetY.clamp(2, 6)),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: variant.glowAlignment,
                  radius: 1.15,
                  colors: <Color>[
                    palette.glow.withValues(alpha: 0.42),
                    palette.glow.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: (resolvedWidth * 0.105).clamp(5.0, 13.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.spine.withValues(alpha: 0.72),
                border: Border(
                  right: BorderSide(
                    color: palette.primaryText.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: resolvedWidth * 0.16,
            right: resolvedWidth * 0.13,
            top: resolvedHeight * 0.12,
            child: _CoverHeader(
              compact: compact,
              palette: palette,
              variant: variant,
            ),
          ),
          Positioned(
            right: -resolvedWidth * 0.20,
            bottom: -resolvedWidth * 0.26,
            child: Container(
              width: resolvedWidth * 0.64,
              height: resolvedWidth * 0.64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.primaryText.withValues(alpha: 0.032),
                  width: resolvedWidth * 0.045,
                ),
              ),
            ),
          ),
          Positioned(
            left: resolvedWidth * 0.16,
            right: resolvedWidth * 0.13,
            bottom: resolvedHeight * (showAuthor ? 0.11 : 0.12),
            child: _CoverFooter(
              label: showAuthor ? normalizedAuthor : '书享阅读',
              compact: compact,
              palette: palette,
              style: authorStyle,
            ),
          ),
          Padding(
            padding: contentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: compact ? 18 : 26),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      displayTitle,
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: titleStyle,
                    ),
                  ),
                ),
                SizedBox(height: compact ? 18 : 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static BorderRadius _resolveBorderRadius(
    BorderRadius requested,
    AppComponentThemeTokens tokens,
  ) {
    if (requested != const BorderRadius.all(Radius.circular(12))) {
      return requested;
    }
    return BorderRadius.circular(tokens.card.radius.clamp(8, 18));
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

enum _CoverVariant {
  calm(Alignment(-0.75, -0.82), 'LIBRARY'),
  vivid(Alignment(0.72, -0.68), 'BOOK'),
  quiet(Alignment(-0.20, 0.84), 'READ');

  const _CoverVariant(this.glowAlignment, this.label);

  final Alignment glowAlignment;
  final String label;
}

class _CoverPalette {
  const _CoverPalette({
    required this.backgroundStart,
    required this.backgroundMid,
    required this.backgroundEnd,
    required this.spine,
    required this.glow,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.accent,
  });

  final Color backgroundStart;
  final Color backgroundMid;
  final Color backgroundEnd;
  final Color spine;
  final Color glow;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final Color accent;

  factory _CoverPalette.fromTheme({
    required ColorScheme colorScheme,
    required int seed,
    required _CoverVariant variant,
  }) {
    final dark = colorScheme.brightness == Brightness.dark;
    final accent = switch (seed % 4) {
      0 => colorScheme.primary,
      1 => colorScheme.secondary,
      2 => colorScheme.tertiary,
      _ => colorScheme.primaryContainer,
    };
    final base = switch (variant) {
      _CoverVariant.calm => colorScheme.surfaceContainerHighest,
      _CoverVariant.vivid => colorScheme.primaryContainer,
      _CoverVariant.quiet => colorScheme.secondaryContainer,
    };
    final canvas = dark ? colorScheme.surfaceContainerLow : colorScheme.surface;
    final text = colorScheme.onSurface;
    final start = Color.alphaBlend(
      accent.withValues(alpha: dark ? 0.30 : 0.18),
      canvas,
    );
    final mid = Color.alphaBlend(
      base.withValues(alpha: dark ? 0.46 : 0.58),
      canvas,
    );
    final end = Color.alphaBlend(
      colorScheme.surfaceContainerHighest.withValues(alpha: dark ? 0.36 : 0.78),
      canvas,
    );
    return _CoverPalette(
      backgroundStart: start,
      backgroundMid: mid,
      backgroundEnd: end,
      spine: Color.alphaBlend(
        accent.withValues(alpha: dark ? 0.18 : 0.12),
        canvas,
      ),
      glow: accent,
      border: colorScheme.outlineVariant.withValues(alpha: dark ? 0.36 : 0.48),
      primaryText: text,
      secondaryText: colorScheme.onSurfaceVariant,
      accent: accent,
    );
  }
}

class _CoverHeader extends StatelessWidget {
  const _CoverHeader({
    required this.compact,
    required this.palette,
    required this.variant,
  });

  final bool compact;
  final _CoverPalette palette;
  final _CoverVariant variant;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 16,
          height: 2.4,
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      );
    }
    return Row(
      children: [
        Container(
          width: 20,
          height: 3.2,
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 1,
            color: palette.primaryText.withValues(alpha: 0.14),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          variant.label,
          style: TextStyle(
            color: palette.secondaryText.withValues(alpha: 0.72),
            fontSize: 7.4,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _CoverFooter extends StatelessWidget {
  const _CoverFooter({
    required this.label,
    required this.compact,
    required this.palette,
    required this.style,
  });

  final String label;
  final bool compact;
  final _CoverPalette palette;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: compact ? 3.8 : 4.8,
          height: compact ? 3.8 : 4.8,
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.62),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}
