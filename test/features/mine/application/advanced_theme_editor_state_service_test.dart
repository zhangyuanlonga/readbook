import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/theme/app_official_theme_presets.dart';
import 'package:shuxiang_reading_next/features/mine/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('new draft can be seeded from official theme mode configs', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(advancedThemeEditorStateServiceProvider);
    final preset = appOfficialThemePresetById(AppOfficialThemePresetId.lumina);

    final draft = service.createDraftFromModeConfigs(
      lightConfig: preset.lightConfig,
      darkConfig: preset.darkConfig,
    );

    expect(draft.lightConfig.colors.primaryColorValue, 0xFF1C1B1B);
    expect(draft.darkConfig.colors.surfaceColorValue, 0xFF151A20);
    expect(draft.lightConfig.componentStyle.buttonStyle.name, 'rounded');
  });
}
