import '../../../domain/entities/app_advanced_theme.dart';

enum AdvancedThemeEditorValidationFocus { name, light, dark }

class AdvancedThemeEditorValidationResult {
  const AdvancedThemeEditorValidationResult._({
    required this.isValid,
    this.message,
    this.focus,
  });

  const AdvancedThemeEditorValidationResult.valid() : this._(isValid: true);

  const AdvancedThemeEditorValidationResult.invalid({
    required String message,
    required AdvancedThemeEditorValidationFocus focus,
  }) : this._(isValid: false, message: message, focus: focus);

  final bool isValid;
  final String? message;
  final AdvancedThemeEditorValidationFocus? focus;
}

/// 高级主题编辑保存前的业务校验。
///
/// 颜色文本框解析仍留在页面层，这里只判断保存 payload 的业务完整性，避免
/// flow 里散落校验文案，也方便后续把保存 payload 继续下沉。
class AdvancedThemeEditorValidationService {
  const AdvancedThemeEditorValidationService();

  AdvancedThemeEditorValidationResult validateSave({
    required String name,
    required AppAdvancedThemeColors lightColors,
    required AppAdvancedThemeColors darkColors,
  }) {
    if (name.trim().isEmpty) {
      return const AdvancedThemeEditorValidationResult.invalid(
        message: '请先填写主题名称',
        focus: AdvancedThemeEditorValidationFocus.name,
      );
    }
    if (lightColors.configuredColorCount == 0) {
      return const AdvancedThemeEditorValidationResult.invalid(
        message: '请先完成浅色配置',
        focus: AdvancedThemeEditorValidationFocus.light,
      );
    }
    if (darkColors.configuredColorCount == 0) {
      return const AdvancedThemeEditorValidationResult.invalid(
        message: '请先完成深色配置',
        focus: AdvancedThemeEditorValidationFocus.dark,
      );
    }
    return const AdvancedThemeEditorValidationResult.valid();
  }
}
