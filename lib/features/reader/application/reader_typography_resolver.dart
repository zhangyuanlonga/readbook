import 'package:flutter/material.dart';

import '../../../domain/entities/reader_settings.dart';

class ReaderTypographyResolver {
  const ReaderTypographyResolver();

  TextStyle resolveBodyStyle({
    required ReaderSettings settings,
    required Color color,
  }) {
    final decorationStyle = settings.bodyTextDecorationStyle;
    final decorationColorValue = settings.bodyTextDecorationColorValue;
    final decorationEnabled =
        decorationStyle != ReaderBodyTextDecorationStyle.none;
    final shadows =
        settings.bodyTextShadowEnabled
            ? <Shadow>[
              Shadow(
                color: Color(
                  settings.bodyTextShadowColorValue ?? color.toARGB32(),
                ),
                blurRadius: settings.bodyTextShadowBlurRadius,
                offset: Offset(
                  settings.bodyTextShadowOffsetDx,
                  settings.bodyTextShadowOffsetDy,
                ),
              ),
            ]
            : null;

    return TextStyle(
      color: color,
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      letterSpacing: settings.letterSpacing,
      fontWeight: _resolveFontWeight(settings),
      fontFamily: _resolveFontFamily(settings),
      fontStyle:
          settings.bodyTextItalicEnabled ? FontStyle.italic : FontStyle.normal,
      shadows: shadows,
      decoration: TextDecoration.none,
      decorationStyle: _resolveDecorationStyle(decorationStyle),
      decorationColor:
          decorationEnabled
              ? Color(decorationColorValue ?? color.toARGB32())
              : null,
      decorationThickness:
          decorationEnabled ? settings.bodyTextUnderlineThickness : null,
    );
  }

  FontWeight _resolveFontWeight(ReaderSettings settings) {
    final exactValue = settings.fontWeightValue;
    if (exactValue != null) {
      return FontWeight.values[(exactValue ~/ 100).clamp(1, 9) - 1];
    }
    return switch (settings.fontWeightLevel) {
      ReaderFontWeightLevel.light => FontWeight.w400,
      ReaderFontWeightLevel.regular => FontWeight.w500,
      ReaderFontWeightLevel.medium => FontWeight.w600,
    };
  }

  String? _resolveFontFamily(ReaderSettings settings) {
    if (settings.fontSource == ReaderFontSource.system) {
      return switch (settings.systemFontPreset) {
        ReaderSystemFontPreset.defaultSans => null,
        ReaderSystemFontPreset.serif => 'serif',
        ReaderSystemFontPreset.monospace => 'monospace',
      };
    }
    final family = settings.fontFamilyKey?.trim();
    if (family == null || family.isEmpty) {
      return null;
    }
    return family;
  }

  TextDecorationStyle _resolveDecorationStyle(
    ReaderBodyTextDecorationStyle style,
  ) {
    return switch (style) {
      ReaderBodyTextDecorationStyle.dashed => TextDecorationStyle.dashed,
      ReaderBodyTextDecorationStyle.solid ||
      ReaderBodyTextDecorationStyle.none => TextDecorationStyle.solid,
    };
  }
}
