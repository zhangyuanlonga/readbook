import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/errors/error_stage.dart';
import '../../core/webview/interactive_verification_browser_executor.dart';
import '../../core/webview/webview_executor.dart';
import '../browser/browser_runtime.dart';
import '../session/source_session.dart';

class AppReadBrowserRuntime implements BrowserRuntime {
  static const String _allowInteractiveChallengeSessionKey =
      '__allow_interactive_challenge__';

  AppReadBrowserRuntime({
    WebViewExecutor? webViewExecutor,
    InteractiveVerificationBrowserExecutor? interactiveExecutor,
    BrowserCookieSynchronizer? cookieSynchronizer,
    this.defaultStage = ErrorStage.unknown,
  }) : _webViewExecutor = webViewExecutor ?? WebViewExecutor(),
       _interactiveExecutor =
           interactiveExecutor ??
           InteractiveVerificationBrowserExecutor.instance,
       _cookieSynchronizer =
           cookieSynchronizer ?? const InAppWebViewCookieSynchronizer();

  final WebViewExecutor _webViewExecutor;
  final InteractiveVerificationBrowserExecutor _interactiveExecutor;
  final BrowserCookieSynchronizer _cookieSynchronizer;
  final ErrorStage defaultStage;
  Future<void> _queue = Future<void>.value();

  @override
  Future<void> open(
    BrowserOpenRequest request, {
    SourceSession? session,
  }) async {
    await _runExclusive(() async {
      _throwIfCancelled(session);
      await _syncSessionCookiesToBrowser(request.uri, session);
      final response = await _webViewExecutor.load(
        request: WebViewRequestPayload(
          url: request.uri.toString(),
          stage: defaultStage,
          sourceId: session?.sourceId,
          timeout: request.timeout,
        ),
      );
      _throwIfCancelled(session);
      await _syncBrowserCookiesToSession(response.finalUrl, session);
      _throwIfCancelled(session);
      _persistSnapshot(session, response);
    });
  }

  @override
  Future<void> challenge(
    BrowserChallengeRequest request, {
    SourceSession? session,
  }) async {
    _throwIfCancelled(session);
    if (session?.get<bool>(_allowInteractiveChallengeSessionKey) == false) {
      throw StateError('Interactive browser challenge is disabled.');
    }
    await _runExclusive(() async {
      _throwIfCancelled(session);
      await _syncSessionCookiesToBrowser(request.uri, session);
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
      _throwIfCancelled(session);
      await _syncBrowserCookiesToSession(response.finalUrl, session);
      _throwIfCancelled(session);
      _persistSnapshot(session, response);
    });
  }

  @override
  Future<Object?> eval(
    BrowserEvalRequest request, {
    SourceSession? session,
  }) async {
    return _runExclusive(() async {
      _throwIfCancelled(session);
      await _syncSessionCookiesToBrowser(request.uri, session);
      final response = await _webViewExecutor.load(
        request: WebViewRequestPayload(
          url: request.uri.toString(),
          stage: defaultStage,
          sourceId: session?.sourceId,
          timeout: request.timeout,
          webJs: request.script,
        ),
      );
      _throwIfCancelled(session);
      await _syncBrowserCookiesToSession(response.finalUrl, session);
      _throwIfCancelled(session);
      _persistSnapshot(session, response);
      return response.scriptResult;
    });
  }

  void _throwIfCancelled(SourceSession? session) {
    if (session?.isCancelled ?? false) {
      throw const SessionTaskCancelledException();
    }
  }

  Future<T> _runExclusive<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.catchError((_) {}).then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _syncSessionCookiesToBrowser(
    Uri uri,
    SourceSession? session,
  ) async {
    if (session == null || session.cookies.isEmpty || uri.host.trim().isEmpty) {
      return;
    }
    await _cookieSynchronizer.syncSessionToBrowser(uri: uri, session: session);
  }

  Future<void> _syncBrowserCookiesToSession(
    String url,
    SourceSession? session,
  ) async {
    if (session == null) {
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.trim().isEmpty) {
      return;
    }
    await _cookieSynchronizer.syncBrowserToSession(uri: uri, session: session);
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

abstract class BrowserCookieSynchronizer {
  Future<void> syncSessionToBrowser({
    required Uri uri,
    required SourceSession session,
  });

  Future<void> syncBrowserToSession({
    required Uri uri,
    required SourceSession session,
  });
}

class InAppWebViewCookieSynchronizer implements BrowserCookieSynchronizer {
  const InAppWebViewCookieSynchronizer({CookieManager? cookieManager})
    : _cookieManager = cookieManager;

  final CookieManager? _cookieManager;

  CookieManager get _manager => _cookieManager ?? CookieManager.instance();

  @override
  Future<void> syncSessionToBrowser({
    required Uri uri,
    required SourceSession session,
  }) async {
    final webUri = WebUri.uri(uri);
    for (final cookie in session.cookieEntriesForUri(uri)) {
      await _manager.setCookie(
        url: webUri,
        name: cookie.name,
        value: cookie.value,
        path: cookie.normalizedPath,
        domain: cookie.hostOnly ? null : cookie.normalizedDomain,
        expiresDate: cookie.expiresAt?.millisecondsSinceEpoch,
        isSecure: cookie.isSecure,
        isHttpOnly: cookie.isHttpOnly,
      );
    }
  }

  @override
  Future<void> syncBrowserToSession({
    required Uri uri,
    required SourceSession session,
  }) async {
    final cookies = await _manager.getCookies(url: WebUri.uri(uri));
    for (final cookie in cookies) {
      final name = cookie.name.trim();
      if (name.isEmpty) {
        continue;
      }
      final rawValue = cookie.value;
      session.setCookie(
        name,
        rawValue?.toString() ?? '',
        uri: uri,
        domain: cookie.domain,
        path: cookie.path ?? '/',
        expiresAt:
            cookie.expiresDate == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                  cookie.expiresDate!,
                  isUtc: true,
                ),
        isSecure: cookie.isSecure,
        isHttpOnly: cookie.isHttpOnly,
        hostOnly: cookie.domain == null || cookie.domain!.trim().isEmpty,
      );
    }
  }
}
