import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/book_identity.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../../runtime/sources/source_result_models.dart' as runtime_models;
import '../../source/application/source_health_service.dart';
import '../../source/application/source_runtime_task_gate_service.dart';
import '../../source/application/source_runtime_facade.dart';

class ExploreCategoryStyle {
  const ExploreCategoryStyle({
    this.layoutFlexGrow,
    this.layoutFlexBasisPercent,
  });

  final double? layoutFlexGrow;
  final double? layoutFlexBasisPercent;
}

class ExploreCategoryItem {
  const ExploreCategoryItem({
    required this.title,
    this.url,
    this.style = const ExploreCategoryStyle(),
    this.extra = const <String, dynamic>{},
  });

  final String title;
  final String? url;
  final ExploreCategoryStyle style;
  final Map<String, dynamic> extra;

  bool get isActionable {
    final value = url?.trim();
    return value != null && value.isNotEmpty;
  }
}

class ExploreBookPageResult {
  const ExploreBookPageResult({
    required this.page,
    required this.pageSize,
    required this.books,
    required this.requestUrl,
    required this.hasMore,
  });

  final int page;
  final int pageSize;
  final List<Book> books;
  final String requestUrl;
  final bool hasMore;
}

class DiscoverSource {
  const DiscoverSource({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.group,
    this.sourceType = 0,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String? group;
  final int sourceType;

  bool get isMangaSource => sourceType == 2;
}

class DiscoverSourceSummary {
  const DiscoverSourceSummary({
    required this.enabledSourceCount,
    required this.discoverCapableCount,
    required this.discoverSources,
  });

  final int enabledSourceCount;
  final int discoverCapableCount;
  final List<DiscoverSource> discoverSources;
}

class ExploreService {
  ExploreService({
    SourceRuntimeFacade? sourceRuntimeFacade,
    SourceHealthService? sourceHealthService,
    SourceRuntimeTaskGateService? taskGateService,
    AppLogger? logger,
  }) : _sourceRuntimeFacade =
           sourceRuntimeFacade ?? SourceRuntimeFacade.instance,
       _sourceHealthService =
           sourceHealthService ?? SourceHealthService.instance,
       _taskGateService =
           taskGateService ?? SourceRuntimeTaskGateService.instance,
       _logger = logger ?? AppLogger.instance;

  final SourceRuntimeFacade? _sourceRuntimeFacade;
  final SourceHealthService _sourceHealthService;
  final SourceRuntimeTaskGateService _taskGateService;
  final AppLogger _logger;

  Future<DiscoverSourceSummary> loadDiscoverSourceSummary() async {
    final sources = await _loadAvailableScriptSources();
    final discoverSources = sources
        .where(_supportsRuntimeDiscover)
        .map(_mapScriptSourceToDiscoverSource)
        .toList(growable: false);

    return DiscoverSourceSummary(
      enabledSourceCount: sources.length,
      discoverCapableCount: discoverSources.length,
      discoverSources: discoverSources,
    );
  }

  bool _supportsRuntimeDiscover(RegisteredSource source) {
    final manifest = source.definition.manifest;
    return manifest.supportsCapability('discover') &&
        source.definition.discoverCategories != null &&
        source.definition.discoverBooks != null;
  }

  Future<List<DiscoverSource>> loadDiscoverSources() async {
    final summary = await loadDiscoverSourceSummary();
    return summary.discoverSources;
  }

  Future<List<ExploreCategoryItem>> parseCategories(
    DiscoverSource source, {
    bool evaluateScript = true,
    bool allowComplexJs = false,
  }) async {
    return _parseRuntimeCategories(source);
  }

  Future<ExploreBookPageResult> loadBooks({
    required DiscoverSource source,
    required ExploreCategoryItem category,
    required int page,
    int pageSize = 20,
  }) async {
    return _loadRuntimeBooks(
      source: source,
      category: category,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<List<RegisteredSource>> _loadAvailableScriptSources() async {
    final facade = _sourceRuntimeFacade;
    if (facade == null) {
      return const <RegisteredSource>[];
    }

    final persistedSources = await facade.listScriptSources();
    final enabledPersistedSourceIds =
        persistedSources
            .where((source) => source.enabled)
            .map((source) => source.id.trim())
            .where((id) => id.isNotEmpty)
            .toSet();

    var sources = facade.registeredScriptSources(enabledOnly: true);
    final runtimeSourceIds =
        sources
            .map((source) => source.runtime.id.trim())
            .where((id) => id.isNotEmpty)
            .toSet();
    final shouldReload =
        enabledPersistedSourceIds.isNotEmpty &&
        (runtimeSourceIds.length != enabledPersistedSourceIds.length ||
            !runtimeSourceIds.containsAll(enabledPersistedSourceIds));

    if (sources.isEmpty || shouldReload) {
      final report = await facade.reloadScriptSources();
      sources = report.loaded;
    }
    return sources;
  }

  DiscoverSource _mapScriptSourceToDiscoverSource(RegisteredSource source) {
    final manifest = source.definition.manifest;
    final homepage = manifest.homepage?.trim() ?? '';
    final firstDomain = manifest.domains.isEmpty ? '' : manifest.domains.first;
    final normalizedBaseUrl =
        homepage.isNotEmpty
            ? homepage
            : (firstDomain.isNotEmpty
                ? 'https://$firstDomain'
                : 'script://${source.runtime.id}');

    return DiscoverSource(
      id: source.runtime.id,
      name: source.runtime.name,
      baseUrl: normalizedBaseUrl,
      group: source.runtime.group.trim().isEmpty ? null : source.runtime.group,
      sourceType: _inferRuntimeSourceType(source),
    );
  }

  int _inferRuntimeSourceType(RegisteredSource source) {
    final manifest = source.definition.manifest;
    final isManga =
        manifest.supportsCapability('manga') ||
        manifest.supportsCapability('comic') ||
        manifest.supportsCapability('manhua') ||
        manifest.supportsCapability('manhwa');
    return isManga ? 2 : 0;
  }

  Future<List<ExploreCategoryItem>> _parseRuntimeCategories(
    DiscoverSource source,
  ) async {
    final facade = _sourceRuntimeFacade;
    if (facade == null) {
      _sourceHealthService.markDiscoverCategoriesFailure(
        sourceId: source.id,
        message: '书源运行时不可用。',
      );
      throw AppException(
        code: ErrorCode.unknownSource,
        stage: ErrorStage.source,
        sourceId: source.id,
        briefMessage: '书源运行时不可用。',
      );
    }
    try {
      final startedAt = DateTime.now();
      final registered = await _lookupRegisteredSource(source.id);
      final categories =
          registered == null
              ? await facade.discoverCategories(sourceId: source.id)
              : await _taskGateService
                  .run<List<runtime_models.DiscoverCategory>>(
                    source: registered,
                    taskKind: SourceRuntimeTaskKind.discoverCategories,
                    action:
                        () => facade.discoverCategories(sourceId: source.id),
                  );
      _sourceHealthService.markDiscoverCategoriesSuccess(sourceId: source.id);
      _logger.info(
        'Runtime discover categories success',
        context: <String, Object?>{
          'chain': 'discover',
          'step': 'discoverCategories',
          'sourceId': source.id,
          'sourceName': source.name,
          'categoryCount': categories.length,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        },
      );
      return categories
          .map(
            (item) => ExploreCategoryItem(
              title: item.title.trim().isEmpty ? '未命名分类' : item.title.trim(),
              url: item.url?.trim(),
              style: ExploreCategoryStyle(
                layoutFlexGrow: item.style.layoutFlexGrow,
                layoutFlexBasisPercent: item.style.layoutFlexBasisPercent,
              ),
              extra: item.extra,
            ),
          )
          .toList(growable: false);
    } on AppException catch (error) {
      _sourceHealthService.markDiscoverCategoriesFailure(
        sourceId: source.id,
        message: error.briefMessage,
        error: error,
      );
      _logger.warn(
        'Runtime discover categories failed',
        context: <String, Object?>{
          'chain': 'discover',
          'step': 'discoverCategories',
          'sourceId': source.id,
          'sourceName': source.name,
          'code': error.code.name,
          'stage': error.stage.name,
          'message': error.briefMessage,
        },
      );
      rethrow;
    } catch (error) {
      _sourceHealthService.markDiscoverCategoriesFailure(
        sourceId: source.id,
        message: error.toString(),
        error: error,
      );
      _logger.error(
        'Runtime discover categories crashed',
        exception: AppException(
          code: ErrorCode.unknown,
          stage: ErrorStage.source,
          sourceId: source.id,
          briefMessage: error.toString(),
          cause: error,
        ),
        context: <String, Object?>{
          'chain': 'discover',
          'step': 'discoverCategories',
          'sourceId': source.id,
          'sourceName': source.name,
        },
      );
      rethrow;
    }
  }

  Future<ExploreBookPageResult> _loadRuntimeBooks({
    required DiscoverSource source,
    required ExploreCategoryItem category,
    required int page,
    required int pageSize,
  }) async {
    final facade = _sourceRuntimeFacade;
    if (facade == null) {
      _sourceHealthService.markDiscoverBooksFailure(
        sourceId: source.id,
        message: '书源运行时不可用。',
      );
      throw AppException(
        code: ErrorCode.unknownSource,
        stage: ErrorStage.search,
        sourceId: source.id,
        briefMessage: '书源运行时不可用。',
      );
    }
    final runtimeCategory = runtime_models.DiscoverCategory(
      title: category.title,
      url: category.url,
      style: runtime_models.DiscoverCategoryStyle(
        layoutFlexGrow: category.style.layoutFlexGrow,
        layoutFlexBasisPercent: category.style.layoutFlexBasisPercent,
      ),
      extra: category.extra,
    );
    try {
      final startedAt = DateTime.now();
      final registered = await _lookupRegisteredSource(source.id);
      final runtimeBooks =
          registered == null
              ? await facade.discoverBooks(
                sourceId: source.id,
                category: runtimeCategory,
                page: page,
                pageSize: pageSize,
              )
              : await _taskGateService.run<List<runtime_models.Book>>(
                source: registered,
                taskKind: SourceRuntimeTaskKind.discoverBooks,
                action:
                    () => facade.discoverBooks(
                      sourceId: source.id,
                      category: runtimeCategory,
                      page: page,
                      pageSize: pageSize,
                    ),
              );
      _sourceHealthService.markDiscoverBooksSuccess(sourceId: source.id);
      _logger.info(
        'Runtime discover books success',
        context: <String, Object?>{
          'chain': 'discover',
          'step': 'discoverBooks',
          'sourceId': source.id,
          'sourceName': source.name,
          'categoryTitle': category.title,
          'page': page,
          'pageSize': pageSize,
          'bookCount': runtimeBooks.length,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        },
      );
      final books = runtimeBooks
          .map((book) => _mapRuntimeBookToDomain(book, sourceId: source.id))
          .toList(growable: false);
      return ExploreBookPageResult(
        page: page,
        pageSize: pageSize,
        books: books,
        requestUrl: '',
        hasMore: books.length >= pageSize,
      );
    } on AppException catch (error) {
      _sourceHealthService.markDiscoverBooksFailure(
        sourceId: source.id,
        message: error.briefMessage,
        error: error,
      );
      _logger.warn(
        'Runtime discover books failed',
        context: <String, Object?>{
          'chain': 'discover',
          'step': 'discoverBooks',
          'sourceId': source.id,
          'sourceName': source.name,
          'categoryTitle': category.title,
          'page': page,
          'pageSize': pageSize,
          'code': error.code.name,
          'stage': error.stage.name,
          'message': error.briefMessage,
        },
      );
      rethrow;
    } catch (error) {
      _sourceHealthService.markDiscoverBooksFailure(
        sourceId: source.id,
        message: error.toString(),
        error: error,
      );
      _logger.error(
        'Runtime discover books crashed',
        exception: AppException(
          code: ErrorCode.unknown,
          stage: ErrorStage.search,
          sourceId: source.id,
          briefMessage: error.toString(),
          cause: error,
        ),
        context: <String, Object?>{
          'chain': 'discover',
          'step': 'discoverBooks',
          'sourceId': source.id,
          'sourceName': source.name,
          'categoryTitle': category.title,
          'page': page,
          'pageSize': pageSize,
        },
      );
      rethrow;
    }
  }

  Book _mapRuntimeBookToDomain(
    runtime_models.Book book, {
    required String sourceId,
  }) {
    final normalizedDetailUrl = book.detailUrl.trim();
    final identity = BookIdentity.remote(
      sourceId: sourceId,
      detailUrl: normalizedDetailUrl,
      fallbackTitle: book.title,
    );
    return Book(
      id: identity.logicalBookId,
      sourceId: sourceId,
      title: book.title.trim().isEmpty ? '未命名书籍' : book.title.trim(),
      detailUrl: normalizedDetailUrl,
      author: _normalizeOptionalText(book.author),
      intro: _normalizeOptionalText(book.intro),
      coverUrl: _normalizeOptionalText(book.cover),
      latestChapter: _normalizeOptionalText(book.latestChapter),
      wordCount: _normalizeOptionalText(book.wordCount),
      category: _normalizeOptionalText(book.category),
      tags: book.tags
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      updateTime: _normalizeOptionalText(book.updateTime),
    );
  }

  String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Future<RegisteredSource?> _lookupRegisteredSource(String sourceId) async {
    final facade = _sourceRuntimeFacade;
    return facade == null
        ? null
        : await facade.ensureRegisteredScriptSourceById(sourceId);
  }
}
