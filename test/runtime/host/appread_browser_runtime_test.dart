import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/core/webview/interactive_verification_browser_executor.dart';
import 'package:shuxiang_reading_next/core/webview/webview_executor.dart';
import 'package:shuxiang_reading_next/runtime/browser/browser_runtime.dart';
import 'package:shuxiang_reading_next/runtime/host/appread_browser_runtime.dart';
import 'package:shuxiang_reading_next/runtime/session/source_session.dart';

void main() {
  test('syncs cookies between session and browser runtime on open', () async {
    final session = SourceSession(sourceId: 'source_69');
    session.setCookie(
      'sid',
      'abc123',
      uri: Uri.parse('https://www.69hao.com/search'),
    );
    session.setCookie(
      'offsite',
      'skip-me',
      uri: Uri.parse('https://other.example.com/'),
    );
    final cookieSynchronizer = _FakeBrowserCookieSynchronizer(
      browserCookies: <SourceCookie>[
        const SourceCookie(
          name: 'cf_clearance',
          value: 'passed-token',
          domain: '.69hao.com',
          path: '/',
        ),
      ],
    );
    final response = WebViewResponsePayload(
      statusCode: 200,
      body: '<html>ok</html>',
      finalUrl: 'https://www.69hao.com/search',
    );
    final runtime = AppReadBrowserRuntime(
      webViewExecutor: _FakeWebViewExecutor(response),
      interactiveExecutor: _FakeInteractiveExecutor(response),
      cookieSynchronizer: cookieSynchronizer,
      defaultStage: ErrorStage.search,
    );

    await runtime.open(
      BrowserOpenRequest(uri: Uri.parse('https://www.69hao.com/search')),
      session: session,
    );

    expect(
      cookieSynchronizer.syncedSessionCookies,
      containsPair('sid', 'abc123'),
    );
    expect(cookieSynchronizer.syncedSessionCookies, isNot(contains('offsite')));
    expect(
      cookieSynchronizer.syncedSessionToBrowserUri?.toString(),
      'https://www.69hao.com/search',
    );
    expect(
      cookieSynchronizer.syncedBrowserToSessionUri?.toString(),
      'https://www.69hao.com/search',
    );
    expect(session.cookies['cf_clearance'], 'passed-token');
    expect(
      session.cookieHeaderForUri(Uri.parse('https://www.69hao.com/search')),
      contains('cf_clearance=passed-token'),
    );
    expect(
      session.cookieHeaderForUri(Uri.parse('https://sub.69hao.com/search')),
      contains('cf_clearance=passed-token'),
    );
    expect(
      session.cookieHeaderForUri(Uri.parse('https://sub.69hao.com/search')),
      isNot(contains('sid=abc123')),
    );
    expect(
      session.get<String>('lastBrowserUrl'),
      'https://www.69hao.com/search',
    );
    expect(session.get<String>('lastBrowserHtml'), '<html>ok</html>');
  });

  test('serializes browser operations across concurrent calls', () async {
    final session = SourceSession(sourceId: 'source_parallel');
    final gate = _SequencedGate();
    final webViewExecutor = _QueuedFakeWebViewExecutor(gate);
    final interactiveExecutor = _QueuedFakeInteractiveExecutor(gate);
    final runtime = AppReadBrowserRuntime(
      webViewExecutor: webViewExecutor,
      interactiveExecutor: interactiveExecutor,
      cookieSynchronizer: _FakeBrowserCookieSynchronizer(
        browserCookies: const [],
      ),
      defaultStage: ErrorStage.search,
    );

    final firstOpen = runtime.open(
      BrowserOpenRequest(uri: Uri.parse('https://example.com/open')),
      session: session,
    );
    final secondEval = runtime.eval(
      BrowserEvalRequest(
        uri: Uri.parse('https://example.com/eval'),
        script: '1+1',
      ),
      session: session,
    );
    final thirdChallenge = runtime.challenge(
      BrowserChallengeRequest(
        uri: Uri.parse('https://example.com/challenge'),
        reason: 'captcha',
      ),
      session: session,
    );

    await gate.waitUntilStartedCount(1);
    expect(gate.maxConcurrent, 1);
    gate.completeNext();

    await gate.waitUntilStartedCount(2);
    expect(gate.maxConcurrent, 1);
    gate.completeNext();

    await gate.waitUntilStartedCount(3);
    expect(gate.maxConcurrent, 1);
    gate.completeNext();

    await Future.wait<void>([firstOpen, thirdChallenge]);
    await secondEval;
    expect(gate.maxConcurrent, 1);
  });

  test('keeps host-only cookies host-only when syncing to webview', () async {
    final platform = _RecordingPlatformCookieManager();
    final synchronizer = InAppWebViewCookieSynchronizer(
      cookieManager: CookieManager.fromPlatform(platform),
    );
    final session = SourceSession(sourceId: 'source_69');
    final expiresAt = DateTime.utc(2037, 10, 21, 7, 28);
    session.setCookie(
      'hostOnly',
      'abc123',
      uri: Uri.parse('https://www.69hao.com/books'),
      path: '/books',
    );
    session.setCookie(
      'shared',
      'passed-token',
      domain: '.69hao.com',
      path: '/books',
      expiresAt: expiresAt,
      isSecure: true,
      isHttpOnly: true,
    );

    await synchronizer.syncSessionToBrowser(
      uri: Uri.parse('https://www.69hao.com/books'),
      session: session,
    );

    final hostOnlyCall = platform.setCookieCalls.firstWhere(
      (_RecordedSetCookieCall call) => call.name == 'hostOnly',
    );
    final sharedCall = platform.setCookieCalls.firstWhere(
      (_RecordedSetCookieCall call) => call.name == 'shared',
    );

    expect(hostOnlyCall.domain, isNull);
    expect(hostOnlyCall.path, '/books');
    expect(sharedCall.domain, '69hao.com');
    expect(sharedCall.path, '/books');
    expect(sharedCall.expiresDate, expiresAt.millisecondsSinceEpoch);
    expect(sharedCall.isSecure, isTrue);
    expect(sharedCall.isHttpOnly, isTrue);
  });

  test('rejects interactive challenge when session disallows it', () async {
    final session = SourceSession(sourceId: 'source_auto_switch');
    session.set('__allow_interactive_challenge__', false);
    final response = WebViewResponsePayload(
      statusCode: 200,
      body: '<html>ok</html>',
      finalUrl: 'https://example.com/challenge',
    );
    final runtime = AppReadBrowserRuntime(
      webViewExecutor: _FakeWebViewExecutor(response),
      interactiveExecutor: _FakeInteractiveExecutor(response),
      cookieSynchronizer: _FakeBrowserCookieSynchronizer(
        browserCookies: const [],
      ),
      defaultStage: ErrorStage.search,
    );

    await expectLater(
      runtime.challenge(
        BrowserChallengeRequest(
          uri: Uri.parse('https://example.com/challenge'),
          reason: 'captcha',
        ),
        session: session,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('rejects browser open when session is cancelled', () async {
    final session = SourceSession(sourceId: 'source_cancelled');
    session.set(
      sessionCancellationHandleKey,
      SessionCancellationHandle(isCancelled: () => true),
    );
    final response = WebViewResponsePayload(
      statusCode: 200,
      body: '<html>ok</html>',
      finalUrl: 'https://example.com/open',
    );
    final runtime = AppReadBrowserRuntime(
      webViewExecutor: _FakeWebViewExecutor(response),
      interactiveExecutor: _FakeInteractiveExecutor(response),
      cookieSynchronizer: _FakeBrowserCookieSynchronizer(
        browserCookies: const [],
      ),
      defaultStage: ErrorStage.search,
    );

    await expectLater(
      runtime.open(
        BrowserOpenRequest(uri: Uri.parse('https://example.com/open')),
        session: session,
      ),
      throwsA(isA<SessionTaskCancelledException>()),
    );
  });
}

class _FakeWebViewExecutor extends WebViewExecutor {
  _FakeWebViewExecutor(this._response);

  final WebViewResponsePayload _response;

  @override
  Future<WebViewResponsePayload> load({
    required WebViewRequestPayload request,
  }) async {
    return _response;
  }
}

class _FakeInteractiveExecutor extends InteractiveVerificationBrowserExecutor {
  _FakeInteractiveExecutor(this._response);

  final WebViewResponsePayload _response;

  @override
  Future<WebViewResponsePayload> open({
    required WebViewRequestPayload request,
    required bool awaitUserResult,
    String? title,
    bool refetchAfterSuccess = true,
  }) async {
    return _response;
  }
}

class _QueuedFakeWebViewExecutor extends WebViewExecutor {
  _QueuedFakeWebViewExecutor(this._gate);

  final _SequencedGate _gate;

  @override
  Future<WebViewResponsePayload> load({
    required WebViewRequestPayload request,
  }) async {
    await _gate.enter('web:${request.url}');
    return WebViewResponsePayload(
      statusCode: 200,
      body: '<html>${request.url}</html>',
      finalUrl: request.url,
      scriptResult: request.webJs == null ? null : 'ok',
    );
  }
}

class _QueuedFakeInteractiveExecutor
    extends InteractiveVerificationBrowserExecutor {
  _QueuedFakeInteractiveExecutor(this._gate);

  final _SequencedGate _gate;

  @override
  Future<WebViewResponsePayload> open({
    required WebViewRequestPayload request,
    required bool awaitUserResult,
    String? title,
    bool refetchAfterSuccess = true,
  }) async {
    await _gate.enter('interactive:${request.url}');
    return WebViewResponsePayload(
      statusCode: 200,
      body: '<html>${request.url}</html>',
      finalUrl: request.url,
    );
  }
}

class _SequencedGate {
  int _startedCount = 0;
  int _activeCount = 0;
  int maxConcurrent = 0;
  final List<Completer<void>> _pending = <Completer<void>>[];

  Future<void> enter(String _) async {
    _startedCount += 1;
    _activeCount += 1;
    if (_activeCount > maxConcurrent) {
      maxConcurrent = _activeCount;
    }
    final completer = Completer<void>();
    _pending.add(completer);
    await completer.future;
    _activeCount -= 1;
  }

  Future<void> waitUntilStartedCount(int expected) async {
    while (_startedCount < expected) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  void completeNext() {
    if (_pending.isEmpty) {
      return;
    }
    _pending.removeAt(0).complete();
  }
}

class _FakeBrowserCookieSynchronizer implements BrowserCookieSynchronizer {
  _FakeBrowserCookieSynchronizer({required this.browserCookies});

  final List<SourceCookie> browserCookies;
  Uri? syncedSessionToBrowserUri;
  Uri? syncedBrowserToSessionUri;
  Map<String, String> syncedSessionCookies = <String, String>{};

  @override
  Future<void> syncBrowserToSession({
    required Uri uri,
    required SourceSession session,
  }) async {
    syncedBrowserToSessionUri = uri;
    session.mergeCookieEntries(browserCookies);
  }

  @override
  Future<void> syncSessionToBrowser({
    required Uri uri,
    required SourceSession session,
  }) async {
    syncedSessionToBrowserUri = uri;
    syncedSessionCookies = Map<String, String>.from(session.cookiesForUri(uri));
  }
}

class _RecordingPlatformCookieManager extends PlatformCookieManager {
  _RecordingPlatformCookieManager()
    : super.implementation(const PlatformCookieManagerCreationParams());

  final List<_RecordedSetCookieCall> setCookieCalls =
      <_RecordedSetCookieCall>[];

  @override
  Future<List<Cookie>> getCookies({
    required WebUri url,
    PlatformInAppWebViewController? iosBelow11WebViewController,
    PlatformInAppWebViewController? webViewController,
  }) async {
    return <Cookie>[];
  }

  @override
  Future<bool> setCookie({
    required WebUri url,
    required String name,
    required String value,
    String path = '/',
    String? domain,
    int? expiresDate,
    int? maxAge,
    bool? isSecure,
    bool? isHttpOnly,
    HTTPCookieSameSitePolicy? sameSite,
    PlatformInAppWebViewController? iosBelow11WebViewController,
    PlatformInAppWebViewController? webViewController,
  }) async {
    setCookieCalls.add(
      _RecordedSetCookieCall(
        url: url.toString(),
        name: name,
        value: value,
        path: path,
        domain: domain,
        expiresDate: expiresDate,
        isSecure: isSecure,
        isHttpOnly: isHttpOnly,
      ),
    );
    return true;
  }
}

class _RecordedSetCookieCall {
  const _RecordedSetCookieCall({
    required this.url,
    required this.name,
    required this.value,
    required this.path,
    this.domain,
    this.expiresDate,
    this.isSecure,
    this.isHttpOnly,
  });

  final String url;
  final String name;
  final String value;
  final String path;
  final String? domain;
  final int? expiresDate;
  final bool? isSecure;
  final bool? isHttpOnly;
}
