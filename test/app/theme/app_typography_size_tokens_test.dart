import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/layout/app_size_tokens.dart';
import 'package:shuxiang_reading_next/app/theme/app_typography.dart';

void main() {
  test('AppTypography exposes app and reader text scale anchors', () {
    expect(AppTypography.bodyBase, 15);
    expect(AppTypography.bodyLarge, 16);
    expect(AppTypography.readerBodyDefaultMobile, 17);
    expect(AppTypography.readerBodyDefaultLargeScreen, 18);
    expect(AppTypography.capUiTextScale(2), 1.5);
    expect(AppTypography.capReaderChromeTextScale(0.6), 0.8);
  });

  test('AppSizeTokens exposes content width and touch target anchors', () {
    expect(AppSizeTokens.minTouchTarget, 44);
    expect(AppSizeTokens.clampTouchTarget(32), 44);
    expect(AppSizeTokens.defaultContentMaxWidthForWidth(390), double.infinity);
    expect(AppSizeTokens.defaultContentMaxWidthForWidth(600), 680);
    expect(AppSizeTokens.defaultContentMaxWidthForWidth(1200), 820);
    expect(AppSizeTokens.readerTextContentMaxWidth, 720);
  });
}
