import 'package:flutter/foundation.dart';

enum AppTaskStatusKind {
  localBookImport,
  localBookReindex,
  galleryImport,
  themeImport,
  fontImport,
  sourceImport,
  cacheCleanup,
  logExport,
  sync,
  other,
}

enum AppTaskStatusPresentation { overlay, inlineCompact, queuePanel }

enum AppTaskStatusResult { idle, running, success, failure, cancelled }

@immutable
class AppTaskStatusData {
  const AppTaskStatusData({
    required this.title,
    required this.message,
    this.kind = AppTaskStatusKind.other,
    this.progress,
    this.progressLabel,
    this.detail,
    this.presentation = AppTaskStatusPresentation.overlay,
    this.result = AppTaskStatusResult.running,
  });

  final String title;
  final String message;
  final AppTaskStatusKind kind;
  final double? progress;
  final String? progressLabel;
  final String? detail;
  final AppTaskStatusPresentation presentation;
  final AppTaskStatusResult result;

  bool get isFinished =>
      result == AppTaskStatusResult.success ||
      result == AppTaskStatusResult.failure ||
      result == AppTaskStatusResult.cancelled;

  AppTaskStatusData copyWith({
    String? title,
    String? message,
    AppTaskStatusKind? kind,
    Object? progress = _sentinel,
    Object? progressLabel = _sentinel,
    Object? detail = _sentinel,
    AppTaskStatusPresentation? presentation,
    AppTaskStatusResult? result,
  }) {
    return AppTaskStatusData(
      title: title ?? this.title,
      message: message ?? this.message,
      kind: kind ?? this.kind,
      progress:
          identical(progress, _sentinel) ? this.progress : progress as double?,
      progressLabel:
          identical(progressLabel, _sentinel)
              ? this.progressLabel
              : progressLabel as String?,
      detail: identical(detail, _sentinel) ? this.detail : detail as String?,
      presentation: presentation ?? this.presentation,
      result: result ?? this.result,
    );
  }
}

const Object _sentinel = Object();
