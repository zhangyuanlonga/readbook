import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import 'search_models.dart';
import 'search_system_settings_service.dart';
import 'server_online_search_service.dart';

export 'search_models.dart';

class SearchService {
  SearchService({
    AppLogger? logger,
    Object? searchHitCacheService,
    SearchSystemSettingsService? searchSystemSettingsService,
    int? maxConcurrentSources,
    Object? runtimePlatform,
    ServerOnlineSearchService? serverOnlineSearchService,
  }) : _logger = logger ?? AppLogger.instance,
       _searchSystemSettingsService =
           searchSystemSettingsService ?? SearchSystemSettingsService(),
       _serverOnlineSearchService =
           serverOnlineSearchService ?? ServerOnlineSearchService(),
       _maxConcurrentSources =
           maxConcurrentSources ??
           SearchSystemSettingsService.defaultMaxConcurrentSources;

  final AppLogger _logger;
  final SearchSystemSettingsService _searchSystemSettingsService;
  final ServerOnlineSearchService _serverOnlineSearchService;

  int _maxConcurrentSources;
  bool _searchDebugLoggingEnabled = false;
  bool _searchDebugLoggingSettingLoaded = false;

  void setSearchDebugLoggingEnabled(bool enabled) {
    _searchDebugLoggingEnabled = enabled;
    _searchDebugLoggingSettingLoaded = true;
  }

  void setMaxConcurrentSources(int value) {
    _maxConcurrentSources = value.clamp(
      SearchSystemSettingsService.minMaxConcurrentSources,
      SearchSystemSettingsService.maxMaxConcurrentSources,
    );
  }

  Future<SearchExecutionReport> search({
    required String keyword,
    int page = 1,
    int pageSize = 20,
    SearchCancellationToken? cancellationToken,
    SearchProgressCallback? onProgress,
    SearchContentMode contentMode = SearchContentMode.novel,
    SearchPlanScenario scenario = SearchPlanScenario.globalSearch,
    List<String>? sourceIds,
    bool aggregateByTitleAuthor = false,
  }) async {
    await _syncSearchDebugLoggingSetting();
    await _syncMaxConcurrentSourcesSetting();

    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        briefMessage: '搜索关键词不能为空。',
      );
    }

    final normalizedSourceIds = sourceIds
        ?.map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    _searchDebugInfo(
      'Server search started',
      context: <String, Object?>{
        'keyword': normalizedKeyword,
        'page': page,
        'pageSize': pageSize,
        'contentMode': contentMode.name,
        'scenario': scenario.name,
        'selectedSourceCount': normalizedSourceIds?.length ?? 0,
        'maxConcurrentSources': _maxConcurrentSources,
      },
    );

    final report = await _serverOnlineSearchService.search(
      keyword: normalizedKeyword,
      contentMode: contentMode,
      sourceIds: normalizedSourceIds,
      aggregateByTitleAuthor: aggregateByTitleAuthor,
      cancellationToken: cancellationToken,
      onProgress: onProgress,
    );

    _searchDebugInfo(
      'Server search finished',
      context: <String, Object?>{
        'keyword': normalizedKeyword,
        'successSources': report.successSourceCount,
        'failedSources': report.failedSourceCount,
        'bookCount': report.books.length,
      },
    );
    return report;
  }

  Future<void> _syncMaxConcurrentSourcesSetting() async {
    try {
      final value =
          await _searchSystemSettingsService.loadMaxConcurrentSources();
      setMaxConcurrentSources(value);
    } catch (_) {}
  }

  Future<void> _syncSearchDebugLoggingSetting() async {
    if (_searchDebugLoggingSettingLoaded) {
      return;
    }
    try {
      _searchDebugLoggingEnabled =
          await _searchSystemSettingsService.loadSearchDebugLogEnabled();
      _searchDebugLoggingSettingLoaded = true;
    } catch (_) {}
  }

  void _searchDebugInfo(
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    if (!_searchDebugLoggingEnabled) {
      return;
    }
    _logger.info(message, context: context);
  }
}
