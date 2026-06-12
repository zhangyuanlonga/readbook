import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../domain/entities/reader_settings.dart';
import '../application/paged_transition_controller.dart';
import 'paged_animation/curl_paged_animation_renderer.dart';
import 'paged_animation/paged_animation_renderer_registry.dart';

typedef ReaderPagedViewportPageBuilder =
    Widget Function({
      required int pageIndex,
      required bool includeBackgroundDecoration,
    });

typedef ReaderPagedViewportWrapper = Widget Function(Widget child);

enum ReaderPagedViewportRenderMode {
  staticPage,
  animatedTransition,
  curlTransition,
  paperCurlSurface,
}

enum ReaderPagedViewportSelectionMode { enabled, disabled }

class ReaderPagedViewportInput {
  const ReaderPagedViewportInput({
    required this.chapterId,
    required this.pageIndex,
    required this.pageCount,
    required this.pageSize,
    required this.animationStyle,
    required this.viewportMetricsHash,
  });

  final String chapterId;
  final int pageIndex;
  final int pageCount;
  final Size pageSize;
  final ReaderPageAnimationStyle animationStyle;
  final int viewportMetricsHash;

  int get safePageIndex =>
      pageIndex.clamp(0, math.max(0, pageCount - 1)).toInt();

  bool get hasPages => pageCount > 0;

  bool isSamePagingSurface(ReaderPagedViewportInput other) {
    return chapterId == other.chapterId &&
        pageCount == other.pageCount &&
        pageSize == other.pageSize &&
        animationStyle == other.animationStyle &&
        viewportMetricsHash == other.viewportMetricsHash;
  }

  @override
  bool operator ==(Object other) {
    return other is ReaderPagedViewportInput && isSamePagingSurface(other);
  }

  @override
  int get hashCode {
    return Object.hash(
      chapterId,
      pageCount,
      pageSize,
      animationStyle,
      viewportMetricsHash,
    );
  }
}

class ReaderPagedViewportCurlState {
  const ReaderPagedViewportCurlState({
    this.isAnimating = false,
    this.isPreview = false,
    this.direction = 1,
    this.fromIndex = 0,
    this.toIndex = 0,
    this.previewProgress = 0,
    this.commitOnAnimationEnd = true,
    this.isCrossChapter = false,
  });

  static const idle = ReaderPagedViewportCurlState();

  final bool isAnimating;
  final bool isPreview;
  final int direction;
  final int fromIndex;
  final int toIndex;
  final double previewProgress;
  final bool commitOnAnimationEnd;
  final bool isCrossChapter;

  bool get isActive => isAnimating || isPreview;

  bool hasActiveTarget(int pageCount) {
    return isActive &&
        pageCount > 0 &&
        fromIndex >= 0 &&
        fromIndex < pageCount &&
        toIndex >= 0 &&
        toIndex < pageCount &&
        (fromIndex != toIndex || isCrossChapter);
  }

  double resolveProgress(Animation<double> animation) {
    final progress = isPreview ? previewProgress : animation.value;
    return progress.clamp(0.0, 1.0).toDouble();
  }
}

class ReaderPagedViewportTransitionPlan {
  const ReaderPagedViewportTransitionPlan({
    required this.pageCount,
    required this.safePageIndex,
    required this.renderedAnimationStyle,
    required this.renderMode,
    required this.selectionMode,
    required this.includeBackgroundDecorationOnPrimaryPage,
    this.fromPageIndex,
    this.toPageIndex,
    this.direction = 1,
  });

  final int pageCount;
  final int safePageIndex;
  final ReaderPageAnimationStyle renderedAnimationStyle;
  final ReaderPagedViewportRenderMode renderMode;
  final ReaderPagedViewportSelectionMode selectionMode;
  final bool includeBackgroundDecorationOnPrimaryPage;
  final int? fromPageIndex;
  final int? toPageIndex;
  final int direction;

  bool get disablesSelection =>
      selectionMode == ReaderPagedViewportSelectionMode.disabled;
}

class ReaderPagedViewportTransitionResolver {
  const ReaderPagedViewportTransitionResolver();

