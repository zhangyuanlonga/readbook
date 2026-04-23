import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../core/auth/auth_session_store.dart';
import '../../core/device/device_identity_service.dart';
import '../crypto/source_crypto.dart';
import '../browser/browser_runtime.dart';
import '../cache/cache_manager.dart';
import '../cache/cache_policy.dart';
import '../html/html_runtime.dart';
import '../http/http_models.dart';
import '../http/request_engine.dart';
import '../session/source_session.dart';
import 'source_manifest.dart';
import 'source_result_models.dart';

enum SourceTaskStep {
  discoverCategories,
  discoverBooks,
  search,
  detail,
  chapters,
  content,
}

class SourceTask {
  const SourceTask({
    required this.sourceId,
    required this.step,
    this.keyword,
    this.category,
    this.page,
    this.pageSize,
    this.book,
    this.chapter,
  });

  final String sourceId;
  final SourceTaskStep step;
  final String? keyword;
  final DiscoverCategory? category;
  final int? page;
  final int? pageSize;
  final Book? book;
  final Chapter? chapter;
}

class SourceHttpContext {
  SourceHttpContext({
    required RequestEngine requestEngine,
    required SourceSession session,
    required SourceManifest manifest,
    required BrowserRuntime browserRuntime,
    DateTime Function()? now,
    Future<void> Function(Duration duration)? sleep,
  }) : _requestEngine = requestEngine,
       _session = session,
       _manifest = manifest,
       _browserRuntime = browserRuntime,
       _now = now ?? DateTime.now,
       _sleep = sleep ?? Future<void>.delayed;

  final RequestEngine _requestEngine;
  final SourceSession _session;
  final SourceManifest _manifest;
  final BrowserRuntime _browserRuntime;
  final DateTime Function() _now;
  final Future<void> Function(Duration duration) _sleep;

  Future<RuntimeHttpResponse> request(RuntimeHttpRequest request) async {
    final startedAt = DateTime.now();
    try {
      if (request.execution == RuntimeRequestExecution.browser) {
        final response = await _requestInBrowser(request);
        appendDebugTrace(_session, <String, Object?>{
          'kind': 'http',
          'execution': 'browser',
          'startedAt': startedAt.toIso8601String(),
          'method': request.method.name.toUpperCase(),
          'url': request.resolvedUri.toString(),
          'headers': request.headers,
          'query': request.query,
          'body': request.body,
          'bodyType': request.bodyType.name,
          'charset': request.charset,
          'status': response.status,
          'responseHeaders': response.headers,
          'responseText': _previewText(response.text),
        });
        return response;
      }
      await _applyRateLimitIfNeeded(request.resolvedUri);
      final response = await _requestEngine.request(request, session: _session);
      appendDebugTrace(_session, <String, Object?>{
        'kind': 'http',
        'execution': 'http',
        'startedAt': startedAt.toIso8601String(),
        'method': request.method.name.toUpperCase(),
        'url': request.resolvedUri.toString(),
        'headers': request.headers,
        'query': request.query,
        'body': request.body,
        'bodyType': request.bodyType.name,
        'charset': request.charset,
        'status': response.status,
        'responseHeaders': response.headers,
        'responseText': _previewText(response.text),
        'responseJson': response.json,
      });
      return response;
    } catch (error) {
      appendDebugTrace(_session, <String, Object?>{
        'kind': 'http',
        'execution': request.execution.name,
        'startedAt': startedAt.toIso8601String(),
        'method': request.method.name.toUpperCase(),
        'url': request.resolvedUri.toString(),
        'headers': request.headers,
        'query': request.query,
        'body': request.body,
        'bodyType': request.bodyType.name,
        'charset': request.charset,
        'error': error.toString(),
      });
      rethrow;
    }
  }

  bool isHtml(RuntimeHttpResponse response) => _requestEngine.isHtml(response);

  bool isJson(RuntimeHttpResponse response) => _requestEngine.isJson(response);

  bool isRedirect(RuntimeHttpResponse response) =>
      _requestEngine.isRedirect(response);

  bool isChallenge(RuntimeHttpResponse response) =>
      _requestEngine.isChallenge(response);

