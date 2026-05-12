import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/features/source/application/external_import_diagnostics.dart';
import 'package:shuxiang_reading_next/features/source/application/external_source_import_bridge.dart';

void main() {
  group('ExternalImportDiagnostics', () {
    test('builds read failure messages by payload type', () {
      expect(
        ExternalImportDiagnostics.readFailedMessage(
          ExternalImportPayloadType.scriptSource,
          'demo.js',
        ),
        '读取外部书源脚本失败：demo.js',
      );
      expect(
        ExternalImportDiagnostics.readFailedMessage(
          ExternalImportPayloadType.localBook,
          'demo.epub',
        ),
        '读取外部本地图书失败：demo.epub',
      );
    });

    test('builds import failure messages by payload type', () {
      expect(
        ExternalImportDiagnostics.importFailedMessage(
          ExternalImportPayloadType.scriptSource,
          '脚本语法错误',
          label: 'demo.js',
        ),
        '导入书源失败：脚本语法错误',
      );
      expect(
        ExternalImportDiagnostics.importFailedMessage(
          ExternalImportPayloadType.advancedTheme,
          '文件格式不支持',
        ),
        '导入主题失败：文件格式不支持',
      );
    });
  });
}
