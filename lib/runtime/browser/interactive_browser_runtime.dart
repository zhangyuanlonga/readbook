import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../session/source_session.dart';
import 'browser_runtime.dart';

enum BrowserRuntimeTaskKind { challenge, eval }

class BrowserRuntimeTask {
  const BrowserRuntimeTask({
    required this.id,
    required this.kind,
    required this.session,
    this.challengeRequest,
    this.evalRequest,
  });

  final String id;
  final BrowserRuntimeTaskKind kind;
  final SourceSession? session;
  final BrowserChallengeRequest? challengeRequest;
  final BrowserEvalRequest? evalRequest;

  Uri get uri =>
      challengeRequest?.uri ?? evalRequest?.uri ?? Uri.parse('about:blank');
}

class InteractiveBrowserRuntime extends ChangeNotifier
    implements BrowserRuntime {
  final Queue<_PendingBrowserTask> _queue = Queue<_PendingBrowserTask>();
  _PendingBrowserTask? _active;
  int _counter = 0;

  BrowserRuntimeTask? get activeTask => _active?.task;

  bool get hasActiveTask => activeTask != null;

  int get queuedTaskCount => _queue.length + (_active == null ? 0 : 1);

  @override
  Future<void> open(
    BrowserOpenRequest request, {
    SourceSession? session,
  }) async {
    await _enqueue<void>(
      BrowserRuntimeTask(
        id: _nextTaskId(),
        kind: BrowserRuntimeTaskKind.challenge,
        session: session,
        challengeRequest: BrowserChallengeRequest(
          uri: request.uri,
          reason: 'open',
          timeout: request.timeout,
        ),
      ),
    );
  }

  @override
  Future<void> challenge(
    BrowserChallengeRequest request, {
    SourceSession? session,
  }) async {
    await _enqueue<void>(
      BrowserRuntimeTask(
        id: _nextTaskId(),
        kind: BrowserRuntimeTaskKind.challenge,
        session: session,
        challengeRequest: request,
      ),
    );
  }

  @override
  Future<Object?> eval(BrowserEvalRequest request, {SourceSession? session}) {
    return _enqueue<Object?>(
      BrowserRuntimeTask(
        id: _nextTaskId(),
        kind: BrowserRuntimeTaskKind.eval,
        session: session,
        evalRequest: request,
      ),
    );
  }

  void completeActive([Object? result]) {
    final current = _active;
    if (current == null) {
      return;
    }
    current.complete(result);
    _active = null;
    _promoteNext();
  }

  void failActive(Object error, [StackTrace? stackTrace]) {
    final current = _active;
    if (current == null) {
      return;
    }
    current.fail(error, stackTrace);
    _active = null;
    _promoteNext();
  }

  void cancelActive([String reason = 'Browser task cancelled.']) {
    failActive(StateError(reason));
  }

  Future<T> _enqueue<T>(BrowserRuntimeTask task) {
    final pending = _PendingBrowserTask<T>(task);
    _queue.addLast(pending);
    if (_active == null) {
      _promoteNext();
    }
    return pending.future;
  }

  void _promoteNext() {
    _active = _queue.isEmpty ? null : _queue.removeFirst();
    notifyListeners();
  }

  String _nextTaskId() {
    _counter += 1;
    return 'browser-task-$_counter';
  }
}

class _PendingBrowserTask<T> {
  _PendingBrowserTask(this.task);

  final BrowserRuntimeTask task;
  final Completer<T> _completer = Completer<T>();

  Future<T> get future => _completer.future;

  void complete(Object? result) {
    if (!_completer.isCompleted) {
      _completer.complete(result as T);
    }
  }

  void fail(Object error, [StackTrace? stackTrace]) {
    if (!_completer.isCompleted) {
      _completer.completeError(error, stackTrace);
    }
  }
}
