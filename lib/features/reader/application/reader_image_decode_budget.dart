import 'dart:math' as math;

import 'reader_resource_budget.dart';

enum ReaderImageDecodeRole { epubInline, manga, cover }

class ReaderImageDecodeBudget {
  const ReaderImageDecodeBudget({
    required this.cacheWidth,
    required this.cacheHeight,
    required this.maxDataUriBytes,
    required this.imageCacheMaximumSize,
    required this.imageCacheMaximumSizeBytes,
  });

  final int? cacheWidth;
  final int? cacheHeight;
  final int maxDataUriBytes;
  final int imageCacheMaximumSize;
  final int imageCacheMaximumSizeBytes;
}

class ReaderImageDecodeBudgetResolver {
  const ReaderImageDecodeBudgetResolver();

  ReaderImageDecodeBudget resolve({
    required ReaderImageDecodeRole role,
    required ReaderResourceBudget resourceBudget,
    required double logicalWidth,
    double? logicalHeight,
    required double devicePixelRatio,
  }) {
    final roleScale = switch (role) {
      ReaderImageDecodeRole.epubInline => 1.0,
      ReaderImageDecodeRole.manga => 1.15,
      ReaderImageDecodeRole.cover => 0.75,
    };
    final targetWidth = _dimension(
      logicalWidth *
          devicePixelRatio *
          resourceBudget.imageDecodeScale *
          roleScale,
    );
    final targetHeight =
        logicalHeight == null
            ? null
            : _dimension(
              logicalHeight *
                  devicePixelRatio *
                  resourceBudget.imageDecodeScale *
                  roleScale,
            );
    final maxDataUriBytes = switch (role) {
      ReaderImageDecodeRole.epubInline => 3 * 1024 * 1024,
      ReaderImageDecodeRole.manga => 5 * 1024 * 1024,
      ReaderImageDecodeRole.cover => 1024 * 1024,
    };

    return ReaderImageDecodeBudget(
      cacheWidth: targetWidth,
      cacheHeight: targetHeight,
      maxDataUriBytes: maxDataUriBytes,
      imageCacheMaximumSize: resourceBudget.imageDecodeScale < 1 ? 80 : 140,
      imageCacheMaximumSizeBytes:
          resourceBudget.imageDecodeScale < 1
              ? 48 * 1024 * 1024
              : 96 * 1024 * 1024,
    );
  }

  int? _dimension(double value) {
    if (!value.isFinite || value <= 0) {
      return null;
    }
    return math.max(1, value.round()).clamp(1, 4096).toInt();
  }
}
