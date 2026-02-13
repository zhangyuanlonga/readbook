import 'package:dio/dio.dart';

import '../logging/app_logger.dart';

class NetworkLogInterceptor extends Interceptor {
  NetworkLogInterceptor(this._logger);

  final AppLogger _logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.info(
      'HTTP request',
      context: {'method': options.method, 'url': options.uri.toString()},
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logger.info(
      'HTTP response',
      context: {
        'statusCode': response.statusCode,
        'url': response.requestOptions.uri.toString(),
      },
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.warn(
      'HTTP error',
      context: {
        'type': err.type.name,
        'url': err.requestOptions.uri.toString(),
        'message': err.message,
        'error': err.error?.toString(),
      },
    );
    handler.next(err);
  }
}
