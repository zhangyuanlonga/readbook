import '../errors/error_stage.dart';

enum HttpRequestMethod { get, post }

class RequestContext {
  const RequestContext({
    required this.url,
    this.method = HttpRequestMethod.get,
    this.queryParameters = const {},
    this.headers = const {},
    this.body,
    this.contentType,
    this.responseCharset,
    this.connectTimeout,
    this.receiveTimeout,
    this.maxRetries = 0,
    this.retryDelay = const Duration(milliseconds: 250),
    this.retryStatusCodes = const {408, 429, 500, 502, 503, 504},
    this.stage = ErrorStage.search,
    this.sourceId,
  });

  final String url;
  final HttpRequestMethod method;
  final Map<String, dynamic> queryParameters;
  final Map<String, String> headers;
  final Object? body;
  final String? contentType;
  final String? responseCharset;
  final Duration? connectTimeout;
  final Duration? receiveTimeout;
  final int maxRetries;
  final Duration retryDelay;
  final Set<int> retryStatusCodes;
  final ErrorStage stage;
  final String? sourceId;

  bool shouldRetryStatusCode(int statusCode) {
    return retryStatusCodes.contains(statusCode);
  }
}
