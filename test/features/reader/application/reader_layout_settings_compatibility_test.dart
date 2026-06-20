import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_settings_compatibility.dart';

void main() {
  group('ReaderLayoutSettingsCompatibilityMatrix', () {
    test('tracks typography and geometry settings in layout signature', () {
      for (final key in <String>[
        'fontSize',
        'lineHeight',
        'paragraphSpacing',
        'paragraphIndent',
        'pagePadding',
        'fontIdentity',
        'textFullJustifyEnabled',
        'zhLayoutPolicy',
      ]) {
        expect(
          ReaderLayoutSettingsCompatibilityMatrix.isTrackedInLayoutSignature(
            key,
          ),
          isTrue,
          reason: key,
        );
      }
    });

    test(
      'keeps shell and page-turn owned settings out of layout signature',
      () {
        final shellOwned = ReaderLayoutSettingsCompatibilityMatrix.byStatus(
          ReaderLayoutSettingCompatibilityStatus.shellOwned,
        );
        final pageTurnOwned = ReaderLayoutSettingsCompatibilityMatrix.byStatus(
          ReaderLayoutSettingCompatibilityStatus.pageTurnDelegateFallback,
        );

        expect(
          shellOwned.map((item) => item.key),
          contains('backgroundBrightnessInfoBar'),
        );
        expect(
          pageTurnOwned.map((item) => item.key),
          contains('pageAnimationStyle'),
        );
      },
    );
  });
}
