import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/paged_transition_controller.dart';
import 'package:shuxiang_reading_next/features/reader/application/text_reader_renderer.dart';

void main() {
  group('PagedTransitionController', () {
    const controller = PagedTransitionController();
    const renderer = PagedTextReaderRenderer();

    test('returns ignored action when a transition is already animating', () {
      final action = controller.planTurn(
        direction: 1,
        currentPageIndex: 2,
        pageCount: 8,
        settings: const ReaderSettings(),
        isAnimating: true,
        renderer: renderer,
      );

      expect(action.type, PagedTransitionActionType.ignored);
      expect(action.targetPageIndex, 2);
      expect(action.motion, isNull);
      expect(action.transitionState, isNull);
    });

    test('returns cross chapter action at page boundary', () {
      final action = controller.planTurn(
        direction: 1,
        currentPageIndex: 4,
        pageCount: 5,
        settings: const ReaderSettings(
          pageAnimationStyle: ReaderPageAnimationStyle.cover,
        ),
        isAnimating: false,
        renderer: renderer,
      );

      expect(action.type, PagedTransitionActionType.crossChapter);
      expect(action.targetPageIndex, 4);
      expect(action.motion, isNotNull);
      expect(action.transitionState, isNotNull);
      expect(action.transitionState!.isCrossChapter, isTrue);
      expect(action.transitionState!.fromIndex, 4);
      expect(action.transitionState!.toIndex, 4);
      expect(action.transitionState!.style, ReaderPageAnimationStyle.cover);
    });

    test('returns immediate action for none animation style', () {
      final action = controller.planTurn(
        direction: 1,
        currentPageIndex: 1,
        pageCount: 5,
        settings: const ReaderSettings(
          pageAnimationStyle: ReaderPageAnimationStyle.none,
        ),
        isAnimating: false,
        renderer: renderer,
      );

      expect(action.type, PagedTransitionActionType.immediate);
      expect(action.targetPageIndex, 2);
    });

    test('returns curl action for curl animation style', () {
      final action = controller.planTurn(
        direction: -1,
        currentPageIndex: 3,
        pageCount: 6,
        settings: const ReaderSettings(
          pageAnimationStyle: ReaderPageAnimationStyle.curl,
        ),
        isAnimating: false,
        renderer: renderer,
      );

      expect(action.type, PagedTransitionActionType.curl);
      expect(action.targetPageIndex, 2);
      expect(action.motion, isNull);
      expect(action.transitionState, isNull);
    });

    test('returns animated action with transition state and motion', () {
      final action = controller.planTurn(
        direction: -1,
        currentPageIndex: 3,
        pageCount: 7,
        settings: const ReaderSettings(
          pageAnimationStyle: ReaderPageAnimationStyle.fade,
        ),
        isAnimating: false,
        renderer: renderer,
      );

      expect(action.type, PagedTransitionActionType.animated);
      expect(action.targetPageIndex, 2);
      expect(action.motion, isNotNull);
      expect(action.transitionState, isNotNull);
      expect(action.transitionState!.isAnimating, isTrue);
      expect(action.transitionState!.direction, -1);
      expect(action.transitionState!.fromIndex, 3);
      expect(action.transitionState!.toIndex, 2);
      expect(action.transitionState!.style, ReaderPageAnimationStyle.fade);
    });

    test('completes animated transition into idle snapshot state', () {
      const state = PagedTransitionState(
        isAnimating: true,
        style: ReaderPageAnimationStyle.cover,
        direction: 1,
        fromIndex: 1,
        toIndex: 2,
      );

      final commit = controller.completeTransition(
        status: AnimationStatus.completed,
        state: state,
      );

      expect(commit, isNotNull);
      expect(commit!.nextPageIndex, 2);
      expect(commit.nextState.isAnimating, isFalse);
      expect(commit.nextState.fromIndex, 2);
      expect(commit.nextState.toIndex, 2);
      expect(commit.nextState.style, ReaderPageAnimationStyle.cover);
      expect(commit.nextState.direction, 1);
    });

    test('does not commit transition before completion', () {
      const state = PagedTransitionState(
        isAnimating: true,
        style: ReaderPageAnimationStyle.fade,
        direction: -1,
        fromIndex: 4,
        toIndex: 3,
      );

      final commit = controller.completeTransition(
        status: AnimationStatus.reverse,
        state: state,
      );

      expect(commit, isNull);
    });
  });
}
