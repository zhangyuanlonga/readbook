import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../../../domain/entities/app_advanced_theme.dart';
import '../../source/application/external_import_catalog.dart';
import '../application/advanced_theme_service.dart';
import 'advanced_theme_list_actions.dart';

class AdvancedThemeExportController {
  const AdvancedThemeExportController();

  bool get shouldUseSaveLocationPicker {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  Future<AdvancedThemeExportResult> exportThemeBundle({
    required AdvancedThemeService service,
    required AppAdvancedTheme theme,
    required Future<AdvancedThemeExportDispatchResult> Function({
      required File file,
      required String text,
      required String subject,
      String? clipboardText,
      ValueChanged<String>? onProgress,
    })
    shareExportedThemeFile,
    ValueChanged<String>? onProgress,
  }) async {
    onProgress?.call('正在准备导出主题包…');
    final fileName = service.themeBundleExportFileName(theme);
    String? successMessage;
    if (shouldUseSaveLocationPicker) {
      final location = await getSaveLocation(
        acceptedTypeGroups: const <XTypeGroup>[
          ExternalImportCatalog.advancedThemeZipTypeGroup,
        ],
        suggestedName: fileName,
        confirmButtonText: '导出',
      );
      if (location == null) {
        return const AdvancedThemeExportResult.cancelled(message: '已取消导出主题包');
      }
      final file = File(location.path);
      await service.writeThemeBundleZipFile(theme: theme, outputFile: file);
    } else {
      final file = await service.writeThemeBundleZipToTemporaryFile(theme);
      final shareResult = await shareExportedThemeFile(
        file: file,
        text: '分享主题包：${theme.name}',
        subject: theme.name,
        onProgress: onProgress,
      );
      if (!shareResult.isCompleted) {
        return AdvancedThemeExportResult.cancelled(
          message: shareResult.message ?? '已取消导出主题包',
        );
      }
      successMessage = shareResult.message;
    }
    return AdvancedThemeExportResult.completed(
      message: successMessage ?? '已导出主题包「${theme.name}」',
    );
  }

  Future<AdvancedThemeExportResult> exportThemeSummaries({
    required AdvancedThemeService service,
    required List<AdvancedThemeSummary> summaries,
    required Future<AdvancedThemeExportDispatchResult> Function({
      required File file,
      required String text,
      required String subject,
      String? clipboardText,
      ValueChanged<String>? onProgress,
    })
    shareExportedThemeFile,
    ValueChanged<String>? onProgress,
  }) async {
    final fileName = service.themeBatchBundleExportFileName();
    String? successMessage;
    if (shouldUseSaveLocationPicker) {
      final location = await getSaveLocation(
        acceptedTypeGroups: const <XTypeGroup>[
          ExternalImportCatalog.advancedThemeZipTypeGroup,
        ],
        suggestedName: fileName,
        confirmButtonText: '导出',
      );
      if (location == null) {
        return const AdvancedThemeExportResult.cancelled(message: '已取消批量导出');
      }
      final outputFile = File(location.path);
      await service.writeThemeBatchBundleFile(
        summaries: summaries,
        outputFile: outputFile,
        onProgress: onProgress,
      );
    } else {
      final outputFile = await service.writeThemeBatchBundleToTemporaryFile(
        summaries: summaries,
        onProgress: onProgress,
      );
      onProgress?.call('正在打开系统分享...');
      final shareResult = await shareExportedThemeFile(
        file: outputFile,
        text: '分享高级主题包，共 ${summaries.length} 个主题',
        subject: '高级主题批量导出',
      );
      if (!shareResult.isCompleted) {
        return AdvancedThemeExportResult.cancelled(
          message: shareResult.message ?? '已取消批量导出',
        );
      }
      successMessage = shareResult.message;
    }
    return AdvancedThemeExportResult.completed(
      message: successMessage ?? '已导出 ${summaries.length} 个主题',
    );
  }
}

enum AdvancedThemeExportResultStatus { completed, cancelled }

class AdvancedThemeExportResult {
  const AdvancedThemeExportResult.completed({required this.message})
    : status = AdvancedThemeExportResultStatus.completed;

  const AdvancedThemeExportResult.cancelled({required this.message})
    : status = AdvancedThemeExportResultStatus.cancelled;

  final AdvancedThemeExportResultStatus status;
  final String message;

  bool get isCompleted => status == AdvancedThemeExportResultStatus.completed;
}
