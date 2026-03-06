import 'package:flutter/material.dart';

import '../../../domain/entities/reader_settings.dart';

class ReaderTypographyResolver {
  const ReaderTypographyResolver();

  TextStyle resolveBodyStyle({
    required ReaderSettings settings,
    required Color color,
  }) {
    return TextStyle(
      color: color,
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      letterSpacing: settings.letterSpacing,
      fontWeight: _resolveFontWeight(settings.fontWeightLevel),
      fontFamily: _resolveFontFamily(settings),
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
}
