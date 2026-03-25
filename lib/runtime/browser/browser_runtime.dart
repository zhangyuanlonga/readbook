import '../session/source_session.dart';

class BrowserChallengeRequest {
  const BrowserChallengeRequest({
    required this.uri,
    required this.reason,
    this.waitFor = const <String, Object?>{},
    this.timeout = const Duration(minutes: 2),
  });

  final Uri uri;
  final String reason;
  final Map<String, Object?> waitFor;
  final Duration timeout;
}

class BrowserOpenRequest {
  const BrowserOpenRequest({
    required this.uri,
    this.timeout = const Duration(minutes: 2),
  });

  final Uri uri;
  final Duration timeout;
}

class BrowserEvalRequest {
  const BrowserEvalRequest({
    required this.uri,
    required this.script,
    this.timeout = const Duration(seconds: 10),
  });

  final Uri uri;
  final String script;
  final Duration timeout;
}

abstract class BrowserRuntime {
  Future<void> open(BrowserOpenRequest request, {SourceSession? session});

  Future<void> challenge(
    BrowserChallengeRequest request, {
    SourceSession? session,
  });

  Future<Object?> eval(BrowserEvalRequest request, {SourceSession? session});
}

class UnsupportedBrowserRuntime implements BrowserRuntime {
  const UnsupportedBrowserRuntime({
    this.reason = 'Browser runtime is not configured.',
  });

  final String reason;

  @override
  Future<void> open(BrowserOpenRequest request, {SourceSession? session}) {
    return Future<void>.error(UnsupportedError(reason));
  }

  @override
  Future<void> challenge(
    BrowserChallengeRequest request, {
    SourceSession? session,
  }) {
    return Future<void>.error(UnsupportedError(reason));
  }

  @override
  Future<Object?> eval(BrowserEvalRequest request, {SourceSession? session}) {
    return Future<Object?>.error(UnsupportedError(reason));
  }
}
