import '../application/advanced_theme_service.dart';

enum AdvancedThemeImportQueueItemStatus {
  pending,
  reading,
  parsing,
  importing,
  success,
  failure,
}

extension AdvancedThemeImportQueueItemStatusLabel
    on AdvancedThemeImportQueueItemStatus {
  String get label => switch (this) {
    AdvancedThemeImportQueueItemStatus.pending => '待处理',
    AdvancedThemeImportQueueItemStatus.reading => '读取文件',
    AdvancedThemeImportQueueItemStatus.parsing => '解析内容',
    AdvancedThemeImportQueueItemStatus.importing => '导入主题',
    AdvancedThemeImportQueueItemStatus.success => '导入完成',
    AdvancedThemeImportQueueItemStatus.failure => '导入失败',
  };
}

class AdvancedThemeImportQueueItem {
  const AdvancedThemeImportQueueItem({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    this.mimeType,
    this.status = AdvancedThemeImportQueueItemStatus.pending,
    this.detail,
  });

  final String path;
  final String fileName;
  final int sizeBytes;
  final String? mimeType;
  final AdvancedThemeImportQueueItemStatus status;
  final String? detail;

  AdvancedThemeImportQueueItem copyWith({
    AdvancedThemeImportQueueItemStatus? status,
    String? detail,
    bool clearDetail = false,
  }) {
    return AdvancedThemeImportQueueItem(
      path: path,
      fileName: fileName,
      sizeBytes: sizeBytes,
      mimeType: mimeType,
      status: status ?? this.status,
      detail: clearDetail ? null : (detail ?? this.detail),
    );
  }
}

typedef AdvancedThemeQueueImportProgressCallback =
    void Function(AdvancedThemeImportQueueItemStatus status, String message);

typedef AdvancedThemeBatchFileImportRunner =
    Future<AdvancedThemeBatchImportSummary> Function({
      required String path,
      String? mimeType,
      AdvancedThemeQueueImportProgressCallback? onProgress,
    });

class AdvancedThemeBatchImportController {
  const AdvancedThemeBatchImportController();

  AdvancedThemeImportQueueItemStatus statusForProgressStage(
    AdvancedThemeImportProgressStage stage,
  ) {
    return switch (stage) {
      AdvancedThemeImportProgressStage.reading =>
        AdvancedThemeImportQueueItemStatus.reading,
      AdvancedThemeImportProgressStage.parsing =>
        AdvancedThemeImportQueueItemStatus.parsing,
      AdvancedThemeImportProgressStage.importing =>
        AdvancedThemeImportQueueItemStatus.importing,
    };
  }

  Future<AdvancedThemeBatchImportSummary> importThemeBatchFile({
    required AdvancedThemeService service,
    required String path,
    String? mimeType,
    AdvancedThemeQueueImportProgressCallback? onProgress,
    String Function(String message)? normalizeProgressMessage,
  }) {
    return service.importThemeBatchFile(
      path: path,
      mimeType: mimeType,
      onProgress: (stage, message) {
        onProgress?.call(
          statusForProgressStage(stage),
          normalizeProgressMessage?.call(message) ?? message,
        );
      },
    );
  }
}
