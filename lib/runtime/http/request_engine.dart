import 'dart:convert';
import 'dart:io' show HttpDate;
import 'dart:typed_data';

import 'package:charset/charset.dart' as charset;
import 'package:http/http.dart' as http;

import '../session/source_session.dart';
import 'challenge_detector.dart';
import 'http_models.dart';

abstract class RequestEngine {
  Future<RuntimeHttpResponse> request(
    RuntimeHttpRequest request, {
    SourceSession? session,
  });

  bool isHtml(RuntimeHttpResponse response);
  bool isJson(RuntimeHttpResponse response);
  bool isRedirect(RuntimeHttpResponse response);
  ChallengeDetectionResult detectChallenge(RuntimeHttpResponse response);

  bool isChallenge(RuntimeHttpResponse response) {
    return detectChallenge(response).isChallenge;
  }
}

class HttpPackageRequestEngine implements RequestEngine {
  HttpPackageRequestEngine({
    http.Client? client,
    ChallengeDetector? challengeDetector,
    Map<String, String>? defaultHeaders,
  }) : _client = client ?? http.Client(),
       _challengeDetector =
           challengeDetector ?? const DefaultChallengeDetector(),
       _defaultHeaders = defaultHeaders ?? const <String, String>{};

  final http.Client _client;
  final ChallengeDetector _challengeDetector;
  final Map<String, String> _defaultHeaders;

  @override
  Future<RuntimeHttpResponse> request(
    RuntimeHttpRequest request, {
    SourceSession? session,
  }) async {
    _throwIfCancelled(session);
    final uri = request.resolvedUri;
    final headers = <String, String>{
      ..._defaultHeaders,
      ...?session?.defaultHeaders,
      ...request.headers,
    };

    if (request.referer case final String referer) {
      headers.putIfAbsent('referer', () => referer);
    }

    if (session?.cookieHeaderForUri(uri) case final String cookieHeader) {
      headers.putIfAbsent('cookie', () => cookieHeader);
    }

    final response = await _send(
      uri,
      request,
      headers,
    ).timeout(request.timeout);
    _throwIfCancelled(session);
    _captureCookies(session, response, uri);

    final bytes = Uint8List.fromList(response.bodyBytes);
    final text = _decodeText(bytes, request.charset);
    final jsonBody = _tryParseJson(text, request.responseType);

    return RuntimeHttpResponse(
      ok: response.statusCode >= 200 && response.statusCode < 300,
      status: response.statusCode,
      uri: response.request?.url ?? uri,
      headers: response.headers,
      text: text,
      json: jsonBody,
      bytes: bytes,
      redirected: response.request?.url != uri,
    );
  }

  void _throwIfCancelled(SourceSession? session) {
    if (session?.isCancelled ?? false) {
      throw const SessionTaskCancelledException();
    }
  }

  @override
  bool isHtml(RuntimeHttpResponse response) {
    final contentType = response.contentType?.toLowerCase() ?? '';
    return contentType.contains('text/html') ||
        (response.text?.toLowerCase().contains('<html') ?? false);
  }

  @override
  bool isJson(RuntimeHttpResponse response) {
    final contentType = response.contentType?.toLowerCase() ?? '';
    return contentType.contains('application/json') || response.json != null;
  }

  @override
  bool isRedirect(RuntimeHttpResponse response) {
    return response.redirected ||
        response.status == 301 ||
        response.status == 302 ||
        response.status == 303 ||
        response.status == 307 ||
        response.status == 308;
  }

  @override
  ChallengeDetectionResult detectChallenge(RuntimeHttpResponse response) {
    return _challengeDetector.detect(response);
  }

  @override
  bool isChallenge(RuntimeHttpResponse response) {
    return detectChallenge(response).isChallenge;
  }

  Future<http.Response> _send(
    Uri uri,
    RuntimeHttpRequest request,
    Map<String, String> headers,
  ) {
    switch (request.method) {
      case RuntimeHttpMethod.get:
        return _client.get(uri, headers: headers);
      case RuntimeHttpMethod.post:
        return _client.post(
          uri,
          headers: headers,
          body: _encodeRequestBody(request, headers),
        );
      case RuntimeHttpMethod.put:
        return _client.put(
          uri,
          headers: headers,
          body: _encodeRequestBody(request, headers),
        );
      case RuntimeHttpMethod.patch:
        return _client.patch(
          uri,
          headers: headers,
          body: _encodeRequestBody(request, headers),
        );
      case RuntimeHttpMethod.delete:
        return _client.delete(
          uri,
          headers: headers,
          body: _encodeRequestBody(request, headers),
        );
      case RuntimeHttpMethod.head:
        return _client.head(uri, headers: headers);
    }
  }

  Object? _encodeBody(Object? body, Map<String, String> headers) {
    if (body == null) {
      return body;
    }

    switch (body is List<int> ? RuntimeBodyType.bytes : RuntimeBodyType.auto) {
      default:
        break;
    }

    if (body is String || body is List<int>) {
      return body;
    }

    headers.putIfAbsent('content-type', () => 'application/json');
    return jsonEncode(body);
  }

