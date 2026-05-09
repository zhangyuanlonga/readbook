import 'package:flutter/animation.dart';

import '../../../domain/entities/reader_document.dart';
import '../../../domain/entities/reader_settings.dart';
import 'text_reader_renderer.dart';

enum PagedTransitionActionType {
  ignored,
  crossChapter,
  curl,
  immediate,
  animated,
}

class PagedTransitionState {
  const PagedTransitionState({
    this.isAnimating = false,
    this.style = ReaderPageAnimationStyle.none,
    this.direction = 1,
    this.fromIndex = 0,
    this.toIndex = 0,
    this.isCrossChapter = false,
  });

  final bool isAnimating;
  final ReaderPageAnimationStyle style;
  final int direction;
  final int fromIndex;
  final int toIndex;
  final bool isCrossChapter;

  PagedTransitionState copyWith({
    bool? isAnimating,
    ReaderPageAnimationStyle? style,
    int? direction,
    int? fromIndex,
    int? toIndex,
    bool? isCrossChapter,
  }) {
    return PagedTransitionState(
      isAnimating: isAnimating ?? this.isAnimating,
      style: style ?? this.style,
      direction: direction ?? this.direction,
      fromIndex: fromIndex ?? this.fromIndex,
      toIndex: toIndex ?? this.toIndex,
      isCrossChapter: isCrossChapter ?? this.isCrossChapter,
    );
  }
}

class PagedTransitionAction {
  const PagedTransitionAction({
    required this.type,
    required this.targetPageIndex,
    this.motion,
    this.transitionState,
  });

  final PagedTransitionActionType type;
  final int targetPageIndex;
  final PagedAnimationMotionSpec? motion;
  final PagedTransitionState? transitionState;
}

class PagedTransitionCommit {
  const PagedTransitionCommit({
    required this.nextPageIndex,
    required this.nextState,
  });

  final int nextPageIndex;
  final PagedTransitionState nextState;
}

class PagedTransitionController {
  const PagedTransitionController();

  static const PagedTransitionState idleState = PagedTransitionState();

  PagedTransitionAction planTurn({
    required int direction,
    required int currentPageIndex,
    required int pageCount,
    required ReaderSettings settings,
    required bool isAnimating,
    required PagedTextReaderRenderer renderer,
    ReaderDocument? document,
  }) {
    if (isAnimating) {
      return PagedTransitionAction(
        type: PagedTransitionActionType.ignored,
        targetPageIndex: currentPageIndex,
      );
    }

    final safeDirection = direction >= 0 ? 1 : -1;
    final turnDecision = renderer.resolveTurnDecision(
      direction: safeDirection,
      currentPageIndex: currentPageIndex,
      pageCount: pageCount,
      settings: settings,
      document: document,
    );

    switch (turnDecision.type) {
      case PagedTurnDecisionType.crossChapter:
        final animationStyle = turnDecision.animationStyle;
        final motion =
            animationStyle == ReaderPageAnimationStyle.none
                ? null
                : renderer.motionSpecForStyle(animationStyle);
        return PagedTransitionAction(
          type: PagedTransitionActionType.crossChapter,
          targetPageIndex: turnDecision.targetPageIndex,
          motion: motion,
          transitionState:
              motion == null
                  ? null
                  : PagedTransitionState(
                    isAnimating: true,
                    style: animationStyle,
                    direction: safeDirection,
                    fromIndex: turnDecision.targetPageIndex,
                    toIndex: turnDecision.targetPageIndex,
                    isCrossChapter: true,
                  ),
        );
      case PagedTurnDecisionType.curl:
        return PagedTransitionAction(
          type: PagedTransitionActionType.curl,
          targetPageIndex: turnDecision.targetPageIndex,
        );
      case PagedTurnDecisionType.immediate:
        return PagedTransitionAction(
          type: PagedTransitionActionType.immediate,
          targetPageIndex: turnDecision.targetPageIndex,
        );
      case PagedTurnDecisionType.animated:
        final motion = renderer.motionSpecForStyle(turnDecision.animationStyle);
        return PagedTransitionAction(
          type: PagedTransitionActionType.animated,
          targetPageIndex: turnDecision.targetPageIndex,
          motion: motion,
          transitionState: PagedTransitionState(
            isAnimating: true,
            style: turnDecision.animationStyle,
            direction: safeDirection,
            fromIndex: currentPageIndex,
            toIndex: turnDecision.targetPageIndex,
          ),
        );
    }
  }

  PagedTransitionCommit? completeTransition({
    required AnimationStatus status,
    required PagedTransitionState state,
  }) {
    if (!state.isAnimating || status != AnimationStatus.completed) {
      return null;
    }

    final nextIndex = state.toIndex;
    return PagedTransitionCommit(
      nextPageIndex: nextIndex,
      nextState: PagedTransitionState(
        fromIndex: nextIndex,
        toIndex: nextIndex,
        style: state.style,
        direction: state.direction,
      ),
    );
  }
}
