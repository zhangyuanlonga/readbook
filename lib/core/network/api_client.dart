import 'dart:async';
import 'dart:convert';
import 'dart:collection';

import 'package:dio/dio.dart';

import '../cache/app_cache_coordinator.dart';
import '../cache/cache_entry.dart';
import '../cache/cache_key.dart';
import '../cache/cache_policy.dart';
import '../cache/cache_result.dart';
import '../cache/cache_scope.dart';
import '../cache/cache_store.dart';
import '../cache/cache_trace.dart';
import '../errors/app_exception.dart';
import '../errors/error_codes.dart';
import '../errors/error_stage.dart';
import '../errors/gateway_failure.dart';
import '../logging/app_logger.dart';
import 'auth_interceptor.dart';
import 'auth_token_refresher.dart';
import 'interceptors.dart';

enum ApiMethod { get, post, put, delete, patch, head }

enum ApiCachePolicy { realtime, shortCache, longCache }

typedef ApiDataDecoder<T> = T Function(Object? data);
typedef ApiCacheUserIdResolver = Future<String?> Function();

class ApiResponse<T> {
  const ApiResponse({
    required this.code,
    required this.message,
    required this.data,
    this.failure,
  });

  final String code;
  final String message;
  final T data;
  final GatewayFailure? failure;

  bool get isOk => code == 'OK';
}

class ApiException extends AppException {
  const ApiException({
    required super.code,
    required super.briefMessage,
    required this.apiCode,
    this.statusCode,
    super.stage,
    super.requestUrl,
    super.gatewayFailure,
    super.cause,
    super.stackTrace,
  });

  final String apiCode;
  final int? statusCode;
}

class ApiRequestSpec<T> {
  const ApiRequestSpec({
    required this.method,
    required this.path,
    required this.decoder,
    this.queryParameters = const <String, dynamic>{},
    this.body,
    this.headers = const <String, String>{},
    this.timeout,
    this.maxRetries,
    this.enableRetry = true,
    this.enableCache = false,
    this.cachePolicy = ApiCachePolicy.realtime,
    this.cacheTtl,
    this.attachAccessToken = true,
    this.enableAuthRefresh = true,
    this.stage = ErrorStage.unknown,
  });

  static ApiRequestSpec<Map<String, dynamic>> jsonObject({
    required ApiMethod method,
    required String path,
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? body,
    Map<String, String> headers = const <String, String>{},
    Duration? timeout,
    int? maxRetries,
    bool enableRetry = true,
    bool enableCache = false,
    ApiCachePolicy cachePolicy = ApiCachePolicy.realtime,
    Duration? cacheTtl,
    bool attachAccessToken = true,
    bool enableAuthRefresh = true,
    ErrorStage stage = ErrorStage.unknown,
  }) {
    return ApiRequestSpec<Map<String, dynamic>>(
      method: method,
      path: path,
      queryParameters: queryParameters,
      body: body,
      headers: headers,
      timeout: timeout,
      maxRetries: maxRetries,
      enableRetry: enableRetry,
      enableCache: enableCache,
      cachePolicy: cachePolicy,
      cacheTtl: cacheTtl,
      attachAccessToken: attachAccessToken,
      enableAuthRefresh: enableAuthRefresh,
      stage: stage,
      decoder: ApiJsonDecoders.mapObject,
    );
  }

  final ApiMethod method;
  final String path;
  final Map<String, dynamic> queryParameters;
  final Object? body;
  final Map<String, String> headers;
  final Duration? timeout;
  final int? maxRetries;
  final bool enableRetry;
  final bool enableCache;
  final ApiCachePolicy cachePolicy;
  final Duration? cacheTtl;
  final bool attachAccessToken;
  final bool enableAuthRefresh;
  final ErrorStage stage;
  final ApiDataDecoder<T> decoder;
}

final class ApiJsonDecoders {
  const ApiJsonDecoders._();

  static Map<String, dynamic> mapObject(Object? data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    throw const FormatException('Invalid response payload.');
  }

  static List<Map<String, dynamic>> mapObjectList(Object? data) {
    if (data is! List) {
      throw const FormatException('Invalid response payload.');
    }
    return data
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList(growable: false);
  }
}