  ReaderPagedViewportTransitionPlan resolve({
    required ReaderPageAnimationStyle requestedAnimationStyle,
    required int pageCount,
    required int currentPageIndex,
    required PagedTransitionState pagedTransition,
    ReaderPagedViewportCurlState curlState = ReaderPagedViewportCurlState.idle,
  }) {
    final safePageIndex =
        currentPageIndex.clamp(0, math.max(0, pageCount - 1)).toInt();
    final renderedAnimationStyle =
        pagedTransition.isAnimating
            ? pagedTransition.style
            : requestedAnimationStyle;
    final selectionMode =
        renderedAnimationStyle == ReaderPageAnimationStyle.curl &&
                curlState.isActive
            ? ReaderPagedViewportSelectionMode.disabled
            : ReaderPagedViewportSelectionMode.enabled;

    if (renderedAnimationStyle == ReaderPageAnimationStyle.curl) {
      if (curlState.hasActiveTarget(pageCount)) {
        return ReaderPagedViewportTransitionPlan(
          pageCount: pageCount,
          safePageIndex: safePageIndex,
          renderedAnimationStyle: renderedAnimationStyle,
          renderMode: ReaderPagedViewportRenderMode.curlTransition,
          selectionMode: selectionMode,
          includeBackgroundDecorationOnPrimaryPage: false,
          fromPageIndex: curlState.fromIndex,
          toPageIndex: curlState.toIndex,
          direction: curlState.direction,
        );
      }
      return ReaderPagedViewportTransitionPlan(
        pageCount: pageCount,
        safePageIndex: safePageIndex,
        renderedAnimationStyle: renderedAnimationStyle,
        renderMode: ReaderPagedViewportRenderMode.staticPage,
        selectionMode: selectionMode,
        includeBackgroundDecorationOnPrimaryPage: false,
      );
    }

    if (renderedAnimationStyle == ReaderPageAnimationStyle.paperCurl) {
      return ReaderPagedViewportTransitionPlan(
        pageCount: pageCount,
        safePageIndex: safePageIndex,
        renderedAnimationStyle: renderedAnimationStyle,
        renderMode: ReaderPagedViewportRenderMode.paperCurlSurface,
        selectionMode: ReaderPagedViewportSelectionMode.disabled,
        includeBackgroundDecorationOnPrimaryPage: true,
      );
    }

    if (renderedAnimationStyle == ReaderPageAnimationStyle.none) {
      return ReaderPagedViewportTransitionPlan(
        pageCount: pageCount,
        safePageIndex: safePageIndex,
        renderedAnimationStyle: renderedAnimationStyle,
        renderMode: ReaderPagedViewportRenderMode.staticPage,
        selectionMode: selectionMode,
        includeBackgroundDecorationOnPrimaryPage: false,
      );
    }

    final hasActiveAnimatedTransition =
        pagedTransition.isAnimating &&
        pagedTransition.style == renderedAnimationStyle &&
        (pagedTransition.fromIndex != pagedTransition.toIndex ||
            pagedTransition.isCrossChapter) &&
        _isValidPageIndex(pagedTransition.fromIndex, pageCount) &&
        _isValidPageIndex(pagedTransition.toIndex, pageCount);

    if (hasActiveAnimatedTransition) {
      return ReaderPagedViewportTransitionPlan(
        pageCount: pageCount,
        safePageIndex: safePageIndex,
        renderedAnimationStyle: renderedAnimationStyle,
        renderMode: ReaderPagedViewportRenderMode.animatedTransition,
        selectionMode: selectionMode,
        includeBackgroundDecorationOnPrimaryPage: true,
        fromPageIndex: pagedTransition.fromIndex,
        toPageIndex: pagedTransition.toIndex,
        direction: pagedTransition.direction,
      );
    }

    return ReaderPagedViewportTransitionPlan(
      pageCount: pageCount,
      safePageIndex: safePageIndex,
      renderedAnimationStyle: renderedAnimationStyle,
      renderMode: ReaderPagedViewportRenderMode.staticPage,
      selectionMode: selectionMode,
      includeBackgroundDecorationOnPrimaryPage: true,
    );
  }

  bool _isValidPageIndex(int index, int pageCount) {
    return index >= 0 && index < pageCount;
  }
}

class ReaderPagedPageFrame extends StatelessWidget {
  const ReaderPagedPageFrame({
    super.key,
    required this.pageSize,
    required this.body,
    this.pinnedHeader,
    this.header,
    this.footer,
    this.backgroundDecoration,
    this.includeBackgroundDecoration = false,
  });

  final Size pageSize;
  final Widget body;
  final Widget? pinnedHeader;
  final Widget? header;
  final Widget? footer;
  final Decoration? backgroundDecoration;
  final bool includeBackgroundDecoration;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        if (pinnedHeader != null) pinnedHeader!,
        if (header != null) header!,
        Expanded(child: body),
        if (footer != null) footer!,
      ],
    );

    return SizedBox(
      width: pageSize.width,
      height: pageSize.height,
      child:
          includeBackgroundDecoration && backgroundDecoration != null
              ? DecoratedBox(decoration: backgroundDecoration!, child: content)
              : content,
    );
  }
}

