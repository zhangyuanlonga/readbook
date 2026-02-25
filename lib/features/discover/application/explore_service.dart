import 'dart:convert';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/rule_engine/processors/legacy_script_rule_fallback.dart';
import '../../../core/rule_engine/processors/url_template_resolver.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/source_repository_impl.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/search_request_context.dart';
import '../../../domain/entities/source_definition.dart';
import '../../../domain/repositories/source_repository.dart';
import '../../search/application/search_service.dart';

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
  });

  final String title;
  final String? url;
  final ExploreCategoryStyle style;

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

class DiscoverSourceSummary {
  const DiscoverSourceSummary({
    required this.enabledSourceCount,
    required this.discoverCapableCount,
    required this.discoverSources,
  });

  final int enabledSourceCount;
  final int discoverCapableCount;
  final List<SourceDefinition> discoverSources;
}

class ExploreService {
  ExploreService({
    SourceRepository? sourceRepository,
    SearchService? searchService,
    UrlTemplateResolver? urlTemplateResolver,
  }) : _sourceRepository =
           sourceRepository ?? SourceRepositoryImpl(AppDatabase.instance),
       _searchService = searchService ?? SearchService(),
       _urlTemplateResolver =
           urlTemplateResolver ?? const UrlTemplateResolver();

  final SourceRepository _sourceRepository;
  final SearchService _searchService;
  final UrlTemplateResolver _urlTemplateResolver;

  Future<DiscoverSourceSummary> loadDiscoverSourceSummary() async {
    final sources = await _sourceRepository.getAll();
    final enabledSources = sources.where((source) => source.enabled).toList();
    final discoverSources = enabledSources
        .where((source) => source.supportsExplore)
        .toList(growable: false);

    return DiscoverSourceSummary(
      enabledSourceCount: enabledSources.length,
      discoverCapableCount: discoverSources.length,
      discoverSources: discoverSources,
    );
  }

  Future<List<SourceDefinition>> loadDiscoverSources() async {
    final summary = await loadDiscoverSourceSummary();
    return summary.discoverSources;
  }

  List<ExploreCategoryItem> parseCategories(SourceDefinition source) {
    final rawExploreUrl = source.exploreUrl?.trim();
    if (rawExploreUrl == null || rawExploreUrl.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.source,
        sourceId: source.id,
        briefMessage: '书源未配置 discoverUrl/exploreUrl。',
      );
    }

    final categories = _parseCategoriesFromText(rawExploreUrl);
    if (categories.isNotEmpty) {
      return categories;
    }

    final fromScript = _tryResolveExploreScript(rawExploreUrl);
    if (fromScript != null) {
      final scriptCategories = _parseCategoriesFromText(fromScript);
      if (scriptCategories.isNotEmpty) {
        return scriptCategories;
      }
    }

