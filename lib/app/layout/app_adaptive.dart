import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'app_layout.dart';

enum AppWindowClass { compact, medium, expanded }

enum AppDensity { compact, regular, comfortable }

class AppAdaptiveMetrics {
  const AppAdaptiveMetrics({
    required this.windowClass,
    required this.density,
    required this.size,
    required this.textScaleFactor,
    required this.pagePadding,
    required this.contentGap,
    required this.sectionGap,
    required this.cardPadding,
    required this.cardRadius,
    required this.listTileMinHeight,
    required this.controlHeight,
    required this.iconButtonSize,
    required this.chipHeight,
    required this.bottomSheetMaxWidth,
    required this.dialogMaxWidth,
    required this.gridMinItemWidth,
  });

  final AppWindowClass windowClass;
  final AppDensity density;
  final Size size;
  final double textScaleFactor;
  final double pagePadding;
  final double contentGap;
  final double sectionGap;
  final double cardPadding;
  final double cardRadius;
  final double listTileMinHeight;
  final double controlHeight;
  final double iconButtonSize;
  final double chipHeight;
  final double bottomSheetMaxWidth;
  final double dialogMaxWidth;
  final double gridMinItemWidth;

  double get width => size.width;
  double get height => size.height;
  bool get isLandscape => width > height;
  bool get isCompactWindow => windowClass == AppWindowClass.compact;
  bool get isMediumWindow => windowClass == AppWindowClass.medium;
  bool get isExpandedWindow => windowClass == AppWindowClass.expanded;
  bool get isCompactDensity => density == AppDensity.compact;

  static AppAdaptiveMetrics of(BuildContext context) {
    return resolve(context);
  }

  static AppAdaptiveMetrics resolve(BuildContext context) {
    return resolveForSize(
      size: AppLayout.viewportSize(context),
      textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
    );
  }

  static AppAdaptiveMetrics resolveForConstraints(
    BuildContext context,
    BoxConstraints constraints, {
    double? height,
  }) {
    final fallbackSize = AppLayout.viewportSize(context);
    final resolvedWidth =
        constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : fallbackSize.width;
    final resolvedHeight =
        height ??
        (constraints.hasBoundedHeight && constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : fallbackSize.height);
    return resolveForSize(
      size: Size(resolvedWidth, resolvedHeight),
      textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
    );
  }

  static AppAdaptiveMetrics resolveForSliver(
    BuildContext context,
    SliverConstraints constraints, {
    double? height,
  }) {
    final fallbackHeight = AppLayout.screenHeight(context);
    return resolveForSize(
      size: Size(constraints.crossAxisExtent, height ?? fallbackHeight),
      textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
    );
  }

  static AppAdaptiveMetrics resolveForSize({
    required Size size,
    double textScaleFactor = 1,
  }) {
    final width = size.width.clamp(0.0, 2400.0).toDouble();
    final height = size.height.clamp(0.0, 2400.0).toDouble();
    final windowClass = windowClassForWidth(width);
    final density = densityFor(
      width: width,
      height: height,
      textScaleFactor: textScaleFactor,
      windowClass: windowClass,
    );
    final base = _MetricSet.forDensity(density);
    final expanded = windowClass == AppWindowClass.expanded;
    final medium = windowClass == AppWindowClass.medium;

    return AppAdaptiveMetrics(
      windowClass: windowClass,
      density: density,
      size: Size(width, height),
      textScaleFactor: textScaleFactor,
      pagePadding:
          expanded
              ? math.max(base.pagePadding, 24)
              : medium
              ? math.max(base.pagePadding, 20)
              : base.pagePadding,
      contentGap: base.contentGap,
      sectionGap: base.sectionGap,
      cardPadding: base.cardPadding,
      cardRadius: base.cardRadius,
      listTileMinHeight: base.listTileMinHeight,
      controlHeight: base.controlHeight,
      iconButtonSize: base.iconButtonSize,
      chipHeight: base.chipHeight,
      bottomSheetMaxWidth:
          expanded
              ? 720
              : medium
              ? 640
              : math.max(0, width - base.pagePadding * 2),
      dialogMaxWidth:
          expanded
              ? 560
              : medium
              ? 520
              : math.max(0, width - base.pagePadding * 2),
      gridMinItemWidth:
          expanded
              ? 132
              : medium
              ? 124
              : density == AppDensity.compact
              ? 104
              : 112,
    );
  }

