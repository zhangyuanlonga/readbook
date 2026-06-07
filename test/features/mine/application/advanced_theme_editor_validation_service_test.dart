import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_editor_validation_service.dart';

void main() {
  const service = AdvancedThemeEditorValidationService();

  group('AdvancedThemeEditorValidationService', () {
    test('rejects blank theme name', () {
      final result = service.validateSave(
        name: '  ',
        lightColors: _colors(),
        darkColors: _colors(),
      );

      expect(result.isValid, isFalse);
      expect(result.message, '请先填写主题名称');
      expect(result.focus, AdvancedThemeEditorValidationFocus.name);
    });

    test('rejects missing light or dark color config', () {
      final missingLight = service.validateSave(
        name: '主题',
        lightColors: const AppAdvancedThemeColors(),
        darkColors: _colors(),
      );
      final missingDark = service.validateSave(
        name: '主题',
        lightColors: _colors(),
        darkColors: const AppAdvancedThemeColors(),
      );

      expect(missingLight.focus, AdvancedThemeEditorValidationFocus.light);
      expect(missingLight.message, '请先完成浅色配置');
      expect(missingDark.focus, AdvancedThemeEditorValidationFocus.dark);
      expect(missingDark.message, '请先完成深色配置');
    });

    test('accepts complete save payload', () {
      final result = service.validateSave(
        name: '主题',
        lightColors: _colors(),
        darkColors: _colors(),
      );

      expect(result.isValid, isTrue);
      expect(result.message, isNull);
      expect(result.focus, isNull);
    });
  });
}

AppAdvancedThemeColors _colors() {
  return const AppAdvancedThemeColors(primaryColorValue: 0xFF123456);
}
