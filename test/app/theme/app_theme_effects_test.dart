import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/theme/app_theme_effects.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';

void main() {
  test('advanced theme effect options expose labels and ambient configs', () {
    expect(
      appAdvancedThemeEffectOptions,
      containsAll(<AppAdvancedThemeEffect>[
        AppAdvancedThemeEffect.rain,
        AppAdvancedThemeEffect.snow,
        AppAdvancedThemeEffect.leaf,
        AppAdvancedThemeEffect.sakura,
        AppAdvancedThemeEffect.rose,
        AppAdvancedThemeEffect.whitePetal,
        AppAdvancedThemeEffect.wisteria,
        AppAdvancedThemeEffect.firefly,
      ]),
    );

    for (final effect in appAdvancedThemeEffectOptions) {
      expect(appAdvancedThemeEffectLabel(effect), isNotEmpty);
      if (effect == AppAdvancedThemeEffect.none) {
        expect(appAmbientEffectConfigFor(effect), isNull);
      } else {
        expect(appAmbientEffectConfigFor(effect), isNotNull);
        expect(appAmbientEffectConfigFor(effect, preview: true), isNotNull);
      }
    }
  });
}