  static AppWindowClass windowClassForWidth(double width) {
    if (width >= AppLayout.expandedBreakpointWidth) {
      return AppWindowClass.expanded;
    }
    if (width >= AppLayout.mediumBreakpointWidth) {
      return AppWindowClass.medium;
    }
    return AppWindowClass.compact;
  }

  static AppWindowClass windowClassForBucket(AppWidthBucket bucket) {
    return switch (bucket) {
      AppWidthBucket.compact ||
      AppWidthBucket.largePhone ||
      AppWidthBucket.phoneXl => AppWindowClass.compact,
      AppWidthBucket.medium => AppWindowClass.medium,
      AppWidthBucket.expanded => AppWindowClass.expanded,
    };
  }

  static AppDensity densityFor({
    required double width,
    required double height,
    required double textScaleFactor,
    AppWindowClass? windowClass,
  }) {
    final resolvedWindowClass = windowClass ?? windowClassForWidth(width);
    final shortestSide = math.min(width, height);
    final isLandscape = width > height;
    if (width < AppLayout.largePhoneBreakpointWidth ||
        shortestSide < 360 ||
        height < 560 ||
        textScaleFactor >= 1.25 ||
        (isLandscape && height < 420)) {
      return AppDensity.compact;
    }
    if (resolvedWindowClass == AppWindowClass.expanded ||
        (resolvedWindowClass == AppWindowClass.medium &&
            height >= 720 &&
            textScaleFactor <= 1.1)) {
      return AppDensity.comfortable;
    }
    return AppDensity.regular;
  }

  int gridColumnsFor({
    double? availableWidth,
    double? minItemWidth,
    int minColumns = 1,
    int maxColumns = 8,
    double spacing = 0,
  }) {
    final width = (availableWidth ?? this.width).clamp(0.0, 2400.0).toDouble();
    final itemWidth = math.max(1.0, minItemWidth ?? gridMinItemWidth);
    final columns = ((width + spacing) / (itemWidth + spacing)).floor();
    return columns.clamp(minColumns, maxColumns).toInt();
  }
}

class _MetricSet {
  const _MetricSet({
    required this.pagePadding,
    required this.contentGap,
    required this.sectionGap,
    required this.cardPadding,
    required this.cardRadius,
    required this.listTileMinHeight,
    required this.controlHeight,
    required this.iconButtonSize,
    required this.chipHeight,
  });

  final double pagePadding;
  final double contentGap;
  final double sectionGap;
  final double cardPadding;
  final double cardRadius;
  final double listTileMinHeight;
  final double controlHeight;
  final double iconButtonSize;
  final double chipHeight;

  static _MetricSet forDensity(AppDensity density) {
    return switch (density) {
      AppDensity.compact => const _MetricSet(
        pagePadding: 12,
        contentGap: 8,
        sectionGap: 12,
        cardPadding: 12,
        cardRadius: 12,
        listTileMinHeight: 52,
        controlHeight: 36,
        iconButtonSize: 36,
        chipHeight: 32,
      ),
      AppDensity.regular => const _MetricSet(
        pagePadding: 16,
        contentGap: 10,
        sectionGap: 16,
        cardPadding: 14,
        cardRadius: 14,
        listTileMinHeight: 58,
        controlHeight: 40,
        iconButtonSize: 40,
        chipHeight: 36,
      ),
      AppDensity.comfortable => const _MetricSet(
        pagePadding: 20,
        contentGap: 12,
        sectionGap: 20,
        cardPadding: 16,
        cardRadius: 16,
        listTileMinHeight: 64,
        controlHeight: 44,
        iconButtonSize: 44,
        chipHeight: 38,
      ),
    };
  }
}
