class BookshelfInitialLoadController {
  Future<void>? _activeLoad;
  bool _reloadAfterActiveLoad = false;
  DateTime? _lastLoadRequestedAt;

  Future<void> load({
    required bool force,
    required bool Function() isMounted,
    required bool hasVisibleBooks,
    required Duration duplicateLoadCooldown,
    required Future<void> Function() runCore,
    required void Function(bool value) setCoverRefreshActive,
  }) {
    final inFlight = _activeLoad;
    if (inFlight != null) {
      if (!force) {
        return inFlight;
      }
      _reloadAfterActiveLoad = true;
      return inFlight.whenComplete(() async {
        if (!_reloadAfterActiveLoad) {
          return;
        }
        _reloadAfterActiveLoad = false;
        if (!isMounted()) {
          return;
        }
        await load(
          force: true,
          isMounted: isMounted,
          hasVisibleBooks: hasVisibleBooks,
          duplicateLoadCooldown: duplicateLoadCooldown,
          runCore: runCore,
          setCoverRefreshActive: setCoverRefreshActive,
        );
      });
    }

    if (!isMounted()) {
      return Future<void>.value();
    }

    final now = DateTime.now();
    if (!force) {
      final lastRequestAt = _lastLoadRequestedAt;
      if (lastRequestAt != null &&
          now.difference(lastRequestAt) < duplicateLoadCooldown) {
        return Future<void>.value();
      }
    }
    _lastLoadRequestedAt = now;

    final showCoverRefresh = force && hasVisibleBooks;
    if (showCoverRefresh) {
      setCoverRefreshActive(true);
    }

    final task = runCore();
    _activeLoad = task;
    return task.whenComplete(() {
      if (identical(_activeLoad, task)) {
        _activeLoad = null;
      }
      if (showCoverRefresh && isMounted()) {
        setCoverRefreshActive(false);
      }
    });
  }
}
