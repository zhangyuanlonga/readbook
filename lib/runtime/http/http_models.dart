import 'dart:typed_data';

enum RuntimeHttpMethod { get, post, put, patch, delete, head }

enum RuntimeResponseType { text, json, bytes }

enum RuntimeRequestExecution { http, browser }

enum RuntimeBodyType { auto, json, form, text, bytes }

class RuntimeHttpRequest {
  const RuntimeHttpRequest({
    required this.uri,
    this.method = RuntimeHttpMethod.get,
    this.headers = const <String, String>{},
    this.query = const <String, String>{},
    this.body,
    this.timeout = const Duration(seconds: 8),
    this.responseType = RuntimeResponseType.text,
    this.referer,
    this.followRedirects = true,
    this.charset,
    this.execution = RuntimeRequestExecution.http,
    this.proxy,
    this.bodyType = RuntimeBodyType.auto,
    this.skipLoginCheck = false,
  });

  final Uri uri;
  final RuntimeHttpMethod method;
  final Map<String, String> headers;
  final Map<String, String> query;
  final Object? body;
  final Duration timeout;
  final RuntimeResponseType responseType;
  final String? referer;
  final bool followRedirects;
  final String? charset;
  final RuntimeRequestExecution execution;
  final String? proxy;
  final RuntimeBodyType bodyType;
  final bool skipLoginCheck;

  Uri get resolvedUri {
    if (query.isEmpty) {
      return uri;
    }

    return uri.replace(
      queryParameters: <String, String>{...uri.queryParameters, ...query},
    );
  }

  RuntimeHttpRequest copyWith({
    Uri? uri,
    RuntimeHttpMethod? method,
    Map<String, String>? headers,
    Map<String, String>? query,
    Object? body = _sentinel,
    Duration? timeout,
    RuntimeResponseType? responseType,
    String? referer = _sentinelString,
    bool? followRedirects,
    String? charset = _sentinelString,
    RuntimeRequestExecution? execution,
    String? proxy = _sentinelString,
    RuntimeBodyType? bodyType,
    bool? skipLoginCheck,
  }) {
    return RuntimeHttpRequest(
      uri: uri ?? this.uri,
      method: method ?? this.method,
      headers: headers ?? this.headers,
      query: query ?? this.query,
      body: identical(body, _sentinel) ? this.body : body,
      timeout: timeout ?? this.timeout,
      responseType: responseType ?? this.responseType,
      referer: identical(referer, _sentinelString) ? this.referer : referer,
      followRedirects: followRedirects ?? this.followRedirects,
      charset: identical(charset, _sentinelString) ? this.charset : charset,
      execution: execution ?? this.execution,
      proxy: identical(proxy, _sentinelString) ? this.proxy : proxy,
      bodyType: bodyType ?? this.bodyType,
      skipLoginCheck: skipLoginCheck ?? this.skipLoginCheck,
    );
  }
}

class RuntimeHttpResponse {
  const RuntimeHttpResponse({
    required this.ok,
    required this.status,
    required this.uri,
    this.headers = const <String, String>{},
    this.text,
    this.json,
    this.bytes,
    this.redirected = false,
  });

  final bool ok;
  final int status;
  final Uri uri;
  final Map<String, String> headers;
  final String? text;
  final Object? json;
  final Uint8List? bytes;
  final bool redirected;

  String? get contentType => headers['content-type'];

  RuntimeHttpResponse copyWith({
    bool? ok,
    int? status,
    Uri? uri,
    Map<String, String>? headers,
    Object? text = _sentinel,
    Object? json = _sentinel,
    Object? bytes = _sentinel,
    bool? redirected,
  }) {
    return RuntimeHttpResponse(
      ok: ok ?? this.ok,
      status: status ?? this.status,
      uri: uri ?? this.uri,
      headers: headers ?? this.headers,
      text: identical(text, _sentinel) ? this.text : text as String?,
      json: identical(json, _sentinel) ? this.json : json,
      bytes: identical(bytes, _sentinel) ? this.bytes : bytes as Uint8List?,
      redirected: redirected ?? this.redirected,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'ok': ok,
      'status': status,
      'url': uri.toString(),
      'headers': headers,
      'text': text,
      'json': json,
      'bytesLength': bytes?.length,
      'redirected': redirected,
    };
  }
}

const Object _sentinel = Object();
const String _sentinelString = '__runtime_http_request_sentinel__';
