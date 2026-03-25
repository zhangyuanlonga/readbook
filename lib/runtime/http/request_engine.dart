import 'dart:convert';
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
    final headers = <String, String>{
      ..._defaultHeaders,
      ...?session?.defaultHeaders,
      ...request.headers,
    };

    if (request.referer case final String referer) {
      headers.putIfAbsent('referer', () => referer);
    }

    if (session?.cookieHeader case final String cookieHeader) {
      headers.putIfAbsent('cookie', () => cookieHeader);
    }

    final uri = request.resolvedUri;
    final response = await _send(
      uri,
      request,
      headers,
    ).timeout(request.timeout);
    _captureCookies(session, response);

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

  void _captureCookies(SourceSession? session, http.Response response) {
    final rawSetCookie = response.headers['set-cookie'];
    if (session == null || rawSetCookie == null || rawSetCookie.isEmpty) {
      return;
    }

    for (final segment in rawSetCookie.split(',')) {
      final firstPair = segment.split(';').first.trim();
      final separatorIndex = firstPair.indexOf('=');
      if (separatorIndex <= 0) {
        continue;
      }

      final name = firstPair.substring(0, separatorIndex).trim();
      final value = firstPair.substring(separatorIndex + 1).trim();
      if (name.isEmpty) {
        continue;
      }
      session.setCookie(name, value);
    }
  }
}
