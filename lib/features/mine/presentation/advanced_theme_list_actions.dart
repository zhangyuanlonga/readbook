import '../application/advanced_theme_service.dart';

enum AdvancedThemeAction { edit, duplicate, exportZip, delete }

enum AdvancedThemeListMoreAction {
  importBatch,
  sortThemes,
  floatingEdit,
  selectThemes,
}

enum AdvancedThemeExportDispatchStatus { completed, cancelled, failed }

class AdvancedThemeExportDispatchResult {
  const AdvancedThemeExportDispatchResult.completed({this.message})
    : status = AdvancedThemeExportDispatchStatus.completed;

  const AdvancedThemeExportDispatchResult.cancelled({this.message})
    : status = AdvancedThemeExportDispatchStatus.cancelled;

  const AdvancedThemeExportDispatchResult.failed({this.message})
    : status = AdvancedThemeExportDispatchStatus.failed;

  final AdvancedThemeExportDispatchStatus status;
  final String? message;

  bool get isCompleted => status == AdvancedThemeExportDispatchStatus.completed;
}

class AdvancedThemeDeleteDecision {
  const AdvancedThemeDeleteDecision({
    required this.confirmed,
    required this.deleteOptions,
  });

  final bool confirmed;
  final AdvancedThemeDeleteOptions deleteOptions;
}
