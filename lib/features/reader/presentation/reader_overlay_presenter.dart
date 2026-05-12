import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

enum ReaderOverlayEdge { top, bottom }

class ReaderOverlaySnackbarDecision {
  const ReaderOverlaySnackbarDecision({
    required this.shouldShow,
    this.nextKey,
    this.nextAt,
  });

  final bool shouldShow;
  final String? nextKey;
  final DateTime? nextAt;
}

class ReaderOverlayPresenter {
  const ReaderOverlayPresenter();

  ReaderOverlaySnackbarDecision resolveSnackbarDecision({
    required String text,
    String? dedupeKey,
    required String? lastKey,
    required DateTime? lastAt,
    required Duration dedupeWindow,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final resolvedKey = (dedupeKey ?? text).trim();
    if (resolvedKey.isNotEmpty &&
        lastKey == resolvedKey &&
        lastAt != null &&
        current.difference(lastAt) < dedupeWindow) {
      return const ReaderOverlaySnackbarDecision(shouldShow: false);
    }
    return ReaderOverlaySnackbarDecision(
      shouldShow: true,
      nextKey: resolvedKey.isEmpty ? lastKey : resolvedKey,
      nextAt: resolvedKey.isEmpty ? lastAt : current,
    );
  }

  String chapterBoundaryMessage({required bool isFirst}) {
    return isFirst ? '已经是第一章。' : '已经是最后一章。';
  }

  double resolveProgressValue({
    required double currentRatio,
    double? draftRatio,
  }) {
    return (draftRatio ?? currentRatio).clamp(0.0, 1.0);
  }

  Widget buildShellOverlayTransition({
    required ReaderOverlayEdge edge,
    required double slideProgress,
    required double fadeProgress,
    required double collapsedScale,
    required double translateDistance,
    required Widget child,
  }) {
    final translateY =
        (edge == ReaderOverlayEdge.top ? -1 : 1) *
        (1 - slideProgress) *
        translateDistance;
    final scale = lerpDouble(collapsedScale, 1.0, slideProgress) ?? 1.0;
    return Transform.translate(
      offset: Offset(0, translateY),
      child: Opacity(
        opacity: fadeProgress,
        child: Transform.scale(scale: scale, child: child),
      ),
    );
  }
}
