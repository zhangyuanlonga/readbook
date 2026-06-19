import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_export_naming.dart';

void main() {
  test('theme bundle export filename normalizes unsafe characters', () {
    final theme = AppAdvancedTheme(
      id: 'theme_1',
      name: '  A/B:C*D?E"F<G>H|I  ',
      createdAt: DateTime.parse('2026-06-19T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-06-19T00:00:00.000Z'),
      lightConfig: AppAdvancedThemeModeConfig(),
      darkConfig: AppAdvancedThemeModeConfig(),
    );

    expect(
      AdvancedThemeExportNaming.themeBundleExportFileName(theme),
      'A_B_C_D_E_F_G_H_I.zip',
    );
    expect(
      AdvancedThemeExportNaming.normalizedExportFileName('   '),
      'advanced_theme',
    );
  });

  test('batch bundle export filename uses stable timestamp format', () {
    expect(
      AdvancedThemeExportNaming.themeBatchBundleExportFileName(
        now: DateTime(2026, 6, 9, 8, 7, 6),
      ),
      'advanced_themes_batch_20260609_080706.zip',
    );
  });
}
