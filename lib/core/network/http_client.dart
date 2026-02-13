import 'package:dio/dio.dart';

import '../errors/app_exception.dart';
import '../logging/app_logger.dart';
import 'interceptors.dart';
import 'request_context.dart';

class HttpResponsePayload {
  const HttpResponsePayload({
    required this.statusCode,
    required this.body,
    required this.headers,
  });

  final int statusCode;
  final String body;
  final Map<String, List<String>> headers;
}

class AppHttpClient {
  AppHttpClient({
    Dio? dio,
    AppLogger? logger,
    Duration defaultConnectTimeout = const Duration(seconds: 8),
    Duration defaultReceiveTimeout = const Duration(seconds: 12),
    Map<String, String> defaultHeaders = const {
      'User-Agent': 'flutter_appread/0.1',
      'Accept': '*/*',
    },
  }) : _dio = dio ?? Dio(),
       _logger = logger ?? AppLogger.instance,
       _defaultConnectTimeout = defaultConnectTimeout,
       _defaultReceiveTimeout = defaultReceiveTimeout,
       _defaultHeaders = Map.unmodifiable({...defaultHeaders}) {
    if (_dio.interceptors.whereType<NetworkLogInterceptor>().isEmpty) {
      _dio.interceptors.add(NetworkLogInterceptor(_logger));
    }
  }

  final Dio _dio;
  final AppLogger _logger;
  final Duration _defaultConnectTimeout;
  final Duration _defaultReceiveTimeout;
  final Map<String, String> _defaultHeaders;

  Future<HttpResponsePayload> get(RequestContext context) async {
    final totalAttempts = context.maxRetries + 1;

    for (var attempt = 1; attempt <= totalAttempts; attempt++) {
      final responseOrError = await _send(context, attempt);

      if (responseOrError case _Success(:final response)) {
        final statusCode = response.statusCode ?? 0;
        final shouldRetry =
            context.shouldRetryStatusCode(statusCode) &&
            attempt < totalAttempts;
        if (shouldRetry) {
          await _delayForRetry(context, attempt);
          continue;
        }

        if (statusCode < 200 || statusCode >= 300) {
          throw NetworkException(
            briefMessage: '请求失败，状态码：$statusCode',
            sourceId: context.sourceId,
            stage: context.stage,
            requestUrl: context.url,
          );
        }

        return HttpResponsePayload(
          statusCode: statusCode,
          body: response.data ?? '',
          headers: response.headers.map,
        );
      }

      if (responseOrError case _Failure(:final exception)) {
        final canRetry = _isRetryable(exception) && attempt < totalAttempts;
        if (canRetry) {
          await _delayForRetry(context, attempt);
          continue;
        }

        final message = _buildExceptionMessage(exception);
        throw NetworkException(
          briefMessage: message,
          sourceId: context.sourceId,
          stage: context.stage,
          requestUrl: context.url,
          cause: exception,
          stackTrace: exception.stackTrace,
        );
      }
    }

    throw NetworkException(
      briefMessage: '网络请求失败：未知错误',
      sourceId: context.sourceId,
      stage: context.stage,
      requestUrl: context.url,
    );
  }

  Future<_ResponseOrError> _send(RequestContext context, int attempt) async {
    final mergedHeaders = <String, String>{
      ..._defaultHeaders,
      ...context.headers,
    };

    if (context.contentType != null && context.contentType!.trim().isNotEmpty) {
      mergedHeaders['Content-Type'] = context.contentType!;
    }

    _logger.info(
      'Network request',
      context: {
        'method': _methodText(context.method),
        'url': context.url,
        'stage': context.stage.name,
        'attempt': attempt,
      },
    );

    try {
      final response = await _dio.request<String>(
        context.url,
        data: context.body,
        queryParameters: context.queryParameters,
        options: Options(
          method: _methodText(context.method),
          responseType: ResponseType.plain,
          headers: mergedHeaders,
          sendTimeout: context.connectTimeout ?? _defaultConnectTimeout,
          connectTimeout: context.connectTimeout ?? _defaultConnectTimeout,
          receiveTimeout: context.receiveTimeout ?? _defaultReceiveTimeout,
          validateStatus:
              (statusCode) => statusCode != null && statusCode < 600,
        ),
      );
      return _Success(response);
    } on DioException catch (error) {
      return _Failure(error);
    }
  }

  String _methodText(HttpRequestMethod method) {
    return switch (method) {
      HttpRequestMethod.get => 'GET',
      HttpRequestMethod.post => 'POST',
    };
  }

  bool _isRetryable(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return true;
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
        return false;
    }
  }

  String _buildExceptionMessage(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '请求超时，请稍后重试。';
      case DioExceptionType.connectionError:
        final detail = exception.error?.toString() ?? exception.message;
        if (detail != null && detail.trim().isNotEmpty) {
          return '网络连接失败：$detail';
        }
        return '网络连接失败，请检查网络设置。';
      case DioExceptionType.badResponse:
        final statusCode = exception.response?.statusCode;
        return '请求失败，状态码：${statusCode ?? 'unknown'}';
      case DioExceptionType.badCertificate:
        return '证书校验失败，无法建立安全连接。';
      case DioExceptionType.cancel:
        return '请求已取消。';
      case DioExceptionType.unknown:
        return '网络请求异常，请稍后重试。';
    }
  }

  Future<void> _delayForRetry(RequestContext context, int attempt) {
    final delay = Duration(
      milliseconds: context.retryDelay.inMilliseconds * attempt,
    );
    return Future<void>.delayed(delay);
  }
}

sealed class _ResponseOrError {}

class _Success extends _ResponseOrError {
  _Success(this.response);

  final Response<String> response;
}

class _Failure extends _ResponseOrError {
  _Failure(this.exception);

  final DioException exception;
}
