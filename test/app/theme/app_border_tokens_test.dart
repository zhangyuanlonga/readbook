import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/app/theme/app_border_tokens.dart';
import 'package:shuxiang_reading_next/app/theme/app_theme_palette.dart';

void main() {
  test('default theme border tones stay ordered for pure white seed', () {
    final scheme = buildAppLightColorScheme(const Color(0xFFFFFFFF));

    final subtle = resolveAppBorderColor(
      scheme,
      tone: AppBorderTone.subtle,
      containerColor: scheme.surface,
    );
    final normal = resolveAppBorderColor(
      scheme,
      tone: AppBorderTone.defaultTone,
      containerColor: scheme.surface,
    );
    final strong = resolveAppBorderColor(
      scheme,
      tone: AppBorderTone.strong,
      containerColor: scheme.surface,
    );

    expect(subtle.toARGB32(), const Color(0xFFEBEBEB).toARGB32());
    expect(normal.toARGB32(), const Color(0xFFE6E6E6).toARGB32());
    expect(strong.toARGB32(), const Color(0xFFE0E2E6).toARGB32());
  });

  test(
    'custom border color keeps explicit base for default and strong tones',
    () {
      const baseColor = Color(0xFF7A5AF8);
      const containerColor = Color(0xFFF8F7FF);
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      );

      final subtle = resolveAppBorderColor(
        scheme,
        baseColor: baseColor,
        containerColor: containerColor,
        tone: AppBorderTone.subtle,
      );
      final normal = resolveAppBorderColor(
        scheme,
        baseColor: baseColor,
        containerColor: containerColor,
        tone: AppBorderTone.defaultTone,
      );
      final strong = resolveAppBorderColor(
        scheme,
        baseColor: baseColor,
        containerColor: containerColor,
        tone: AppBorderTone.strong,
      );

      expect(subtle, isNot(baseColor));
      expect(normal, baseColor);
      expect(strong, baseColor);
    },
  );
}
