import 'package:flutter/animation.dart';

import '../../../domain/entities/reader_settings.dart';
import 'reader_session_state.dart';

class ReaderRenderMetrics {
  const ReaderRenderMetrics({
    this.pageCount = 0,
    this.currentPageIndex = 0,
    this.hasScrollClients = false,
    this.maxScrollExtent = 0,
    this.scrollOffset = 0,
  });

  final int pageCount;
  final int currentPageIndex;
  final bool hasScrollClients;
  final double maxScrollExtent;
  final double scrollOffset;
}

class ReaderRestorePlan {
  const ReaderRestorePlan({
    required this.normalizedRatio,
    this.pageIndex,
    this.scrollOffset,
    this.shouldDefer = false,
  });

  final double normalizedRatio;
  final int? pageIndex;
  final double? scrollOffset;
  final bool shouldDefer;
}

enum PagedTurnDecisionType { crossChapter, immediate, animated, curl }

class PagedAnimationMotionSpec {
  const PagedAnimationMotionSpec({
    required this.duration,
    required this.switchInCurve,
    required this.switchOutCurve,
  });

  final Duration duration;
  final Curve switchInCurve;
  final Curve switchOutCurve;
}

class PagedTurnDecision {
  const PagedTurnDecision({
    required this.type,
    required this.targetPageIndex,
    required this.animationStyle,
  });

  final PagedTurnDecisionType type;
  final int targetPageIndex;
  final ReaderPageAnimationStyle animationStyle;
}

abstract class TextReaderRenderer {
  const TextReaderRenderer();

  TextReaderRendererKind get kind;

  double captureProgress(ReaderRenderMetrics metrics);

  ReaderRestorePlan planRestore({
    required double ratio,
    required ReaderRenderMetrics metrics,
  });
}

class ScrollTextReaderRenderer extends TextReaderRenderer {
  const ScrollTextReaderRenderer();

  @override
  TextReaderRendererKind get kind => TextReaderRendererKind.scroll;

  @override
  double captureProgress(ReaderRenderMetrics metrics) {
    if (!metrics.hasScrollClients || metrics.maxScrollExtent <= 0) {
      return 0;
    }
    return (metrics.scrollOffset / metrics.maxScrollExtent).clamp(0.0, 1.0);
  }

  @override
  ReaderRestorePlan planRestore({
    required double ratio,
    required ReaderRenderMetrics metrics,
  }) {
    final normalizedRatio = ratio.clamp(0.0, 1.0);
    if (!metrics.hasScrollClients || metrics.maxScrollExtent <= 0) {
      return ReaderRestorePlan(
        normalizedRatio: normalizedRatio,
        scrollOffset: 0,
      );
    }
    return ReaderRestorePlan(
      normalizedRatio: normalizedRatio,
      scrollOffset: metrics.maxScrollExtent * normalizedRatio,
    );
  }
}

class PagedTextReaderRenderer extends TextReaderRenderer {
  const PagedTextReaderRenderer();

  @override
  TextReaderRendererKind get kind => TextReaderRendererKind.paged;

  @override
  double captureProgress(ReaderRenderMetrics metrics) {
    if (metrics.pageCount <= 1) {
      return 0;
    }
    return (metrics.currentPageIndex / (metrics.pageCount - 1)).clamp(0.0, 1.0);
  }

  @override
  ReaderRestorePlan planRestore({
    required double ratio,
    required ReaderRenderMetrics metrics,
  }) {
    final normalizedRatio = ratio.clamp(0.0, 1.0);
    if (metrics.pageCount <= 0) {
      return ReaderRestorePlan(
        normalizedRatio: normalizedRatio,
        shouldDefer: true,
      );
    }
    final pageIndex = (normalizedRatio * (metrics.pageCount - 1)).round().clamp(
      0,
      metrics.pageCount - 1,
    );
    return ReaderRestorePlan(
      normalizedRatio: normalizedRatio,
      pageIndex: pageIndex,
    );
  }

  ReaderPageAnimationStyle resolveAnimationStyle(ReaderSettings settings) {
    return settings.pageAnimationStyle;
  }

  PagedAnimationMotionSpec motionSpecForStyle(ReaderPageAnimationStyle style) {
    return switch (style) {
      ReaderPageAnimationStyle.curl => const PagedAnimationMotionSpec(
        duration: Duration(milliseconds: 700),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
      ),
      ReaderPageAnimationStyle.cover => const PagedAnimationMotionSpec(
        duration: Duration(milliseconds: 520),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
      ),
      ReaderPageAnimationStyle.translate => const PagedAnimationMotionSpec(
        duration: Duration(milliseconds: 430),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
      ),
      ReaderPageAnimationStyle.vertical => const PagedAnimationMotionSpec(
        duration: Duration(milliseconds: 460),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
      ),
      ReaderPageAnimationStyle.fade => const PagedAnimationMotionSpec(
        duration: Duration(milliseconds: 380),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
      ),
      ReaderPageAnimationStyle.none => const PagedAnimationMotionSpec(
        duration: Duration.zero,
        switchInCurve: Curves.linear,
        switchOutCurve: Curves.linear,
      ),
    };
  }

  PagedTurnDecision resolveTurnDecision({
    required int direction,
    required int currentPageIndex,
    required int pageCount,
    required ReaderSettings settings,
  }) {
    final animationStyle = resolveAnimationStyle(settings);
    if (pageCount <= 0 || direction == 0) {
      return PagedTurnDecision(
        type: PagedTurnDecisionType.immediate,
        targetPageIndex: 0,
        animationStyle: animationStyle,
      );
    }

    final safeDirection = direction >= 0 ? 1 : -1;
    final safeCurrentIndex = currentPageIndex.clamp(0, pageCount - 1);
    final targetPageIndex = safeCurrentIndex + safeDirection;
    if (targetPageIndex < 0 || targetPageIndex >= pageCount) {
      return PagedTurnDecision(
        type: PagedTurnDecisionType.crossChapter,
        targetPageIndex: safeCurrentIndex,
        animationStyle: animationStyle,
      );
    }

    if (animationStyle == ReaderPageAnimationStyle.curl) {
      return PagedTurnDecision(
        type: PagedTurnDecisionType.curl,
        targetPageIndex: targetPageIndex,
        animationStyle: animationStyle,
      );
    }
    if (animationStyle == ReaderPageAnimationStyle.none) {
      return PagedTurnDecision(
        type: PagedTurnDecisionType.immediate,
        targetPageIndex: targetPageIndex,
        animationStyle: animationStyle,
      );
    }
    return PagedTurnDecision(
      type: PagedTurnDecisionType.animated,
      targetPageIndex: targetPageIndex,
      animationStyle: animationStyle,
    );
  }
}
