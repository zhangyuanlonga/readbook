import 'import_export_task_overlay.dart';

class ImportExportCopy {
  const ImportExportCopy._();

  static const String readingExternalFile = '正在读取外部文件并准备导入…';
  static const String importPreparing = '正在准备导入内容…';
  static const String importCompleted = '处理完成';
  static const String exportPreparing = '正在准备导出内容…';
  static const String shareLaunching = '正在打开系统分享…';

  static ImportExportTaskStatus running({
    required String title,
    required String message,
    String? detail,
    double? progress,
    String? progressLabel,
    ImportExportTaskPresentation presentation =
        ImportExportTaskPresentation.overlay,
  }) {
    return ImportExportTaskStatus(
      title: title,
      message: message,
      detail: detail,
      progress: progress,
      progressLabel: progressLabel,
      presentation: presentation,
      result: ImportExportTaskResult.running,
    );
  }

  static ImportExportTaskStatus success({
    required String title,
    required String message,
    String? detail,
    double? progress,
    String? progressLabel,
    ImportExportTaskPresentation presentation =
        ImportExportTaskPresentation.overlay,
  }) {
    return ImportExportTaskStatus(
      title: title,
      message: message,
      detail: detail,
      progress: progress,
      progressLabel: progressLabel,
      presentation: presentation,
      result: ImportExportTaskResult.success,
    );
  }

  static ImportExportTaskStatus failure({
    required String title,
    required String message,
    String? detail,
    ImportExportTaskPresentation presentation =
        ImportExportTaskPresentation.overlay,
  }) {
    return ImportExportTaskStatus(
      title: title,
      message: message,
      detail: detail,
      presentation: presentation,
      result: ImportExportTaskResult.failure,
    );
  }

  static ImportExportTaskStatus cancelled({
    required String title,
    required String message,
    String? detail,
    ImportExportTaskPresentation presentation =
        ImportExportTaskPresentation.overlay,
  }) {
    return ImportExportTaskStatus(
      title: title,
      message: message,
      detail: detail,
      presentation: presentation,
      result: ImportExportTaskResult.cancelled,
    );
  }
}