  Object? _encodeRequestBody(
    RuntimeHttpRequest request,
    Map<String, String> headers,
  ) {
    final body = request.body;
    if (body == null) {
      return null;
    }

    switch (request.bodyType) {
      case RuntimeBodyType.auto:
        return _encodeBody(body, headers);
      case RuntimeBodyType.json:
        headers.putIfAbsent('content-type', () => 'application/json');
        return body is String ? body : jsonEncode(body);
      case RuntimeBodyType.form:
        headers.putIfAbsent(
          'content-type',
          () => 'application/x-www-form-urlencoded',
        );
        if (body is String) {
          return body;
        }
        if (body is Map) {
          return body.entries
              .map(
                (MapEntry<dynamic, dynamic> entry) =>
                    '${Uri.encodeQueryComponent(entry.key.toString())}'
                    '=${Uri.encodeQueryComponent(entry.value?.toString() ?? '')}',
              )
              .join('&');
        }
        return body.toString();
      case RuntimeBodyType.text:
        headers.putIfAbsent('content-type', () => 'text/plain; charset=utf-8');
        return body.toString();
      case RuntimeBodyType.bytes:
        if (body is List<int>) {
          return body;
        }
        if (body is Uint8List) {
          return body;
        }
        throw ArgumentError('bodyType=bytes 时 body 必须为 List<int>。');
    }
  }

  String _decodeText(Uint8List bytes, String? charsetName) {
    if (bytes.isEmpty) {
      return '';
    }
    final normalized = charsetName?.trim().toLowerCase();
    if (normalized == null ||
        normalized.isEmpty ||
        normalized == 'utf8' ||
        normalized == 'utf-8') {
      return utf8.decode(bytes, allowMalformed: true);
    }

    try {
      final encoding = charset.Charset.getByName(normalized);
      if (encoding != null) {
        return encoding.decode(bytes);
      }
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  Object? _tryParseJson(String text, RuntimeResponseType responseType) {
    if (text.trim().isEmpty) {
      return null;
    }

    if (responseType != RuntimeResponseType.json &&
        !text.trimLeft().startsWith('{') &&
        !text.trimLeft().startsWith('[')) {
      return null;
    }

    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  void _captureCookies(
    SourceSession? session,
    http.Response response,
    Uri requestUri,
  ) {
    final rawSetCookie = response.headers['set-cookie'];
    if (session == null || rawSetCookie == null || rawSetCookie.isEmpty) {
      return;
    }

    final responseUri = response.request?.url ?? requestUri;
    for (final segment in _splitSetCookieHeader(rawSetCookie)) {
      final parsed = _parseSetCookieSegment(segment, responseUri);
      if (parsed == null) {
        continue;
      }
      session.setCookieEntry(parsed);
    }
  }

  List<String> _splitSetCookieHeader(String rawSetCookie) {
    return rawSetCookie
        .split(RegExp(r',(?=\s*[^=;,\s]+\s*=)'))
        .map((String segment) => segment.trim())
        .where((String segment) => segment.isNotEmpty)
        .toList(growable: false);
  }

  SourceCookie? _parseSetCookieSegment(String segment, Uri responseUri) {
    final parts = segment.split(';');
    if (parts.isEmpty) {
      return null;
    }

    final firstPair = parts.first.trim();
    final separatorIndex = firstPair.indexOf('=');
    if (separatorIndex <= 0) {
      return null;
    }

    final name = firstPair.substring(0, separatorIndex).trim();
    final value = firstPair.substring(separatorIndex + 1).trim();
    if (name.isEmpty) {
      return null;
    }

    String? domain;
    String? path;
    DateTime? expiresAt;
    int? maxAge;
    bool? isSecure;
    bool? isHttpOnly;

    for (final attribute in parts.skip(1)) {
      final normalized = attribute.trim();
      if (normalized.isEmpty) {
        continue;
      }

      final attributeSeparator = normalized.indexOf('=');
      final attributeName =
          attributeSeparator == -1
              ? normalized.toLowerCase()
              : normalized
                  .substring(0, attributeSeparator)
                  .trim()
                  .toLowerCase();
      final attributeValue =
          attributeSeparator == -1
              ? ''
              : normalized.substring(attributeSeparator + 1).trim();

      switch (attributeName) {
        case 'domain':
          if (attributeValue.isNotEmpty) {
            domain = attributeValue;
          }
          break;
        case 'path':
          if (attributeValue.isNotEmpty) {
            path = attributeValue;
          }
          break;
        case 'expires':
          if (attributeValue.isNotEmpty) {
            expiresAt = _tryParseExpires(attributeValue);
          }
          break;
        case 'max-age':
          maxAge = int.tryParse(attributeValue);
          break;
        case 'secure':
          isSecure = true;
          break;
        case 'httponly':
          isHttpOnly = true;
          break;
        default:
          break;
      }
    }

    final resolvedExpiresAt =
        maxAge == null
            ? expiresAt
            : DateTime.now().toUtc().add(Duration(seconds: maxAge));

    return SourceCookie(
      name: name,
      value: value,
      domain: domain ?? responseUri.host,
      path: path ?? _defaultCookiePath(responseUri),
      expiresAt: resolvedExpiresAt,
      isSecure: isSecure,
      isHttpOnly: isHttpOnly,
      hostOnly: domain == null || domain.trim().isEmpty,
    );
  }

  DateTime? _tryParseExpires(String value) {
    try {
      return HttpDate.parse(value);
    } catch (_) {
      final normalized = value
          .trim()
          .replaceFirstMapped(
            RegExp(
              r'^([A-Za-z]{3},\s*\d{1,2})-([A-Za-z]{3})-(\d{2,4}\s+\d{2}:\d{2}:\d{2}\s+GMT)$',
            ),
            (match) => '${match.group(1)} ${match.group(2)} ${match.group(3)}',
          );
      if (normalized == value.trim()) {
        return null;
      }
      try {
        return HttpDate.parse(normalized);
      } catch (_) {
        return null;
      }
    }
  }

  String _defaultCookiePath(Uri uri) {
    final requestPath = uri.path.trim();
    if (requestPath.isEmpty || !requestPath.startsWith('/')) {
      return '/';
    }
    final lastSlashIndex = requestPath.lastIndexOf('/');
    if (lastSlashIndex <= 0) {
      return '/';
    }
    return requestPath.substring(0, lastSlashIndex);
  }
}