  Future<void> _applyRateLimitIfNeeded(Uri uri) {
    final rateLimit = _manifest.rateLimitForUri(uri);
    if (rateLimit == null || rateLimit.minInterval <= Duration.zero) {
      return Future<void>.value();
    }

    return _SourceDomainRateLimiter.waitTurn(
      sourceId: _session.sourceId,
      domain: uri.host,
      minInterval: rateLimit.minInterval,
      now: _now,
      sleep: _sleep,
    );
  }

  Future<RuntimeHttpResponse> _requestInBrowser(
    RuntimeHttpRequest request,
  ) async {
    final uri = request.resolvedUri;
    await _browserRuntime.open(
      BrowserOpenRequest(uri: uri, timeout: request.timeout),
      session: _session,
    );
    final html = _session.get<String>('lastBrowserHtml') ?? '';
    final currentUrl = _session.get<String>('lastBrowserUrl') ?? uri.toString();
    final bytes = utf8.encode(html);
    final parsedJson =
        request.responseType == RuntimeResponseType.json
            ? _tryParseJson(html)
            : null;

    return RuntimeHttpResponse(
      ok: true,
      status: 200,
      uri: Uri.parse(currentUrl),
      headers: const <String, String>{
        'content-type': 'text/html; charset=utf-8',
      },
      text: html,
      json: parsedJson,
      bytes: Uint8List.fromList(bytes),
      redirected: currentUrl != uri.toString(),
    );
  }

  Object? _tryParseJson(String text) {
    if (text.trim().isEmpty) {
      return null;
    }
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  String? _previewText(String? text) {
    if (text == null) {
      return null;
    }
    if (text.length <= 4000) {
      return text;
    }
    return '${text.substring(0, 4000)}\n...[truncated]';
  }
}

class SourceCookieContext {
  const SourceCookieContext({required SourceSession session})
    : _session = session;

  final SourceSession _session;

  String? get(String name) {
    return _session.cookies[name];
  }

  Map<String, String> getAll() {
    return _session.cookies;
  }

  Object? getForUrl(String url, [String? name]) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.trim().isEmpty) {
      if (name == null || name.isEmpty) {
        return _session.cookies;
      }
      return _session.cookies[name];
    }

    if (name == null || name.isEmpty) {
      return _session.cookiesForUri(uri);
    }
    return _session.cookieValueForUri(uri, name);
  }

  void set(String name, String value) {
    _session.setCookie(name, value);
  }

  void remove(String name) {
    _session.removeCookie(name);
  }

  void clearDomain(String domain) {
    _session.clearCookiesForDomain(domain);
  }
}

class SourceBrowserContext {
  const SourceBrowserContext({
    required BrowserRuntime browserRuntime,
    required SourceSession session,
  }) : _browserRuntime = browserRuntime,
       _session = session;

  final BrowserRuntime _browserRuntime;
  final SourceSession _session;

  Future<void> open(BrowserOpenRequest request) {
    final startedAt = DateTime.now();
    return _browserRuntime
        .open(request, session: _session)
        .then((_) {
          appendDebugTrace(_session, <String, Object?>{
            'kind': 'browser',
            'action': 'open',
            'startedAt': startedAt.toIso8601String(),
            'url': request.uri.toString(),
          });
        })
        .catchError((Object error) {
          appendDebugTrace(_session, <String, Object?>{
            'kind': 'browser',
            'action': 'open',
            'startedAt': startedAt.toIso8601String(),
            'url': request.uri.toString(),
            'error': error.toString(),
          });
          throw error;
        });
  }

  Future<void> challenge(BrowserChallengeRequest request) {
    final startedAt = DateTime.now();
    return _browserRuntime
        .challenge(request, session: _session)
        .then((_) {
          appendDebugTrace(_session, <String, Object?>{
            'kind': 'browser',
            'action': 'challenge',
            'startedAt': startedAt.toIso8601String(),
            'url': request.uri.toString(),
            'reason': request.reason,
            'waitFor': request.waitFor,
          });
        })
        .catchError((Object error) {
          appendDebugTrace(_session, <String, Object?>{
            'kind': 'browser',
            'action': 'challenge',
            'startedAt': startedAt.toIso8601String(),
            'url': request.uri.toString(),
            'reason': request.reason,
            'waitFor': request.waitFor,
            'error': error.toString(),
          });
          throw error;
        });
  }

