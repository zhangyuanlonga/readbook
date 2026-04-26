import 'dart:math';

import 'package:flutter/material.dart';

import '../application/reader_pagination_engine.dart';
import 'reader_paged_viewport_support.dart';

class ReaderPagedViewportController {
  const ReaderPagedViewportController();

  ReaderPagedViewportCurlState updateCurlPreviewProgress({
    required Size viewportSize,
    required bool isCurlAutoTurning,
    required double? swipeDragStartDx,
    required double? swipeDragCurrentDx,
    required int pageCount,
    required int currentPageIndex,
    required ReaderPagedViewportCurlState currentState,
    double startThreshold = 18,
  }) {
    if (isCurlAutoTurning) {
      return currentState;
    }

    final startDx = swipeDragStartDx;
    final currentDx = swipeDragCurrentDx;
    if (startDx == null || currentDx == null) {
      return currentState;
    }

    final delta = currentDx - startDx;
    if (delta.abs() < startThreshold) {
      if (currentState.isPreview) {
        return const ReaderPagedViewportCurlState();
      }
      return currentState;
    }

    if (pageCount <= 0) {
      return currentState;
    }

    final direction = delta < 0 ? 1 : -1;
    final clampedCurrentIndex = currentPageIndex.clamp(0, pageCount - 1);
    final targetIndex = clampedCurrentIndex + direction;
    if (targetIndex < 0 || targetIndex >= pageCount) {
      return currentState.isPreview
          ? const ReaderPagedViewportCurlState()
          : currentState;
    }

    final progress = (delta.abs() / max(viewportSize.width * 0.9, 1.0)).clamp(
      0.0,
      0.98,
    );
    if (currentState.isPreview &&
        currentState.direction == direction &&
        currentState.fromIndex == clampedCurrentIndex &&
        currentState.toIndex == targetIndex &&
        (progress - currentState.previewProgress).abs() < 0.01) {
      return currentState;
    }

    return ReaderPagedViewportCurlState(
      isPreview: true,
      direction: direction,
      fromIndex: clampedCurrentIndex,
      toIndex: targetIndex,
      previewProgress: progress,
    );
  }

  ReaderPagedViewportCurlState finishCurlPreview({
    required ReaderPagedViewportCurlState currentState,
    required bool commit,
  }) {
    if (!currentState.isPreview) {
      return currentState;
    }

    final progress = currentState.previewProgress.clamp(0.0, 1.0);
    if (progress <= 0) {
      return const ReaderPagedViewportCurlState();
    }

    return ReaderPagedViewportCurlState(
      isAnimating: true,
      direction: currentState.direction,
      fromIndex: currentState.fromIndex,
      toIndex: currentState.toIndex,
      previewProgress: progress,
      commitOnAnimationEnd: commit,
    );
  }

  ReaderPagedViewportCurlState resolveCurlAnimationStatus({
    required AnimationStatus status,
    required ReaderPagedViewportCurlState currentState,
    required int pageCount,
    required int currentPageIndex,
  }) {
    if (!currentState.isAnimating) {
      return currentState;
    }

    if (status == AnimationStatus.dismissed &&
        !currentState.commitOnAnimationEnd) {
      final safeIndex =
          pageCount <= 0 ? 0 : currentPageIndex.clamp(0, pageCount - 1);
      return ReaderPagedViewportCurlState(
        fromIndex: safeIndex,
        toIndex: safeIndex,
      );
    }

    if (status != AnimationStatus.completed ||
        !currentState.commitOnAnimationEnd) {
      return currentState;
    }

    if (pageCount <= 0) {
      return const ReaderPagedViewportCurlState();
    }

    final nextIndex = currentState.toIndex.clamp(0, pageCount - 1);
    return ReaderPagedViewportCurlState(
      fromIndex: nextIndex,
      toIndex: nextIndex,
    );
  }

  ReaderPagedViewportCurlState startAutoTurn({
    required int direction,
    required int currentPageIndex,
    required int pageCount,
  }) {
    final safeIndex = currentPageIndex.clamp(0, max(0, pageCount - 1)).toInt();
    return ReaderPagedViewportCurlState(
      isAnimating: true,
      direction: direction,
      fromIndex: safeIndex,
      toIndex: safeIndex + direction,
      commitOnAnimationEnd: true,
    );
  }

  ReaderPaginationEnsurePlan buildEnsurePlan({
    required ReaderPaginationEngine engine,
    required ReaderPaginationEnsureRequest request,
  }) {
    return engine.buildEnsurePlan(request);
  }

  List<ReaderPaginationParagraph> buildPaginationParagraphModels({
    required List<String> paragraphs,
    required ReaderPaginationParagraph Function(int index, String paragraph)
    paragraphBuilder,
  }) {
    return List<ReaderPaginationParagraph>.generate(
      paragraphs.length,
      (index) => paragraphBuilder(index, paragraphs[index]),
      growable: false,
    );
  }
}
