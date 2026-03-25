import 'source_session.dart';

abstract class SessionManager {
  SourceSession sessionFor(String sourceId);
  Iterable<SourceSession> get activeSessions;
  void clearSource(String sourceId);
  void clearAll();
}

class InMemorySessionManager implements SessionManager {
  final Map<String, SourceSession> _sessions = <String, SourceSession>{};

  @override
  Iterable<SourceSession> get activeSessions => _sessions.values;

  @override
  SourceSession sessionFor(String sourceId) {
    return _sessions.putIfAbsent(
      sourceId,
      () => SourceSession(sourceId: sourceId),
    );
  }

  @override
  void clearSource(String sourceId) {
    _sessions.remove(sourceId);
  }

  @override
  void clearAll() {
    _sessions.clear();
  }
}
