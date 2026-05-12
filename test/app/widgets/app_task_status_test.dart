import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/widgets/app_task_status.dart';
import 'package:shuxiang_reading_next/app/widgets/import_export_task_overlay.dart';

void main() {
  test('AppTaskStatusData keeps nullable fields controllable via copyWith', () {
    const status = AppTaskStatusData(
      title: '正在重建索引',
      message: '正在解析章节',
      kind: AppTaskStatusKind.localBookReindex,
      progress: 0.5,
      progressLabel: '50%',
      detail: '第 10 章',
    );

    final updated = status.copyWith(
      progress: null,
      progressLabel: null,
      detail: null,
      result: AppTaskStatusResult.success,
    );

    expect(updated.title, '正在重建索引');
    expect(updated.kind, AppTaskStatusKind.localBookReindex);
    expect(updated.progress, isNull);
    expect(updated.progressLabel, isNull);
    expect(updated.detail, isNull);
    expect(updated.isFinished, isTrue);
  });

  test('ImportExportTaskStatus converts to and from unified task status', () {
    const importStatus = ImportExportTaskStatus(
      title: '正在导入字体',
      message: '正在复制字体文件',
      progress: 0.25,
      progressLabel: '1/4',
      detail: '校验文件',
      presentation: ImportExportTaskPresentation.inlineCompact,
      result: ImportExportTaskResult.running,
    );

    final appStatus = importStatus.toAppTaskStatusData(
      kind: AppTaskStatusKind.fontImport,
    );
    final converted = ImportExportTaskStatus.fromAppTaskStatus(
      appStatus.copyWith(result: AppTaskStatusResult.failure),
    );

    expect(appStatus.kind, AppTaskStatusKind.fontImport);
    expect(appStatus.presentation, AppTaskStatusPresentation.inlineCompact);
    expect(converted.title, importStatus.title);
    expect(converted.progress, importStatus.progress);
    expect(converted.result, ImportExportTaskResult.failure);
  });
}