class ApiClient {
  static AuthTokenRefresher? defaultAuthTokenRefresher;
  static ApiCacheUserIdResolver? defaultCacheUserIdResolver;
  static final ApiCacheStore defaultCacheStore = ApiCacheStore();

  /// Installs the shared auth interceptor on a Dio instance once.
  ///
  /// Use this for direct Dio clients that cannot go through [ApiClient], for
  /// example SSE streaming endpoints that need `ResponseType.stream`.
  static void installAuthInterceptor(
    Dio dio, {
    AuthTokenRefresher? Function()? authTokenRefresherResolver,
  }) {
    if (dio.interceptors.whereType<AuthInterceptor>().isNotEmpty) {
      return;
    }
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        authTokenRefresherResolver:
            authTokenRefresherResolver ??
            () => ApiClient.defaultAuthTokenRefresher,
      ),
    );
  }

  ApiClient({
    Dio? dio,
    AppLogger? logger,
    String baseUrl = '',
    Duration defaultTimeout = const Duration(seconds: 12),
    int defaultMaxRetries = 2,
    Duration defaultCacheTtl = const Duration(minutes: 5),
    Duration defaultLongCacheTtl = const Duration(hours: 6),
    ApiCacheStore? cacheStore,
    AppCacheCoordinator? cacheCoordinator,
    Map<String, String> defaultHeaders = const {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
    AuthTokenRefresher? authTokenRefresher,
    ApiCacheUserIdResolver? cacheUserIdResolver,
  }) : _dio = dio ?? Dio(),
       _logger = logger ?? AppLogger.instance,
       _baseUrl = baseUrl.trim(),
       _defaultTimeout = defaultTimeout,
       _defaultMaxRetries = defaultMaxRetries,
       _defaultCacheTtl = defaultCacheTtl,
       _defaultLongCacheTtl = defaultLongCacheTtl,
       _cacheStore = cacheStore ?? ApiClient.defaultCacheStore,
       _cacheCoordinator = cacheCoordinator ?? AppCacheCoordinator(),
       _defaultHeaders = Map.unmodifiable({...defaultHeaders}),
       _authTokenRefresher =
           authTokenRefresher ?? ApiClient.defaultAuthTokenRefresher,
       _cacheUserIdResolver =
           cacheUserIdResolver ?? ApiClient.defaultCacheUserIdResolver {
    ApiClient.installAuthInterceptor(
      _dio,
      authTokenRefresherResolver:
          () => _authTokenRefresher ?? ApiClient.defaultAuthTokenRefresher,
    );
    if (_dio.interceptors.whereType<NetworkLogInterceptor>().isEmpty) {
      _dio.interceptors.add(NetworkLogInterceptor(_logger));
    }
    _cacheCoordinator.registerStore(_cacheStore);
  }

  final Dio _dio;
  final AppLogger _logger;
  final String _baseUrl;
  final Duration _defaultTimeout;
  final int _defaultMaxRetries;
  final Duration _defaultCacheTtl;
  final Duration _defaultLongCacheTtl;
  final ApiCacheStore _cacheStore;
  final AppCacheCoordinator _cacheCoordinator;
  final Map<String, String> _defaultHeaders;
  final AuthTokenRefresher? _authTokenRefresher;
  final ApiCacheUserIdResolver? _cacheUserIdResolver;

  Future<T> request<T>({
    required ApiMethod method,
    required String path,
    Map<String, dynamic> queryParameters = const {},
    Object? body,
    Map<String, String> headers = const {},
    Duration? timeout,
    int? maxRetries,
    bool enableRetry = true,
    bool enableCache = false,
    ApiCachePolicy cachePolicy = ApiCachePolicy.realtime,
    Duration? cacheTtl,

    /// Authenticated requests are the default. Public endpoints should pass
    /// `attachAccessToken: false` explicitly to avoid leaking stale sessions.
    bool attachAccessToken = true,
    bool enableAuthRefresh = true,
    ErrorStage stage = ErrorStage.unknown,
    T Function(Object? data)? decoder,
  }) async {
    final url = _resolveUrl(path);
    final attempts =
        _isIdempotent(method) && enableRetry
            ? (maxRetries ?? _defaultMaxRetries) + 1
            : 1;
    final resolvedCachePolicy = cachePolicy;
    final shouldUseCache =
        enableCache &&
        resolvedCachePolicy != ApiCachePolicy.realtime &&
        _isIdempotent(method);
    final cacheUserId = await _resolveCacheUserId(attachAccessToken);
    final cacheKey = _cacheKey(
      method: method,
      url: url,
      queryParameters: queryParameters,
      userId: cacheUserId,
    );

    if (shouldUseCache) {
      final cached = _cacheStore.get<T>(cacheKey);
      if (cached != null) {
        return cached;
      }
    }

    final resolvedHeaders = <String, String>{..._defaultHeaders, ...headers};

    for (var attempt = 1; attempt <= attempts; attempt++) {
      final start = DateTime.now();
      try {
        Response<String> response = await _dio.request<String>(
          url,
          data: body,
          queryParameters: queryParameters.isEmpty ? null : queryParameters,
          options: Options(
            method: _methodText(method),
            responseType: ResponseType.plain,
            headers: resolvedHeaders,
            sendTimeout: timeout ?? _defaultTimeout,
            connectTimeout: timeout ?? _defaultTimeout,
            receiveTimeout: timeout ?? _defaultTimeout,
            extra: <String, Object?>{
              apiAttachAccessTokenExtraKey: attachAccessToken,
              apiEnableAuthRefreshExtraKey: enableAuthRefresh,
            },
            validateStatus:
                (statusCode) => statusCode != null && statusCode < 600,
          ),
        );

        var statusCode = response.statusCode ?? 0;
        if (statusCode >= 500) {
          final shouldRetry = attempt < attempts;
          _logApiFailure(
            url: url,
            elapsed: DateTime.now().difference(start),
            code: 'HTTP_$statusCode',
            message: '网络异常',
          );
          if (shouldRetry) {
            await _delayForRetry(attempt);
            continue;
          }
          final errorEnvelope = _tryParseEnvelope(response.data);
          if (errorEnvelope != null && !errorEnvelope.isOk) {
            throw _mapApiError(
              envelope: errorEnvelope,
              statusCode: statusCode,
              stage: stage,
              requestUrl: url,
            );
          }
          throw NetworkException(
            briefMessage: '网络异常，状态码：$statusCode',
            stage: stage,
            requestUrl: url,
          );
        }

        final envelope = _parseEnvelope(response.data);
        if (!envelope.isOk) {
          _logApiFailure(
            url: url,
            elapsed: DateTime.now().difference(start),
            code: envelope.code,
            message: envelope.message,
          );
          throw _mapApiError(
            envelope: envelope,
            statusCode: statusCode,
            stage: stage,
            requestUrl: url,
          );
        }

        final data = _decodeData<T>(envelope.data, decoder);
        _logger.info(
          'API response',
          context: {
            'path': url,
            'costMs': DateTime.now().difference(start).inMilliseconds,
            'code': envelope.code,
            'message': envelope.message,
          },
        );

        if (shouldUseCache) {
          _cacheStore.set(
            cacheKey,
            data,
            cacheTtl ?? _defaultTtlForPolicy(resolvedCachePolicy),
          );
        }

        return data;
      } on DioException catch (error) {
        final shouldRetry = attempt < attempts && _isRetryable(error);
        _logApiFailure(
          url: url,
          elapsed: DateTime.now().difference(start),
          code: error.type.name,
          message: error.message ?? '网络请求失败',
        );
        if (shouldRetry) {
          await _delayForRetry(attempt);
          continue;
        }

        final message = _buildExceptionMessage(error);
        throw NetworkException(
          briefMessage: message,
          stage: stage,
          requestUrl: url,
          cause: error,
          stackTrace: error.stackTrace,
        );
      } on FormatException catch (error) {
        _logApiFailure(
          url: url,
          elapsed: DateTime.now().difference(start),
          code: 'DECODE_ERROR',
          message: error.message,
        );
        throw DecodeException(
          briefMessage: '响应解析失败，请稍后重试。',
          stage: stage,
          requestUrl: url,
          cause: error,
        );
      }
    }

    throw NetworkException(
      briefMessage: '网络请求失败：未知错误',
      stage: stage,
      requestUrl: url,
    );
  }

  Future<T> requestSpec<T>(ApiRequestSpec<T> spec) {
    return request<T>(
      method: spec.method,
      path: spec.path,
      queryParameters: spec.queryParameters,
      body: spec.body,
      headers: spec.headers,
      timeout: spec.timeout,
      maxRetries: spec.maxRetries,
      enableRetry: spec.enableRetry,
      enableCache: spec.enableCache,
      cachePolicy: spec.cachePolicy,
      cacheTtl: spec.cacheTtl,
      attachAccessToken: spec.attachAccessToken,
      enableAuthRefresh: spec.enableAuthRefresh,
      stage: spec.stage,
      decoder: spec.decoder,
    );
  }

  void clearCache() {
    unawaited(_cacheCoordinator.clearScope(scope: AppCacheScope.apiResponse));
  }

  String _resolveUrl(String path) {
    final normalized = path.trim();
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }
    if (_baseUrl.isEmpty) {
      return normalized;
    }
    final baseUri = Uri.parse(_baseUrl);
    if (normalized.startsWith('/')) {
      final basePath = baseUri.path.trim();
      if (basePath.isNotEmpty && basePath != '/') {
        final normalizedBasePath =
            basePath.endsWith('/')
                ? basePath.substring(0, basePath.length - 1)
                : basePath;
        return baseUri
            .replace(path: '$normalizedBasePath$normalized')
            .toString();
      }
    }
    return baseUri.resolve(normalized).toString();
  }

  String _methodText(ApiMethod method) {
    return switch (method) {
      ApiMethod.get => 'GET',
      ApiMethod.post => 'POST',
      ApiMethod.put => 'PUT',
      ApiMethod.delete => 'DELETE',
      ApiMethod.patch => 'PATCH',
      ApiMethod.head => 'HEAD',
    };
  }

  bool _isIdempotent(ApiMethod method) {
    return method == ApiMethod.get || method == ApiMethod.head;
  }

  AppCacheKey _cacheKey({
    required ApiMethod method,
    required String url,
    required Map<String, dynamic> queryParameters,
    required String? userId,
  }) {
    final owner = (userId ?? '').trim().isEmpty ? 'public' : userId!.trim();
    final sorted = SplayTreeMap<String, dynamic>.from(queryParameters);
    return AppCacheKey(
      scope: AppCacheScope.apiResponse,
      owner: owner,
      parts: <String, Object?>{
        'method': _methodText(method),
        'url': url,
        for (final entry in sorted.entries) 'query.${entry.key}': entry.value,
      },
    );
  }

  Duration _defaultTtlForPolicy(ApiCachePolicy policy) {
    return switch (policy) {
      ApiCachePolicy.realtime => Duration.zero,
      ApiCachePolicy.shortCache => _defaultCacheTtl,
      ApiCachePolicy.longCache => _defaultLongCacheTtl,
    };
  }

  Future<String?> _resolveCacheUserId(bool attachAccessToken) async {
    if (!attachAccessToken) {
      return null;
    }
    final resolver =
        _cacheUserIdResolver ?? ApiClient.defaultCacheUserIdResolver;
    if (resolver == null) {
      return null;
    }
    final userId = await resolver();
    final normalized = userId?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  ApiResponse<Object?> _parseEnvelope(Object? payload) {
    if (payload == null) {
      throw const FormatException('Empty response');
    }

    final decoded = payload is String ? jsonDecode(payload) : payload;
    if (decoded is! Map) {
      throw const FormatException('Invalid response shape');
    }

    final map = decoded.map((key, value) => MapEntry(key.toString(), value));
    final code = (map['code']?.toString() ?? '').trim();
    final message = (map['message']?.toString() ?? '').trim();
    if (code.isEmpty) {
      throw const FormatException('Missing response code');
    }

    return ApiResponse<Object?>(
      code: code,
      message: message.isEmpty ? _defaultMessageForCode(code) : message,
      data: map['data'],
      failure: GatewayFailure.tryParse(map['failure']),
    );
  }

  ApiResponse<Object?>? _tryParseEnvelope(Object? payload) {
    try {
      return _parseEnvelope(payload);
    } catch (_) {
      return null;
    }
  }

  T _decodeData<T>(Object? data, T Function(Object? data)? decoder) {
    if (decoder != null) {
      return decoder(data);
    }
    return data as T;
  }

  ApiException _mapApiError({
    required ApiResponse<Object?> envelope,
    required int statusCode,
    required ErrorStage stage,
    required String requestUrl,
  }) {
    final apiCode = envelope.code;
    final failure = envelope.failure;
    final mapped =
        failure?.toErrorCode() ??
        switch (apiCode) {
          'INVALID_ARGUMENT' => ErrorCode.validation,
          'NOT_FOUND' => ErrorCode.unknownSource,
          'INTERNAL_ERROR' => ErrorCode.unknown,
          _ => ErrorCode.unknown,
        };
    final mappedStage = failure?.toErrorStage(fallback: stage) ?? stage;
    final message =
        failure?.message.trim().isNotEmpty == true
            ? failure!.message
            : envelope.message;

    return ApiException(
      code: mapped,
      briefMessage: message,
      apiCode: apiCode,
      statusCode: statusCode,
      stage: mappedStage,
      requestUrl: requestUrl,
      gatewayFailure: failure,
    );
  }

  String _defaultMessageForCode(String code) {
    return switch (code) {
      'OK' => 'success',
      'INVALID_ARGUMENT' => '参数错误',
      'NOT_FOUND' => '资源不存在',
      'INTERNAL_ERROR' => '系统繁忙，请稍后重试',
      _ => '请求失败',
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

  Future<void> _delayForRetry(int attempt) {
    return Future<void>.delayed(Duration(milliseconds: 250 * attempt));
  }

  void _logApiFailure({
    required String url,
    required Duration elapsed,
    required String code,
    required String message,
  }) {
    _logger.warn(
      'API error',
      context: {
        'path': url,
        'costMs': elapsed.inMilliseconds,
        'code': code,
        'message': message,
      },
    );
  }
}

class ApiCacheStore implements AppCacheStore {
  ApiCacheStore({AppCacheTracer? tracer})
    : _tracer = tracer ?? AppCacheTracer();

  final Map<String, _ApiCacheEntry> _entries = <String, _ApiCacheEntry>{};
  final AppCacheTracer _tracer;

  @override
  AppCacheScope get scope => AppCacheScope.apiResponse;

  @override
  String get backendName => 'memory.api_response';

  T? get<T>(Object key) {
    final cacheKey = _normalizeKey(key);
    final storageKey = _storageKey(key);
    final entry = _entries[storageKey];
    if (entry == null) {
      if (cacheKey != null) {
        _tracer.traceRead(
          AppCacheReadResult.miss(key: cacheKey, backend: backendName),
        );
      }
      return null;
    }
    final now = DateTime.now();
    if (!entry.expiresAt.isAfter(now)) {
      _entries.remove(storageKey);
      if (entry.key != null) {
        _tracer.traceRead(
          AppCacheReadResult.stale(
            key: entry.key!,
            backend: backendName,
            entry: entry.toAppEntry(),
            invalidReason: AppCacheInvalidReason.ttlExpired,
          ),
        );
      }
      return null;
    }
    if (entry.key != null) {
      _tracer.traceRead(
        AppCacheReadResult.hit(
          key: entry.key!,
          backend: backendName,
          entry: entry.toAppEntry(),
        ),
      );
    }
    return entry.value as T?;
  }

  void set<T>(Object key, T value, Duration ttl) {
    if (ttl <= Duration.zero) {
      return;
    }
    final cacheKey = _normalizeKey(key);
    final storageKey = _storageKey(key);
    _entries[storageKey] = _ApiCacheEntry(
      key: cacheKey,
      value: value,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(ttl),
    );
    if (cacheKey != null) {
      _tracer.traceWrite(
        AppCacheWriteResult.written(key: cacheKey, backend: backendName),
      );
    }
  }

  void invalidate(Object key) {
    _entries.remove(_storageKey(key));
  }

  void clear() {
    _entries.clear();
  }

  @override
  Future<AppCacheReadResult> read(
    AppCacheKey key, {
    AppCachePolicy? policy,
  }) async {
    final entry = _entries[key.toStorageKey()];
    if (entry == null) {
      return AppCacheReadResult.miss(key: key, backend: backendName);
    }
    if (!entry.expiresAt.isAfter(DateTime.now())) {
      _entries.remove(key.toStorageKey());
      return AppCacheReadResult.stale(
        key: key,
        backend: backendName,
        entry: entry.toAppEntry(keyOverride: key),
        invalidReason: AppCacheInvalidReason.ttlExpired,
      );
    }
    return AppCacheReadResult.hit(
      key: key,
      backend: backendName,
      entry: entry.toAppEntry(keyOverride: key),
    );
  }

  @override
  Future<AppCacheWriteResult> write(
    AppCacheEntry entry, {
    AppCachePolicy? policy,
  }) async {
    final expiresAt =
        entry.expiresAt ??
        policy?.expiresAtFor(entry.createdAt) ??
        DateTime.now().add(const Duration(minutes: 5));
    if (!expiresAt.isAfter(DateTime.now())) {
      return AppCacheWriteResult.skipped(key: entry.key, backend: backendName);
    }
    _entries[entry.key.toStorageKey()] = _ApiCacheEntry(
      key: entry.key,
      value: entry.payload,
      createdAt: entry.createdAt,
      expiresAt: expiresAt,
    );
    return AppCacheWriteResult.written(
      key: entry.key,
      backend: backendName,
      sizeBytes: entry.sizeBytes,
    );
  }

  @override
  Future<AppCacheDeleteResult> delete(AppCacheKey key) async {
    final removed = _entries.remove(key.toStorageKey());
    return AppCacheDeleteResult.deleted(
      scope: scope,
      backend: backendName,
      key: key,
      deletedEntries: removed == null ? 0 : 1,
    );
  }

  @override
  Future<AppCacheDeleteResult> clearScope({String? owner}) async {
    final normalizedOwner = owner?.trim() ?? '';
    if (normalizedOwner.isEmpty) {
      final deleted = _entries.length;
      _entries.clear();
      return AppCacheDeleteResult.deleted(
        scope: scope,
        backend: backendName,
        deletedEntries: deleted,
      );
    }
    final keys = _entries.entries
        .where((entry) => entry.value.key?.owner == normalizedOwner)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in keys) {
      _entries.remove(key);
    }
    return AppCacheDeleteResult.deleted(
      scope: scope,
      backend: backendName,
      deletedEntries: keys.length,
    );
  }

  @override
  Future<AppCacheStats> stats({String? owner}) async {
    final normalizedOwner = owner?.trim() ?? '';
    final entries = _entries.values
        .where(
          (entry) =>
              normalizedOwner.isEmpty || entry.key?.owner == normalizedOwner,
        )
        .toList(growable: false);
    return AppCacheStats(
      scope: scope,
      backend: backendName,
      entries: entries.length,
      bytes: 0,
    );
  }

  @override
  Future<AppCachePruneResult> prune(AppCachePolicy policy) async {
    final before = _entries.length;
    final now = DateTime.now();
    _entries.removeWhere((_, entry) => !entry.expiresAt.isAfter(now));
    final maxEntries = policy.maxEntries;
    if (maxEntries != null && maxEntries >= 0 && _entries.length > maxEntries) {
      final sorted =
          _entries.entries.toList()
            ..sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));
      final overflow = _entries.length - maxEntries;
      for (final entry in sorted.take(overflow)) {
        _entries.remove(entry.key);
      }
    }
    return AppCachePruneResult(
      scope: scope,
      backend: backendName,
      deletedEntries: before - _entries.length,
    );
  }

  AppCacheKey? _normalizeKey(Object key) {
    return key is AppCacheKey ? key : null;
  }

  String _storageKey(Object key) {
    return key is AppCacheKey ? key.toStorageKey() : key.toString();
  }
}

class _ApiCacheEntry {
  _ApiCacheEntry({
    required this.value,
    required this.expiresAt,
    required this.createdAt,
    this.key,
  });

  final AppCacheKey? key;
  final Object? value;
  final DateTime expiresAt;
  final DateTime createdAt;

  AppCacheEntry toAppEntry({AppCacheKey? keyOverride}) {
    final resolvedKey =
        keyOverride ??
        key ??
        AppCacheKey(scope: AppCacheScope.apiResponse, owner: 'legacy');
    return AppCacheEntry(
      key: resolvedKey,
      payload: value,
      createdAt: createdAt,
      updatedAt: createdAt,
      lastAccessedAt: DateTime.now(),
      expiresAt: expiresAt,
    );
  }
}