  Future<void> waitForUrl({
    required String urlIncludes,
    Duration timeout = const Duration(minutes: 2),
    Uri? url,
    String reason = 'wait_for_url',
  }) {
    return _browserRuntime.challenge(
      BrowserChallengeRequest(
        uri:
            url ??
            Uri.parse(_session.get<String>('lastBrowserUrl') ?? 'about:blank'),
        reason: reason,
        waitFor: <String, Object?>{'urlIncludes': urlIncludes},
        timeout: timeout,
      ),
      session: _session,
    );
  }

  Future<void> waitForText({
    required String textIncludes,
    Duration timeout = const Duration(minutes: 2),
    Uri? url,
    String reason = 'wait_for_text',
  }) {
    return _browserRuntime.challenge(
      BrowserChallengeRequest(
        uri:
            url ??
            Uri.parse(_session.get<String>('lastBrowserUrl') ?? 'about:blank'),
        reason: reason,
        waitFor: <String, Object?>{'textIncludes': textIncludes},
        timeout: timeout,
      ),
      session: _session,
    );
  }

  Future<Object?> eval(BrowserEvalRequest request) {
    final startedAt = DateTime.now();
    return _browserRuntime
        .eval(request, session: _session)
        .then((Object? result) {
          appendDebugTrace(_session, <String, Object?>{
            'kind': 'browser',
            'action': 'eval',
            'startedAt': startedAt.toIso8601String(),
            'url': request.uri.toString(),
            'script':
                request.script.length <= 1000
                    ? request.script
                    : '${request.script.substring(0, 1000)}\n...[truncated]',
            'result': result,
          });
          return result;
        })
        .catchError((Object error) {
          appendDebugTrace(_session, <String, Object?>{
            'kind': 'browser',
            'action': 'eval',
            'startedAt': startedAt.toIso8601String(),
            'url': request.uri.toString(),
            'script':
                request.script.length <= 1000
                    ? request.script
                    : '${request.script.substring(0, 1000)}\n...[truncated]',
            'error': error.toString(),
          });
          throw error;
        });
  }

  Map<String, String> getCookies() {
    return _session.cookies;
  }

  String getCurrentUrl() {
    return _session.get<String>('lastBrowserUrl') ?? '';
  }

  String getHtml() {
    return _session.get<String>('lastBrowserHtml') ?? '';
  }

  Map<String, Object?> getStorage() {
    return <String, Object?>{
      'localStorage':
          _session.get<Map<String, String>>('lastBrowserLocalStorage') ??
          const <String, String>{},
      'sessionStorage':
          _session.get<Map<String, String>>('lastBrowserSessionStorage') ??
          const <String, String>{},
    };
  }
}

class SourceUtilsContext {
  SourceUtilsContext({
    DeviceIdentityService? deviceIdentityService,
    AuthSessionStore? authSessionStore,
  }) : _deviceIdentityService =
           deviceIdentityService ?? DeviceIdentityService(),
       _authSessionStore = authSessionStore ?? AuthSessionStore();

  final DeviceIdentityService _deviceIdentityService;
  final AuthSessionStore _authSessionStore;

  String absoluteUrl(String base, String relative) {
    if (relative.trim().isEmpty) {
      return '';
    }
    return Uri.parse(base).resolve(relative).toString();
  }

  Future<void> sleep(Duration duration) {
    return Future<void>.delayed(duration);
  }

  T pick<T>(T? value, T fallback) {
    return value ?? fallback;
  }

  String normalizeText(String? value) {
    return value?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  }

