class SessionCancellationHandle {
  const SessionCancellationHandle({required bool Function() isCancelled})
    : _isCancelled = isCancelled;

  final bool Function() _isCancelled;

  bool get isCancelled => _isCancelled();
}

class SessionTaskCancelledException implements Exception {
  const SessionTaskCancelledException([
    this.message = 'Session-bound task was cancelled.',
  ]);

  final String message;

  @override
  String toString() => 'SessionTaskCancelledException: $message';
}
