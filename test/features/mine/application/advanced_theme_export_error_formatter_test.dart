import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_export_error_formatter.dart';

void main() {
  test('formats platform exception with message and details', () {
    final message = formatAdvancedThemeExportError(
      PlatformException(
        code: 'share_error',
        message: 'iOS 系统分享失败',
        details: 'sharePositionOrigin 不在当前视图范围内',
      ),
    );

    expect(message, 'iOS 系统分享失败（share_error）；详情：sharePositionOrigin 不在当前视图范围内');
  });

  test('formats file system exception with os error and path', () {
    final message = formatAdvancedThemeExportError(
      const FileSystemException(
        '写入文件失败',
        '/tmp/theme.zip',
        OSError('Operation not permitted', 1),
      ),
    );

    expect(message, '写入文件失败；Operation not permitted；路径：/tmp/theme.zip');
  });

  test('uses app exception brief message first', () {
    final message = formatAdvancedThemeExportError(
      const AppException(
        code: ErrorCode.unknown,
        stage: ErrorStage.unknown,
        briefMessage: '主题包生成失败',
      ),
    );

    expect(message, '主题包生成失败');
  });
}