  String htmlFormat(String? value) {
    final text = value ?? '';
    if (text.trim().isEmpty) {
      return '';
    }
    return text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String timeFormat(Object? value, {String pattern = 'yyyy-MM-dd HH:mm:ss'}) {
    final dateTime = _parseDateTime(value);
    if (dateTime == null) {
      return '';
    }

    return pattern
        .replaceAll('yyyy', dateTime.year.toString().padLeft(4, '0'))
        .replaceAll('MM', dateTime.month.toString().padLeft(2, '0'))
        .replaceAll('dd', dateTime.day.toString().padLeft(2, '0'))
        .replaceAll('HH', dateTime.hour.toString().padLeft(2, '0'))
        .replaceAll('mm', dateTime.minute.toString().padLeft(2, '0'))
        .replaceAll('ss', dateTime.second.toString().padLeft(2, '0'));
  }

  DateTime? _parseDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      return value > 9999999999
          ? DateTime.fromMillisecondsSinceEpoch(value)
          : DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String) {
      final raw = value.trim();
      if (raw.isEmpty) {
        return null;
      }
      final asInt = int.tryParse(raw);
      if (asInt != null) {
        return _parseDateTime(asInt);
      }
      return DateTime.tryParse(raw.replaceAll('/', '-'));
    }
    return null;
  }

  String base64Encode(String? value) {
    return base64.encode(utf8.encode(value ?? ''));
  }

  String base64Decode(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }
    return utf8.decode(base64.decode(raw));
  }

  String hexEncode(String? value) {
    final bytes = utf8.encode(value ?? '');
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  String hexDecode(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }
    if (raw.length.isOdd) {
      throw const FormatException('hex 字符串长度必须为偶数。');
    }

    final bytes = <int>[];
    for (var index = 0; index < raw.length; index += 2) {
      final segment = raw.substring(index, index + 2);
      final byte = int.parse(segment, radix: 16);
      bytes.add(byte);
    }
    return utf8.decode(bytes);
  }

  String encodeUri(String? value) {
    return Uri.encodeFull(value ?? '');
  }

  String decodeUri(String? value) {
    return Uri.decodeFull(value ?? '');
  }

  String encodeUriComponent(String? value) {
    return Uri.encodeComponent(value ?? '');
  }

  String decodeUriComponent(String? value) {
    return Uri.decodeComponent(value ?? '');
  }

  Future<Map<String, Object?>> getDeviceInfo() async {
    final identity = await _deviceIdentityService.loadIdentity();
    return <String, Object?>{
      'installId': identity.installId,
      'deviceUid': identity.deviceUid,
      'deviceFingerprint': identity.deviceFingerprint,
      'platform': identity.platform,
      'deviceBrand': identity.deviceBrand,
      'deviceModel': identity.deviceModel,
      'osVersion': identity.osVersion,
      'appVersion': identity.appVersion,
    };
  }

  Future<String?> getUserId() {
    return _authSessionStore.getUserId();
  }
}

class SourceCacheContext {
  const SourceCacheContext({
    required CacheStoreContext cacheStore,
    required String sourceId,
  }) : _cacheStore = cacheStore,
       _sourceId = sourceId;

  final CacheStoreContext _cacheStore;
  final String _sourceId;

  T? get<T>(String key) {
    return _cacheStore.get<T>(_buildKey(key));
  }

  void set(String key, Object? value, {CachePolicy? policy}) {
    _cacheStore.set(_buildKey(key), value, sourceId: _sourceId, policy: policy);
  }

  void remove(String key) {
    _cacheStore.remove(_buildKey(key));
  }

  void clearPrefix(String prefix) {
    _cacheStore.clearPrefix(_buildKey(prefix));
  }

  String _buildKey(String key) {
    return '$_sourceId:$key';
  }
}

class SourceRuntimeContext {
  const SourceRuntimeContext({
    required this.source,
    required this.http,
    required this.browser,
    required this.cookie,
    required this.cache,
    required this.html,
    required this.session,
    required this.utils,
    required this.crypto,
    required this.log,
  });

  final SourceRuntimeInfo source;
  final SourceHttpContext http;
  final SourceBrowserContext browser;
  final SourceCookieContext cookie;
  final SourceCacheContext cache;
  final HtmlRuntime html;
  final SourceSession session;
  final SourceUtilsContext utils;
  final SourceCryptoContext crypto;
  final void Function(String message) log;
}

typedef SourceInitHandler =
    FutureOr<void> Function(SourceRuntimeContext ctx, SourceTask task);
typedef SourceSearchHandler =
    FutureOr<List<Book>> Function(SourceRuntimeContext ctx, String keyword);
typedef SourceDiscoverCategoriesHandler =
    FutureOr<List<DiscoverCategory>> Function(SourceRuntimeContext ctx);
typedef SourceDiscoverBooksHandler =
    FutureOr<List<Book>> Function(
      SourceRuntimeContext ctx,
      DiscoverCategory category,
      int page,
      int pageSize,
    );