    throw AppException(
      code: ErrorCode.ruleParse,
      stage: ErrorStage.source,
      sourceId: source.id,
      briefMessage: '发现入口解析失败，当前规则可能依赖复杂 JS。',
    );
  }

  Future<ExploreBookPageResult> loadBooks({
    required SourceDefinition source,
    required ExploreCategoryItem category,
    required int page,
    int pageSize = 20,
  }) async {
    final categoryUrl = category.url?.trim();
    if (categoryUrl == null || categoryUrl.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        sourceId: source.id,
        briefMessage: '当前发现分类不可点击（缺少 URL）。',
      );
    }

    final mappedSource = _mapSourceToExploreSearch(
      source: source,
      categoryUrl: categoryUrl,
    );

    final result = await _searchService.searchSingleSource(
      source: mappedSource,
      keyword: category.title.trim().isEmpty ? source.name : category.title,
      page: page,
      pageSize: pageSize,
    );

    return ExploreBookPageResult(
      page: page,
      pageSize: pageSize,
      books: result.books,
      requestUrl: result.requestUrl,
      hasMore: result.books.length >= pageSize,
    );
  }

  SourceDefinition _mapSourceToExploreSearch({
    required SourceDefinition source,
    required String categoryUrl,
  }) {
    final rules = source.rules;
    final listRule = rules.exploreListRule?.trim();
    final titleRule = rules.exploreTitleRule?.trim();
    final detailUrlRule = rules.exploreDetailUrlRule?.trim();
    if (listRule == null ||
        listRule.isEmpty ||
        titleRule == null ||
        titleRule.isEmpty ||
        detailUrlRule == null ||
        detailUrlRule.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        sourceId: source.id,
        briefMessage: '发现规则不完整（缺少 bookList/name/bookUrl）。',
      );
    }

    return source.copyWith(
      rules: rules.copyWith(
        searchRule: categoryUrl,
        searchInitRule: rules.exploreInitRule,
        searchListRule: listRule,
        searchTitleRule: titleRule,
        searchDetailUrlRule: detailUrlRule,
        searchAuthorRule: rules.exploreAuthorRule,
        searchIntroRule: rules.exploreIntroRule,
        searchCoverUrlRule: rules.exploreCoverUrlRule,
        searchLatestChapterRule: rules.exploreLatestChapterRule,
      ),
    );
  }

  List<ExploreCategoryItem> _parseCategoriesFromText(String source) {
    final text = source.trim();
    if (text.isEmpty) {
      return const <ExploreCategoryItem>[];
    }

    final fromJson = _tryParseJsonCategories(text);
    if (fromJson.isNotEmpty) {
      return fromJson;
    }

    final fromPlain = _parsePlainTitleUrlLines(text);
    if (fromPlain.isNotEmpty) {
      return fromPlain;
    }

    final looksLikeSingleUrl = _looksLikeUrlTemplate(text);
    if (looksLikeSingleUrl) {
      return <ExploreCategoryItem>[ExploreCategoryItem(title: '推荐', url: text)];
    }

    return const <ExploreCategoryItem>[];
  }

  List<ExploreCategoryItem> _tryParseJsonCategories(String source) {
    dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      return const <ExploreCategoryItem>[];
    }

    if (decoded is! List) {
      return const <ExploreCategoryItem>[];
    }

    final categories = <ExploreCategoryItem>[];
    for (final entry in decoded) {
      if (entry is! Map) {
        continue;
      }

      final title = entry['title']?.toString().trim() ?? '';
      if (title.isEmpty) {
        continue;
      }

      final urlValue = entry['url']?.toString().trim();
      final styleMap = entry['style'];

      categories.add(
        ExploreCategoryItem(
          title: title,
          url: urlValue == null || urlValue.isEmpty ? null : urlValue,
          style: ExploreCategoryStyle(
            layoutFlexGrow: _asDouble(
              styleMap is Map ? styleMap['layout_flexGrow'] : null,
            ),
            layoutFlexBasisPercent: _asDouble(
              styleMap is Map ? styleMap['layout_flexBasisPercent'] : null,
            ),
          ),
        ),
      );
    }

    return categories;
  }

  List<ExploreCategoryItem> _parsePlainTitleUrlLines(String source) {
    final categories = <ExploreCategoryItem>[];
    for (final rawLine in source.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      final splitIndex = line.indexOf('::');
      if (splitIndex < 0) {
        continue;
      }

      final title = line.substring(0, splitIndex).trim();
      final url = line.substring(splitIndex + 2).trim();
      if (title.isEmpty) {
        continue;
      }

      categories.add(
        ExploreCategoryItem(title: title, url: url.isEmpty ? null : url),
      );
    }
    return categories;
  }

  String? _tryResolveExploreScript(String rawExploreUrl) {
    final normalized = rawExploreUrl.trim();
    final isScript =
        normalized.startsWith('@js:') ||
        normalized.startsWith('<js>') ||
        normalized.toLowerCase().contains('\n@js:') ||
        normalized.toLowerCase().contains('\r@js:');
    if (!isScript) {
      return null;
    }

    try {
      final result = LegacyScriptRuleFallback.evaluateFieldValue(
        content: '',
        rawRule: rawExploreUrl,
      );
      final output = result?.trim();
      if (output == null || output.isEmpty) {
        return null;
      }
      return output;
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeUrlTemplate(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return false;
    }

    if (text.startsWith('http://') || text.startsWith('https://')) {
      return true;
    }

    if (text.startsWith('/') ||
        text.startsWith('./') ||
        text.startsWith('../') ||
        text.startsWith('?')) {
      return true;
    }

    try {
      final resolved = _urlTemplateResolver.resolve(
        template: text,
        context: SearchRequestContext(
          keyword: 'discover',
          page: 1,
          pageSize: 20,
        ),
        baseUrl: 'https://example.com',
        encodeKeywordByDefault: false,
      );
      return resolved.startsWith('https://example.com') ||
          resolved.startsWith('http://') ||
          resolved.startsWith('https://');
    } catch (_) {
      // Keep category parser resilient when sources contain invalid templates.
      return text.contains('{{page') ||
          text.contains('{{key') ||
          text.contains('{{keyword');
    }
  }

  double? _asDouble(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString().trim());
  }
}
