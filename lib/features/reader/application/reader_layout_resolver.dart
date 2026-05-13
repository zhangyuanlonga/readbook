import 'dart:math';

import 'package:flutter/rendering.dart';

import '../../../domain/entities/reader_settings.dart';
import 'reader_surface_metrics.dart';

class ReaderLayoutResolver {
  const ReaderLayoutResolver();

  static const double desktopReadableContentMaxWidth = 720;

  bool showsPinnedChapterHeader(ReaderSettings settings) {
    return settings.showChapterHeader;
  }

  double resolveChapterHeaderTopSpacing(ReaderSettings settings) {
    return settings.chapterHeaderVerticalOffset
        .clamp(
          ReaderSettings.minChapterHeaderVerticalOffset,
          ReaderSettings.maxChapterHeaderSpacing,
        )
        .toDouble();
  }

  double resolveChapterHeaderBottomSpacing(ReaderSettings settings) {
    return 0;
  }

  EdgeInsets resolveBodyPadding(ReaderSettings settings) {
    final margins = settings.effectiveBodyMarginValues;
    return EdgeInsets.fromLTRB(
      _clampLayoutMargin(margins.left),
      _clampLayoutMargin(margins.top),
      _clampLayoutMargin(margins.right),
      _clampLayoutMargin(margins.bottom),
    );
  }

  EdgeInsets resolveInfoBarPadding(
    ReaderSettings settings, {
    required bool isHeader,
  }) {
    return EdgeInsets.fromLTRB(
      _clampInfoBarHorizontalMargin(
        isHeader: isHeader,
        value:
            isHeader
                ? settings.infoHeaderMarginLeft
                : settings.infoFooterMarginLeft,
      ),
      _clampLayoutMargin(
        isHeader ? settings.infoHeaderMarginTop : settings.infoFooterMarginTop,
      ),
      _clampInfoBarHorizontalMargin(
        isHeader: isHeader,
        value:
            isHeader
                ? settings.infoHeaderMarginRight
                : settings.infoFooterMarginRight,
      ),
      _clampLayoutMargin(
        isHeader
            ? settings.infoHeaderMarginBottom
            : settings.infoFooterMarginBottom,
      ),
    );
  }

  EdgeInsets resolveScrollableBodyPadding({
    required ReaderSettings settings,
    required EdgeInsets safeInsets,
    required double extraBottomPadding,
    double? maxContentWidth,
  }) {
    return resolveSurfaceMetrics(
      settings: settings,
      viewportSize: Size.zero,
      safeInsets: safeInsets,
      pinnedHeaderHeight: 0,
      scrollBottomReserve: extraBottomPadding,
      pagedBottomReserve: 0,
      maxContentWidth: maxContentWidth,
    ).scrollBodyPadding;
  }

  ReaderSurfaceMetrics resolveSurfaceMetrics({
    required ReaderSettings settings,
    required Size viewportSize,
    required EdgeInsets safeInsets,
    required double pinnedHeaderHeight,
    double pagedHeaderReserve = 0,
    required double scrollBottomReserve,
    required double pagedBottomReserve,
    double? maxContentWidth,
  }) {
    final bodyPadding = resolveBodyPadding(settings);
    final availableContentWidth = max(
      0.0,
      viewportSize.width - bodyPadding.horizontal,
    );
    final resolvedContentWidth =
        maxContentWidth == null || maxContentWidth <= 0
            ? availableContentWidth
            : min(availableContentWidth, maxContentWidth);
    final extraHorizontalInset = max(
      0.0,
      (availableContentWidth - resolvedContentWidth) / 2,
    );
    final effectivePagePadding = bodyPadding.copyWith(
      left: bodyPadding.left + extraHorizontalInset,
      right: bodyPadding.right + extraHorizontalInset,
    );
    final scrollBodyPadding = effectivePagePadding.copyWith(
      bottom:
          effectivePagePadding.bottom + safeInsets.bottom + scrollBottomReserve,
    );
    final contentWidth = resolvedContentWidth;
    final pagedFooterReserve = safeInsets.bottom + pagedBottomReserve;
    final contentHeight = max(
      0.0,
      viewportSize.height -
          pinnedHeaderHeight -
          pagedHeaderReserve -
          pagedFooterReserve -
          effectivePagePadding.vertical,
    );
    return ReaderSurfaceMetrics(
      viewportSize: viewportSize,
      safeInsets: safeInsets,
      bodyPadding: bodyPadding,
      headerPadding: resolveInfoBarPadding(settings, isHeader: true),
      footerPadding: resolveInfoBarPadding(settings, isHeader: false),
      scrollBodyPadding: scrollBodyPadding,
      pinnedHeaderHeight: pinnedHeaderHeight,
      pagedHeaderReserve: pagedHeaderReserve,
      pagedFooterReserve: pagedFooterReserve,
      bottomProgressReserve: pagedBottomReserve,
      effectivePagePadding: effectivePagePadding,
      contentRect: Rect.fromLTWH(
        effectivePagePadding.left,
        pinnedHeaderHeight + pagedHeaderReserve + effectivePagePadding.top,
        contentWidth,
        contentHeight,
      ),
      contentWidth: contentWidth,
      contentHeight: contentHeight,
    );
  }

  ReaderSurfaceMetrics resolvePagedMetrics({
    required ReaderSettings settings,
    required Size viewportSize,
    required EdgeInsets safeInsets,
    required double pinnedHeaderHeight,
    double pagedHeaderReserve = 0,
    required double bottomProgressReserve,
    double? maxContentWidth,
  }) {
    return resolveSurfaceMetrics(
      settings: settings,
      viewportSize: viewportSize,
      safeInsets: safeInsets,
      pinnedHeaderHeight: pinnedHeaderHeight,
      pagedHeaderReserve: pagedHeaderReserve,
      scrollBottomReserve: 0,
      pagedBottomReserve: bottomProgressReserve,
      maxContentWidth: maxContentWidth,
    );
  }

  double _clampLayoutMargin(double value) {
    return value
        .clamp(ReaderSettings.minLayoutMargin, ReaderSettings.maxLayoutMargin)
        .toDouble();
  }

  double _clampInfoBarHorizontalMargin({
    required bool isHeader,
    required double value,
  }) {
    final maxValue =
        isHeader
            ? ReaderSettings.maxLayoutMargin
            : ReaderSettings.maxInfoFooterHorizontalMargin;
    return value.clamp(ReaderSettings.minLayoutMargin, maxValue).toDouble();
  }
}