typedef SourceDetailHandler =
    FutureOr<Book> Function(SourceRuntimeContext ctx, Book book);
typedef SourceChaptersHandler =
    FutureOr<List<Chapter>> Function(SourceRuntimeContext ctx, Book book);
typedef SourceContentHandler =
    FutureOr<Content> Function(
      SourceRuntimeContext ctx,
      Book book,
      Chapter chapter,
    );

class RuntimeSourceDefinition {
  const RuntimeSourceDefinition({
    required this.manifest,
    required this.search,
    required this.detail,
    required this.chapters,
    required this.content,
    this.init,
    this.discoverCategories,
    this.discoverBooks,
    this.dispose,
  });

  final SourceManifest manifest;
  final SourceInitHandler? init;
  final SourceDiscoverCategoriesHandler? discoverCategories;
  final SourceDiscoverBooksHandler? discoverBooks;
  final SourceSearchHandler search;
  final SourceDetailHandler detail;
  final SourceChaptersHandler chapters;
  final SourceContentHandler content;
  final void Function()? dispose;
}

const String debugTraceSessionKey = '__debug_traces';
const String debugLogSessionKey = '__debug_logs';

void appendDebugTrace(SourceSession session, Map<String, Object?> trace) {
  final existing =
      session
          .get<List<Object?>>(debugTraceSessionKey)
          ?.cast<Map<String, Object?>>() ??
      <Map<String, Object?>>[];
  existing.add(trace);
  if (existing.length > 60) {
    existing.removeRange(0, existing.length - 60);
  }
  session.set(debugTraceSessionKey, existing);
}

void appendDebugLog(
  SourceSession session, {
  required String message,
  String level = 'info',
}) {
  final normalizedMessage = message.trim();
  if (normalizedMessage.isEmpty) {
    return;
  }
  final existing =
      session
          .get<List<Object?>>(debugLogSessionKey)
          ?.cast<Map<String, Object?>>() ??
      <Map<String, Object?>>[];
  existing.add(<String, Object?>{
    'at': DateTime.now().toIso8601String(),
    'level': level.trim().isEmpty ? 'info' : level.trim(),
    'message': normalizedMessage,
  });
  if (existing.length > 120) {
    existing.removeRange(0, existing.length - 120);
  }
  session.set(debugLogSessionKey, existing);
}

List<Map<String, Object?>> readDebugTraces(SourceSession session) {
  return session
          .get<List<Object?>>(debugTraceSessionKey)
          ?.whereType<Map<String, Object?>>()
          .toList(growable: false) ??
      const <Map<String, Object?>>[];
}

List<Map<String, Object?>> readDebugLogs(SourceSession session) {
  return session
          .get<List<Object?>>(debugLogSessionKey)
          ?.whereType<Map<String, Object?>>()
          .toList(growable: false) ??
      const <Map<String, Object?>>[];
}

void clearDebugArtifacts(SourceSession session) {
  session.clear(debugTraceSessionKey);
  session.clear(debugLogSessionKey);
}

class _SourceDomainRateLimiter {
  static final Map<String, Future<void>> _pending = <String, Future<void>>{};
  static final Map<String, DateTime> _lastRequestStartedAt =
      <String, DateTime>{};

  static Future<void> waitTurn({
    required String sourceId,
    required String domain,
    required Duration minInterval,
    required DateTime Function() now,
    required Future<void> Function(Duration duration) sleep,
  }) {
    final key = '${sourceId.toLowerCase()}|${domain.toLowerCase()}';
    final previous = _pending[key] ?? Future<void>.value();
    final completer = Completer<void>();
    _pending[key] = completer.future;

    return previous
        .catchError((Object _) {})
        .then((_) async {
          final lastStartedAt = _lastRequestStartedAt[key];
          if (lastStartedAt != null) {
            final elapsed = now().difference(lastStartedAt);
            final remaining = minInterval - elapsed;
            if (remaining > Duration.zero) {
              await sleep(remaining);
            }
          }
          _lastRequestStartedAt[key] = now();
        })
        .whenComplete(() {
          completer.complete();
          if (identical(_pending[key], completer.future)) {
            _pending.remove(key);
          }
        });
  }
}
