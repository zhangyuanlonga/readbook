import '../../core/errors/error_stage.dart';
import '../../core/webview/interactive_verification_browser_executor.dart';
import '../../core/webview/webview_executor.dart';
import '../browser/browser_runtime.dart';
import '../session/source_session.dart';

class AppReadBrowserRuntime implements BrowserRuntime {
  AppReadBrowserRuntime({
    WebViewExecutor? webViewExecutor,
    InteractiveVerificationBrowserExecutor? interactiveExecutor,
    this.defaultStage = ErrorStage.unknown,
  }) : _webViewExecutor = webViewExecutor ?? WebViewExecutor(),
       _interactiveExecutor =
           interactiveExecutor ??
           InteractiveVerificationBrowserExecutor.instance;

  final WebViewExecutor _webViewExecutor;
  final InteractiveVerificationBrowserExecutor _interactiveExecutor;
  final ErrorStage defaultStage;

  @override
  Future<void> open(
    BrowserOpenRequest request, {
    SourceSession? session,
  }) async {
    final response = await _webViewExecutor.load(
      request: WebViewRequestPayload(
        url: request.uri.toString(),
        stage: defaultStage,
        sourceId: session?.sourceId,
        timeout: request.timeout,
      ),
    );
    _persistSnapshot(session, response);
  }

  @override
  Future<void> challenge(
    BrowserChallengeRequest request, {
    SourceSession? session,
  }) async {
    final response = await _interactiveExecutor.open(
      request: WebViewRequestPayload(
        url: request.uri.toString(),
        stage: defaultStage,
        sourceId: session?.sourceId,
        timeout: request.timeout,
      ),
      awaitUserResult: true,
      title: request.reason,
      refetchAfterSuccess: true,
    );
    _persistSnapshot(session, response);
  }

  @override
  Future<Object?> eval(
    BrowserEvalRequest request, {
    SourceSession? session,
  }) async {
    final response = await _webViewExecutor.load(
      request: WebViewRequestPayload(
        url: request.uri.toString(),
        stage: defaultStage,
        sourceId: session?.sourceId,
        timeout: request.timeout,
        webJs: request.script,
      ),
    );
    _persistSnapshot(session, response);
    return response.scriptResult;
  }

  void _persistSnapshot(
    SourceSession? session,
    WebViewResponsePayload response,
  ) {
    if (session == null) {
      return;
    }

    session.set('lastBrowserUrl', response.finalUrl);
    session.set('lastBrowserHtml', response.body);
    session.set('lastBrowserMatchedResourceUrl', response.matchedResourceUrl);
    session.set('lastBrowserMatchedOverrideUrl', response.matchedOverrideUrl);
    session.set('lastBrowserScriptResult', response.scriptResult);
    session.set('lastBrowserLocalStorage', const <String, String>{});
    session.set('lastBrowserSessionStorage', const <String, String>{});
  }
}