class ReaderPagedViewportTransitionStack extends StatelessWidget {
  const ReaderPagedViewportTransitionStack({
    super.key,
    required this.plan,
    required this.pageBuilder,
    required this.pagedTransitionAnimation,
    required this.curlAnimation,
    required this.switchInCurve,
    this.selectionWrapper = _identityWrapper,
    this.disabledSelectionWrapper = _identityWrapper,
    this.animationRendererRegistry = const PagedAnimationRendererRegistry(),
    this.curlState = ReaderPagedViewportCurlState.idle,
    this.curlRenderer = const CurlPagedAnimationRenderer(),
    this.curlColors = const CurlRendererColors(
      backgroundColor: Color(0x00000000),
      dividerColor: Color(0x00000000),
      overlayColor: Color(0x00000000),
    ),
  });

  final ReaderPagedViewportTransitionPlan plan;
  final ReaderPagedViewportPageBuilder pageBuilder;
  final Animation<double> pagedTransitionAnimation;
  final Animation<double> curlAnimation;
  final Curve switchInCurve;
  final ReaderPagedViewportWrapper selectionWrapper;
  final ReaderPagedViewportWrapper disabledSelectionWrapper;
  final PagedAnimationRendererRegistry animationRendererRegistry;
  final ReaderPagedViewportCurlState curlState;
  final CurlPagedAnimationRenderer curlRenderer;
  final CurlRendererColors curlColors;

  @override
  Widget build(BuildContext context) {
    final pageStack = switch (plan.renderMode) {
      ReaderPagedViewportRenderMode.staticPage => _buildStaticPage(
        includeBackgroundDecoration:
            plan.includeBackgroundDecorationOnPrimaryPage,
      ),
      ReaderPagedViewportRenderMode.animatedTransition =>
        _buildAnimatedTransition(),
      ReaderPagedViewportRenderMode.curlTransition => _buildCurlTransition(),
      ReaderPagedViewportRenderMode.paperCurlSurface => _buildStaticPage(
        includeBackgroundDecoration:
            plan.includeBackgroundDecorationOnPrimaryPage,
      ),
    };

    return plan.disablesSelection
        ? disabledSelectionWrapper(pageStack)
        : selectionWrapper(pageStack);
  }

  Widget _buildStaticPage({required bool includeBackgroundDecoration}) {
    return KeyedSubtree(
      key: ValueKey<int>(plan.safePageIndex),
      child: pageBuilder(
        pageIndex: plan.safePageIndex,
        includeBackgroundDecoration: includeBackgroundDecoration,
      ),
    );
  }

  Widget _buildAnimatedTransition() {
    final fromPageIndex = plan.fromPageIndex;
    final toPageIndex = plan.toPageIndex;
    if (fromPageIndex == null || toPageIndex == null) {
      return _buildStaticPage(
        includeBackgroundDecoration:
            plan.includeBackgroundDecorationOnPrimaryPage,
      );
    }

    final fromPage = disabledSelectionWrapper(
      pageBuilder(pageIndex: fromPageIndex, includeBackgroundDecoration: true),
    );
    final toPage = disabledSelectionWrapper(
      pageBuilder(pageIndex: toPageIndex, includeBackgroundDecoration: true),
    );
    final effectRenderer = animationRendererRegistry.resolve(
      plan.renderedAnimationStyle,
    );

    return AnimatedBuilder(
      animation: pagedTransitionAnimation,
      builder: (context, _) {
        final progress = switchInCurve.transform(
          pagedTransitionAnimation.value.clamp(0.0, 1.0),
        );
        return effectRenderer.build(
          fromPage: fromPage,
          toPage: toPage,
          progress: progress,
          direction: plan.direction.toDouble(),
        );
      },
    );
  }

  Widget _buildCurlTransition() {
    final fromPageIndex = plan.fromPageIndex;
    final toPageIndex = plan.toPageIndex;
    if (fromPageIndex == null || toPageIndex == null) {
      return _buildStaticPage(includeBackgroundDecoration: false);
    }

    final targetPage = disabledSelectionWrapper(
      pageBuilder(pageIndex: toPageIndex, includeBackgroundDecoration: true),
    );
    final currentPage = disabledSelectionWrapper(
      pageBuilder(pageIndex: fromPageIndex, includeBackgroundDecoration: true),
    );

    return AnimatedBuilder(
      animation: curlAnimation,
      child: targetPage,
      builder: (context, child) {
        final progress = curlState.resolveProgress(curlAnimation);
        if (progress <= 0) {
          return currentPage;
        }
        return curlRenderer.build(
          currentPage: currentPage,
          targetPage: child ?? targetPage,
          progress: progress,
          direction: plan.direction,
          colors: curlColors,
        );
      },
    );
  }
}

Widget _identityWrapper(Widget child) => child;
