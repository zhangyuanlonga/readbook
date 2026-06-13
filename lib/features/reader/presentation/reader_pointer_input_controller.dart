import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

typedef ReaderPointerTraceLogger =
    void Function(String step, {Map<String, Object?> context});

class ReaderPointerLongPressGuard {
  const ReaderPointerLongPressGuard({
    required this.mounted,
    required this.selectionActive,
  });

  final bool mounted;
  final bool selectionActive;
}

class ReaderPointerSwipeSnapshot {
  const ReaderPointerSwipeSnapshot({
    required this.startDx,
    required this.startDy,
    required this.currentDx,
    required this.currentDy,
  });

  final double startDx;
  final double startDy;
  final double currentDx;
  final double currentDy;

  double get dx => currentDx - startDx;
  double get dy => currentDy - startDy;
}

class ReaderPointerUpSnapshot {
  const ReaderPointerUpSnapshot({
    required this.pointer,
    required this.localPosition,
    required this.elapsedMs,
    required this.moved,
    required this.longPressTriggered,
    required this.childHandled,
    required this.swipe,
  });

  final int pointer;
  final Offset localPosition;
  final int elapsedMs;
  final bool moved;
  final bool longPressTriggered;
  final bool childHandled;
  final ReaderPointerSwipeSnapshot? swipe;

  double get dx => swipe?.dx ?? 0;
  double get dy => swipe?.dy ?? 0;
  double get velocity => elapsedMs <= 0 ? 0 : dx / (elapsedMs / 1000.0);
  bool get hasSwipeTracking => swipe != null;
}

/// Owns reader-level pointer bookkeeping so the page state only decides effects.
class ReaderPointerInputController {
  ReaderPointerInputController({DateTime Function()? now}) : _now = now;

  final DateTime Function()? _now;

  Timer? _longPressTimer;
  int? _pointerId;
  Offset? _downPosition;
  DateTime? _downTime;
  bool _moved = false;
  bool _longPressTriggered = false;
  bool _childHandled = false;
  double? _swipeStartDx;
  double? _swipeStartDy;
  double? _swipeCurrentDx;
  double? _swipeCurrentDy;

  DateTime _currentTime() => _now?.call() ?? DateTime.now();

  bool get hasActivePointer => _pointerId != null;
  bool get childHandled => _childHandled;
  bool get moved => _moved;
  bool get longPressTriggered => _longPressTriggered;

  ReaderPointerSwipeSnapshot? get swipeSnapshot {
    final startDx = _swipeStartDx;
    final startDy = _swipeStartDy;
    final currentDx = _swipeCurrentDx;
    final currentDy = _swipeCurrentDy;
    if (startDx == null ||
        startDy == null ||
        currentDx == null ||
        currentDy == null) {
      return null;
    }
    return ReaderPointerSwipeSnapshot(
      startDx: startDx,
      startDy: startDy,
      currentDx: currentDx,
      currentDy: currentDy,
    );
  }

  bool beginPointer(
    PointerDownEvent event, {
    required bool shouldHandleLongPress,
    required bool selectionActive,
    required ReaderPointerLongPressGuard Function() resolveLongPressGuard,
    required ReaderPointerTraceLogger logTrace,
    required VoidCallback onLongPress,
  }) {
    if (!isPrimaryPointerDown(event) || _pointerId != null) {
      return false;
    }
    _pointerId = event.pointer;
    _downPosition = event.localPosition;
    _downTime = _currentTime();
    _moved = false;
    _longPressTriggered = false;
    _childHandled = false;
    _longPressTimer?.cancel();
    logTrace(
      'pointer_down',
      context: <String, Object?>{
        'pointer': event.pointer,
        'dx': event.localPosition.dx.toStringAsFixed(1),
        'dy': event.localPosition.dy.toStringAsFixed(1),
        'shouldHandleLongPress': shouldHandleLongPress,
        'selectionActive': selectionActive,
      },
    );

    if (shouldHandleLongPress) {
      _longPressTimer = Timer(kLongPressTimeout, () {
        final guard = resolveLongPressGuard();
        final blocked =
            !guard.mounted ||
            _pointerId != event.pointer ||
            _moved ||
            _longPressTriggered ||
            guard.selectionActive ||
            _childHandled;
        logTrace(
          blocked ? 'timer_fire_blocked' : 'timer_fire',
          context: <String, Object?>{
            'pointer': event.pointer,
            'mounted': guard.mounted,
            'pointerMatches': _pointerId == event.pointer,
            'tapPointerMoved': _moved,
            'longPressTriggered': _longPressTriggered,
            'selectionActive': guard.selectionActive,
            'readerTapHandledByChild': _childHandled,
          },
        );
        if (blocked) {
          return;
        }
        _longPressTriggered = true;
        _childHandled = true;
        onLongPress();
      });
    }
    return true;
  }

  void startSwipe(Offset position) {
    _swipeStartDx = position.dx;
    _swipeStartDy = position.dy;
    _swipeCurrentDx = position.dx;
    _swipeCurrentDy = position.dy;
  }

  bool updatePointerMove(
    PointerMoveEvent event, {
    required ReaderPointerTraceLogger logTrace,
  }) {
    if (event.pointer != _pointerId) {
      return false;
    }
    _swipeCurrentDx = event.localPosition.dx;
    _swipeCurrentDy = event.localPosition.dy;
    final down = _downPosition;
    if (down != null && !_moved) {
      final distance = (event.localPosition - down).distance;
      if (distance > kTouchSlop) {
        _moved = true;
        _longPressTimer?.cancel();
        logTrace(
          'pointer_move_cancel_long_press',
          context: <String, Object?>{
            'pointer': event.pointer,
            'distance': distance.toStringAsFixed(2),
          },
        );
      }
    }
    return true;
  }

  bool isTrackedPointer(int pointer) => pointer == _pointerId;

  ReaderPointerUpSnapshot? buildPointerUpSnapshot(PointerUpEvent event) {
    if (event.pointer != _pointerId) {
      return null;
    }
    final downTime = _downTime;
    final elapsedMs =
        downTime == null
            ? 0
            : _currentTime().difference(downTime).inMilliseconds;
    return ReaderPointerUpSnapshot(
      pointer: event.pointer,
      localPosition: event.localPosition,
      elapsedMs: elapsedMs,
      moved: _moved,
      longPressTriggered: _longPressTriggered,
      childHandled: _childHandled,
      swipe: swipeSnapshot,
    );
  }

  void markChildHandled() {
    _childHandled = true;
  }

  void reset() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _pointerId = null;
    _downPosition = null;
    _downTime = null;
    _moved = false;
    _longPressTriggered = false;
    _childHandled = false;
    _swipeStartDx = null;
    _swipeStartDy = null;
    _swipeCurrentDx = null;
    _swipeCurrentDy = null;
  }

  void dispose() {
    reset();
  }

  static bool isPrimaryPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      return true;
    }
    return event.buttons == kPrimaryButton;
  }
}
