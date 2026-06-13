import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../domain/entities/announcement.dart';

class AnnouncementService {
  AnnouncementService({ApiClient? client, String? baseUrl})
    : _baseUrl = (baseUrl ?? AppApiConfig.baseUrl).trim(),
      _client =
          client ??
          ApiClient(baseUrl: (baseUrl ?? AppApiConfig.baseUrl).trim());

  static const Duration _latestCacheTtl = Duration(minutes: 5);
  static Announcement? _latestCache;
  static DateTime? _latestCacheAt;
  static Future<Announcement?>? _latestInFlight;

  final ApiClient _client;
  final String _baseUrl;

  Future<AnnouncementPage> fetchAnnouncements({
    int page = 1,
    int pageSize = 20,
    bool useCache = true,
  }) async {
    _ensureBaseUrl();
    try {
      final data = await _client.request<Map<String, dynamic>>(
        method: ApiMethod.get,
        path: '/v1/announcements',
        queryParameters: {'page': page, 'page_size': pageSize},
        attachAccessToken: false,
        enableCache: useCache,
        cachePolicy: ApiCachePolicy.shortCache,
        cacheTtl: const Duration(minutes: 5),
        stage: ErrorStage.unknown,
        decoder: _decodeMap,
      );
      return AnnouncementPage.fromJson(data);
    } on ApiException catch (error) {
      if (error.apiCode == 'NOT_FOUND') {
        return AnnouncementPage(
          items: const <Announcement>[],
          page: page,
          pageSize: pageSize,
          total: 0,
        );
      }
      rethrow;
    }
  }

  Future<Announcement?> fetchLatestAnnouncement({bool useCache = true}) async {
    _ensureBaseUrl();
    if (useCache) {
      final cached = _latestCache;
      final cachedAt = _latestCacheAt;
      if (cached != null &&
          cachedAt != null &&
          DateTime.now().difference(cachedAt) < _latestCacheTtl) {
        return cached;
      }
      final inflight = _latestInFlight;
      if (inflight != null) {
        return inflight;
      }
    }
    Future<Announcement?> task() async {
      try {
        final data = await _client.request<Object?>(
          method: ApiMethod.get,
          path: '/v1/announcements/latest',
          attachAccessToken: false,
          enableCache: useCache,
          cachePolicy: ApiCachePolicy.shortCache,
          cacheTtl: _latestCacheTtl,
          stage: ErrorStage.unknown,
        );
        if (data is! Map) {
          _latestCache = null;
          _latestCacheAt = null;
          return null;
        }
        final announcement = Announcement.fromJson(
          data.map((key, value) => MapEntry(key.toString(), value)),
        );
        _latestCache = announcement;
        _latestCacheAt = DateTime.now();
        return announcement;
      } on ApiException catch (error) {
        if (error.apiCode == 'NOT_FOUND') {
          _latestCache = null;
          _latestCacheAt = null;
          return null;
        }
        rethrow;
      }
    }

    final future = task().whenComplete(() {
      _latestInFlight = null;
    });

    if (useCache) {
      _latestInFlight = future;
    }
    return future;
  }

  Future<Announcement> fetchAnnouncementDetail(
    String id, {
    bool useCache = true,
  }) async {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      throw const AppException(
        code: ErrorCode.validation,
        briefMessage: '公告 ID 不能为空。',
        stage: ErrorStage.unknown,
      );
    }
    _ensureBaseUrl();
    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.get,
      path: '/v1/announcements/$normalized',
      attachAccessToken: false,
      enableCache: useCache,
      cachePolicy: ApiCachePolicy.shortCache,
      cacheTtl: const Duration(minutes: 10),
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );
    return Announcement.fromJson(data);
  }

  void clearCache() {
    _client.clearCache();
    _latestCache = null;
    _latestCacheAt = null;
    _latestInFlight = null;
  }

  void _ensureBaseUrl() {
    if (_baseUrl.isNotEmpty) {
      return;
    }
    throw const AppException(
      code: ErrorCode.validation,
      briefMessage: '缺少公告服务地址，请配置 APPREAD_API_BASE_URL。',
      stage: ErrorStage.unknown,
    );
  }

  Map<String, dynamic> _decodeMap(Object? data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    throw const FormatException('Invalid response payload.');
  }
}
