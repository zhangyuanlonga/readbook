import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../application/reader_desktop_input_resolver.dart';

class ReaderDesktopInputSnapshot {
  const ReaderDesktopInputSnapshot({
    required this.textSelectionActive,
    required this.editingText,
    required this.readerBusy,
    required this.overlayVisible,
    required this.autoReadSessionEnabled,
    required this.isPagedViewport,
    this.lastPageTurnAt,
  });

  final bool textSelectionActive;
  final bool editingText;
  final bool readerBusy;
  final bool overlayVisible;
  final bool autoReadSessionEnabled;
  final bool isPagedViewport;
  final DateTime? lastPageTurnAt;
}

class ReaderDesktopInputIntent {
  const ReaderDesktopInputIntent({
    required this.action,
    this.updateLastPageTurnAt = false,
  });

  final ReaderDesktopInputAction action;
  final bool updateLastPageTurnAt;
}

class ReaderDesktopInputDispatcher {
  const ReaderDesktopInputDispatcher({
    ReaderDesktopInputResolver resolver = const ReaderDesktopInputResolver(),
  }) : _resolver = resolver;

  final ReaderDesktopInputResolver _resolver;

  ReaderDesktopInputIntent resolveKeyIntent({
    required KeyEvent event,
    required ReaderDesktopInputSnapshot snapshot,
  }) {
    if (event is! KeyDownEvent) {
      return const ReaderDesktopInputIntent(
        action: ReaderDesktopInputAction.none,
      );
    }
    return ReaderDesktopInputIntent(
      action: _resolver.resolveKeyAction(
        event.logicalKey,
        textSelectionActive: snapshot.textSelectionActive,
        editingText: snapshot.editingText,
        readerBusy: snapshot.readerBusy,
        overlayVisible: snapshot.overlayVisible,
        autoReadSessionEnabled: snapshot.autoReadSessionEnabled,
      ),
    );
  }

  ReaderDesktopInputIntent resolvePointerSignalIntent({
    required PointerSignalEvent event,
    required ReaderDesktopInputSnapshot snapshot,
    required DateTime now,
  }) {
    if (event is! PointerScrollEvent) {
      return const ReaderDesktopInputIntent(
        action: ReaderDesktopInputAction.none,
      );
    }
    final action = _resolver.resolvePointerScrollAction(
      deltaY: event.scrollDelta.dy,
      isPagedViewport: snapshot.isPagedViewport,
      overlayVisible: snapshot.overlayVisible,
      textSelectionActive: snapshot.textSelectionActive,
      lastPageTurnAt: snapshot.lastPageTurnAt,
      now: now,
    );
    return ReaderDesktopInputIntent(
      action: action,
      updateLastPageTurnAt: action != ReaderDesktopInputAction.none,
    );
  }
}
