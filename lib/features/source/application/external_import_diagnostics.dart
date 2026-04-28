import '../../../core/logging/app_logger.dart';
import 'external_source_import_bridge.dart';

class ExternalImportDiagnostics {
  ExternalImportDiagnostics._();

  static final AppLogger _logger = AppLogger.instance;

  static String payloadLabel(ExternalImportPayloadType type) {
    return switch (type) {
      ExternalImportPayloadType.scriptSource => '书源脚本',
      ExternalImportPayloadType.localBook => '本地图书',
      ExternalImportPayloadType.advancedTheme => '主题文件',
      ExternalImportPayloadType.font => '字体文件',
    };
  }

  static String readFailedMessage(
    ExternalImportPayloadType type,
    String label,
  ) {
    return '读取外部${payloadLabel(type)}失败：$label';
  }

  static String importFailedMessage(
    ExternalImportPayloadType type,
    String detail, {
    String? label,
  }) {
    final prefix = switch (type) {
      ExternalImportPayloadType.scriptSource => '导入书源失败',
      ExternalImportPayloadType.localBook => '导入图书失败',
      ExternalImportPayloadType.advancedTheme => '导入主题失败',
      ExternalImportPayloadType.font => '导入字体失败',
    };
    final normalizedDetail = detail.trim();
    if (normalizedDetail.isEmpty) {
      return label == null ? prefix : '$prefix：$label';
    }
    return '$prefix：$normalizedDetail';
  }

  static void logPayloadQueued(IncomingExternalImportPayload payload) {
    _logger.info(
      'External import payload queued',
      context: _payloadContext(payload),
    );
  }

  static void logPayloadMalformed(Object? raw) {
    _logger.warn(
      'External import payload ignored',
      context: <String, Object?>{'raw': '$raw'},
    );
  }

  static void logNavigationScheduled(IncomingExternalImportPayload payload) {
    _logger.info(
      'External import navigation scheduled',
      context: _payloadContext(payload),
    );
  }

  static void logCacheFailed(IncomingExternalImportPayload payload) {
    _logger.warn(
      'External import cache failed',
      context: _payloadContext(payload),
    );
  }

  static void logImportUnsupported(
    ExternalImportPayloadType type,
    String label,
  ) {
    _logger.warn(
      'External import unsupported file',
      context: <String, Object?>{'type': type.name, 'label': label},
    );
  }

  static void logImportSucceeded(ExternalImportPayloadType type, String label) {
    _logger.info(
      'External import succeeded',
      context: <String, Object?>{'type': type.name, 'label': label},
    );
  }

  static void logImportFailed(
    ExternalImportPayloadType type,
    String label,
    Object error,
  ) {
    _logger.warn(
      'External import failed',
      context: <String, Object?>{
        'type': type.name,
        'label': label,
        'error': '$error',
      },
    );
  }

  static Map<String, Object?> _payloadContext(
    IncomingExternalImportPayload payload,
  ) {
    return <String, Object?>{
      'type': payload.type.name,
      'label': payload.label,
      'uri': payload.uri,
      'mimeType': payload.mimeType,
    };
  }
}
