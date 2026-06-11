import 'package:dio/dio.dart';

import '../logging/app_logger.dart';
import 'auth_token_refresher.dart';

/// Dio [RequestOptions.extra] key that controls automatic bearer token attach.
const String apiAttachAccessTokenExtraKey = 'attachAccessToken';

/// Dio [RequestOptions.extra] key that controls one-time refresh on HTTP 401.
const String apiEnableAuthRefreshExtraKey = 'enableAuthRefresh';

const String _authRetryAttemptExtraKey = 'authRetryAttempt';

/// Attaches the current access token and retries once after a refreshable 401.
///
/// The interceptor keeps token handling centralized for [ApiClient] and any
/// direct Dio clients that still need streaming support, such as SSE endpoints.
/// Token values are never written to logs.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required AuthTokenRefresher? Function() authTokenRefresherResolver,
    AppLogger? logger,
  }) : _dio = dio,
       _authTokenRefresherResolver = authTokenRefresherResolver,
       _logger = logger ?? AppLogger.instance;

  final Dio _dio;
  final AuthTokenRefresher? Function() _authTokenRefresherResolver;
  final AppLogger _logger;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_shouldAttachAccessToken(options)) {
      handler.next(options);
      return;
    }
    if (_hasAuthorizationHeader(options.headers)) {
      handler.next(options);
      return;
    }

    final token = await _resolveAccessToken();
    if (token != null) {
      _setAuthorizationHeader(options.headers, token);
      _logger.debug('Token attached', context: _requestContext(options));
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    if (!_shouldRefresh(response)) {
      handler.next(response);
      return;
    }

    final refresher = _authTokenRefresherResolver();
    if (refresher == null) {
      handler.next(response);
      return;
    }

    try {
      final refreshed = await refresher.refreshToken();
      if (!refreshed) {
        handler.next(response);
        return;
      }
      final token = await _resolveAccessToken(refresher);
      if (token == null) {
        handler.next(response);
        return;
      }
      _logger.info(
        'Token refreshed for 401',
        context: _requestContext(response.requestOptions),
      );
      final retryResponse = await _retry(response.requestOptions, token);
      handler.resolve(retryResponse);
    } on DioException catch (error) {
      handler.reject(error);
    } catch (_) {
      handler.next(response);
    }
  }

  Future<String?> _resolveAccessToken([AuthTokenRefresher? refresher]) async {
    final token =
        await (refresher ?? _authTokenRefresherResolver())?.getAccessToken();
    final normalized = token?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  bool _shouldAttachAccessToken(RequestOptions options) {
    return _readBool(
      options.extra[apiAttachAccessTokenExtraKey],
      fallback: true,
    );
  }

  bool _shouldRefresh(Response response) {
    if (response.statusCode != 401) {
      return false;
    }
    final options = response.requestOptions;
    if (!_readBool(
      options.extra[apiEnableAuthRefreshExtraKey],
      fallback: true,
    )) {
      return false;
    }
    if (_retryAttempt(options) > 0) {
      return false;
    }
    return _shouldAttachAccessToken(options) ||
        _hasAuthorizationHeader(options.headers);
  }

  int _retryAttempt(RequestOptions options) {
    final value = options.extra[_authRetryAttemptExtraKey];
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<Response<dynamic>> _retry(
    RequestOptions requestOptions,
    String token,
  ) {
    final headers = Map<String, dynamic>.from(requestOptions.headers);
    _setAuthorizationHeader(headers, token);
    final extra = Map<String, dynamic>.from(requestOptions.extra);
    extra[_authRetryAttemptExtraKey] = _retryAttempt(requestOptions) + 1;

    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      cancelToken: requestOptions.cancelToken,
      options: Options(
        method: requestOptions.method,
        sendTimeout: requestOptions.sendTimeout,
        connectTimeout: requestOptions.connectTimeout,
        receiveTimeout: requestOptions.receiveTimeout,
        extra: extra,
        headers: headers,
        responseType: requestOptions.responseType,
        contentType: requestOptions.contentType,
        validateStatus: requestOptions.validateStatus,
        receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
        followRedirects: requestOptions.followRedirects,
        maxRedirects: requestOptions.maxRedirects,
        requestEncoder: requestOptions.requestEncoder,
        responseDecoder: requestOptions.responseDecoder,
        listFormat: requestOptions.listFormat,
      ),
    );
  }

  bool _readBool(Object? value, {required bool fallback}) {
    return value is bool ? value : fallback;
  }

  Map<String, Object?> _requestContext(RequestOptions options) {
    return <String, Object?>{
      'method': options.method,
      'url': options.uri.toString(),
    };
  }

  bool _hasAuthorizationHeader(Map<String, dynamic> headers) {
    return headers.keys.any(
      (key) => key.toString().toLowerCase() == 'authorization',
    );
  }

  void _setAuthorizationHeader(Map<String, dynamic> headers, String token) {
    headers.removeWhere(
      (key, _) => key.toString().toLowerCase() == 'authorization',
    );
    headers['Authorization'] = 'Bearer $token';
  }
}
