import 'dart:math';

import 'package:flutter/painting.dart';

import '../../../domain/entities/reader_settings.dart';

class ReaderTapZoneHit {
  const ReaderTapZoneHit({
    required this.rect,
    required this.row,
    required this.column,
    required this.index,
    required this.action,
  });

  final Rect rect;
  final int row;
  final int column;
  final int index;
  final ReaderTapZoneAction action;
}

class ReaderTapZoneResolver {
  const ReaderTapZoneResolver();

  Rect resolveRect({
    required Size viewportSize,
    required Rect contentRect,
    required EdgeInsets gestureInsets,
  }) {
    final leftGuard = max(
      ReaderTapZoneConstants.minimumHorizontalGuard,
      gestureInsets.left +
          viewportSize.width * ReaderTapZoneConstants.horizontalGuardRatio,
    );
    final rightGuard = max(
      ReaderTapZoneConstants.minimumHorizontalGuard,
      gestureInsets.right +
          viewportSize.width * ReaderTapZoneConstants.horizontalGuardRatio,
    );
    final topGuard = max(0.0, gestureInsets.top);
    final bottomGuard = max(0.0, gestureInsets.bottom);

    final left = max(leftGuard, contentRect.left);
    final top = max(topGuard, contentRect.top);
    final right = min(viewportSize.width - rightGuard, contentRect.right);
    final bottom = min(viewportSize.height - bottomGuard, contentRect.bottom);
    if (right <= left || bottom <= top) {
      return Rect.zero;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  ReaderTapZoneHit? resolveHit({
    required Offset localPosition,
    required Rect rect,
    required List<ReaderTapZoneAction> actions,
  }) {
    if (rect.isEmpty || !rect.contains(localPosition) || actions.isEmpty) {
      return null;
    }

    final usableWidth = max(1.0, rect.width);
    final usableHeight = max(1.0, rect.height);
    final normalizedDx = ((localPosition.dx - rect.left) / usableWidth).clamp(
      0.0,
      0.999999,
    );
    final normalizedDy = ((localPosition.dy - rect.top) / usableHeight).clamp(
      0.0,
      0.999999,
    );
    final column = (normalizedDx * 3).floor().clamp(0, 2);
    final row = (normalizedDy * 3).floor().clamp(0, 2);
    final index = (row * 3 + column).clamp(0, actions.length - 1);
    return ReaderTapZoneHit(
      rect: rect,
      row: row,
      column: column,
      index: index,
      action: actions[index],
    );
  }

  ReaderTapZoneHit? resolvePrimaryHit({
    required Offset localPosition,
    required Rect rect,
  }) {
    if (rect.isEmpty || !rect.contains(localPosition)) {
      return null;
    }

    final usableWidth = max(1.0, rect.width);
    final normalizedDx = ((localPosition.dx - rect.left) / usableWidth).clamp(
      0.0,
      0.999999,
    );
    if (normalizedDx < ReaderTapZoneConstants.sideActionWidthRatio) {
      return ReaderTapZoneHit(
        rect: rect,
        row: 1,
        column: 0,
        index: 3,
        action: ReaderTapZoneAction.previousPage,
      );
    }
    if (normalizedDx > 1 - ReaderTapZoneConstants.sideActionWidthRatio) {
      return ReaderTapZoneHit(
        rect: rect,
        row: 1,
        column: 2,
        index: 5,
        action: ReaderTapZoneAction.nextPage,
      );
    }
    return ReaderTapZoneHit(
      rect: rect,
      row: 1,
      column: 1,
      index: 4,
      action: ReaderTapZoneAction.toggleToolbar,
    );
  }
}

class ReaderTapZoneConstants {
  const ReaderTapZoneConstants._();

  static const double minimumHorizontalGuard = 22;
  static const double horizontalGuardRatio = 0.02;
  static const double sideActionWidthRatio = 0.3;
}
