import 'dart:math' as math;

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

    return TextStyle(
      color: color,
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      letterSpacing: settings.letterSpacing,
      fontWeight: _resolveFontWeight(settings.fontWeightLevel),
      fontFamily: _resolveFontFamily(settings),
      decoration:
          decorationEnabled ? TextDecoration.underline : TextDecoration.none,
      decorationStyle: _resolveDecorationStyle(decorationStyle),
      decorationColor:
          decorationEnabled
              ? Color(decorationColorValue ?? color.toARGB32())
              : null,
      decorationThickness:
          decorationEnabled
              ? _resolveDecorationThickness(settings.fontSize)
              : null,
    );
  }

  FontWeight _resolveFontWeight(ReaderFontWeightLevel level) {
    return switch (level) {
      ReaderFontWeightLevel.light => FontWeight.w400,
      ReaderFontWeightLevel.regular => FontWeight.w500,
      ReaderFontWeightLevel.medium => FontWeight.w600,
    };
  }

  String? _resolveFontFamily(ReaderSettings settings) {
    if (settings.fontSource == ReaderFontSource.system) {
      return null;
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

  double _resolveDecorationThickness(double fontSize) {
    return math.max(2.2, fontSize * 0.14);
  }
}
