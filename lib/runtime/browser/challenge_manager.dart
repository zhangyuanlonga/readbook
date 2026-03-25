import '../session/source_session.dart';
import 'browser_runtime.dart';

class ChallengeManager {
  const ChallengeManager({required BrowserRuntime browserRuntime})
    : _browserRuntime = browserRuntime;

  final BrowserRuntime _browserRuntime;

  Future<void> runChallenge({
    required SourceSession session,
    required BrowserChallengeRequest request,
  }) {
    return _browserRuntime.challenge(request, session: session);
  }
}
