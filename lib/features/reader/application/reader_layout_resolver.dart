import 'dart:math';

import 'package:flutter/rendering.dart';

import '../../../domain/entities/reader_settings.dart';
import 'reader_layout_metrics.dart';

class ReaderLayoutResolver {
  const ReaderLayoutResolver();

  EdgeInsets resolveBodyPadding(ReaderSettings settings) {
    return EdgeInsets.fromLTRB(
      _clampLayoutMargin(settings.bodyMarginLeft),
      _clampLayoutMargin(settings.bodyMarginTop),
      _clampLayoutMargin(settings.bodyMarginRight),
      _clampLayoutMargin(settings.bodyMarginBottom),
    );
  }

  EdgeInsets resolveInfoBarPadding(
    ReaderSettings settings, {
    required bool isHeader,
  }) {
    return EdgeInsets.fromLTRB(
      _clampLayoutMargin(
        isHeader
            ? settings.infoHeaderMarginLeft
            : settings.infoFooterMarginLeft,
      ),
      _clampLayoutMargin(
        isHeader ? settings.infoHeaderMarginTop : settings.infoFooterMarginTop,
      ),
      _clampLayoutMargin(
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
  }) {
    final bodyPadding = resolveBodyPadding(settings);
    return bodyPadding.copyWith(
      bottom: bodyPadding.bottom + safeInsets.bottom + extraBottomPadding,
    );
  }

  ReaderLayoutMetrics resolvePagedMetrics({
    required ReaderSettings settings,
    required Size viewportSize,
    required EdgeInsets safeInsets,
    required double pinnedHeaderHeight,
    required double bottomProgressReserve,
  }) {
    final bodyPadding = resolveBodyPadding(settings);
    final effectivePagePadding = bodyPadding.copyWith(
      bottom: bodyPadding.bottom + safeInsets.bottom + bottomProgressReserve,
    );
    final contentWidth = max(
      0.0,
      viewportSize.width - effectivePagePadding.horizontal,
    );
    final contentHeight = max(
      0.0,
      viewportSize.height - pinnedHeaderHeight - effectivePagePadding.vertical,
    );
    return ReaderLayoutMetrics(
      safeInsets: safeInsets,
      bodyPadding: bodyPadding,
      headerPadding: resolveInfoBarPadding(settings, isHeader: true),
      footerPadding: resolveInfoBarPadding(settings, isHeader: false),
      bottomProgressReserve: bottomProgressReserve,
      pinnedHeaderHeight: pinnedHeaderHeight,
      effectivePagePadding: effectivePagePadding,
      contentWidth: contentWidth,
      contentHeight: contentHeight,
    );
  }

  double _clampLayoutMargin(double value) {
    return value
        .clamp(ReaderSettings.minLayoutMargin, ReaderSettings.maxLayoutMargin)
        .toDouble();
  }
}
