import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_appread/app/theme/app_theme.dart';

void main() {
  test('AppTheme input decoration is transparent by default', () {
    final theme = AppTheme.build(
      ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
    );

    expect(theme.inputDecorationTheme.filled, isFalse);
    expect(theme.inputDecorationTheme.fillColor, Colors.transparent);
    expect(theme.inputDecorationTheme.enabledBorder, isNotNull);
    expect(theme.inputDecorationTheme.focusedBorder, isNotNull);
  });
}
