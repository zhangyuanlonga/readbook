import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../app/layout/app_spacing.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/source_repository_impl.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/repositories/source_repository.dart';
import '../../source/presentation/source_filter_sheet.dart';
import '../application/search_history_service.dart';
import '../application/search_service.dart';
import 'widgets/search_book_card.dart';
import 'widgets/search_empty_state.dart';
import 'widgets/search_failure_banner.dart';
import 'widgets/search_input_card.dart';
import 'widgets/search_progress_card.dart';
import 'widgets/search_report_summary.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _keywordController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SourceRepository _sourceRepository = SourceRepositoryImpl(
    AppDatabase.instance,
  );
  late final SearchService _searchService;
  final SearchHistoryService _historyService = SearchHistoryService();

  static final RegExp _preciseSpaceRegex = RegExp(r'[\u3000\s]+');
  static final RegExp _htmlTagRegex = RegExp(r'<[^>]+>');
  static const Set<String> _preciseTitleSeparators = <String>{
    ' ',
    '-',
    '_',
    '.',
    '·',
    ':',
    '：',
    '/',
    '|',
    '(',
    '（',
    '[',
    '【',
    '<',
    '《',
  };
  static const Set<String> _preciseLeadingWrappers = <String>{
    '《',
    '〈',
    '<',
    '「',
    '『',
    '【',
    '[',
    '(',
    '（',
  };
  static const Set<String> _preciseTrailingWrappers = <String>{
    '》',
    '〉',
    '>',
    '」',
    '』',
    '】',
    ']',
    ')',
    '）',
  };
  static const Duration _progressUiThrottleWindow = Duration(milliseconds: 120);
  static const Duration _sourceCountLoadTimeout = Duration(seconds: 8);
  static const Set<PointerDeviceKind> _dragDevices = <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };
  static const int _searchResultPageSize = 40;
  static const double _paginationTriggerDistance = 280;

  bool _isSearching = false;
  bool _isLoadingSourceCount = false;
  SearchExecutionReport? _report;
  List<Book> _visibleBooks = const <Book>[];
  SearchCancellationToken? _activeSearchToken;
  int _searchSessionId = 0;
  SearchContentMode _searchContentMode = SearchContentMode.novel;
  bool _isPreciseBookMatch = false;
  int _availableSourceCount = 0;
  Set<String> _selectedSourceIds = <String>{};
  final ScrollController _pageScrollController = ScrollController();
  int _renderedResultCount = 0;
  bool _isAppendingResults = false;
  SearchExecutionReport? _pendingProgressReport;
  Timer? _progressUiTimer;
  DateTime? _lastProgressUiUpdateAt;

  // Pre-processed snippet caches
  Map<String, String?> _normalizedIntros = const <String, String?>{};
  Map<String, String?> _normalizedLatestChapters = const <String, String?>{};

  // Search history
  List<String> _searchHistory = const <String>[];

  @override
  void initState() {
    super.initState();
    _searchService = SearchService(sourceRepository: _sourceRepository);
    _pageScrollController.addListener(_onPageScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshSourceCount());
      unawaited(_loadSearchHistory());
    });
  }

  @override
  void dispose() {
    _activeSearchToken?.cancel();
    _clearProgressUiThrottle();
    _pageScrollController.removeListener(_onPageScroll);
    _pageScrollController.dispose();
    _searchFocusNode.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final canPopRoute = context.canPop();
    final report = _report;

    return PopScope<void>(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted) return;
        context.go('/bookshelf');
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _handleBackNavigation,
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('搜索'),
        ),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colorScheme.surface, colorScheme.surfaceContainerLow],
            ),
          ),
          child: ScrollConfiguration(
            behavior: const MaterialScrollBehavior().copyWith(
              dragDevices: _dragDevices,
            ),
            child: ListView(
              controller: _pageScrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontal,
                12,
                horizontal,
                16 + bottomSafe,
              ),
              children: [
                SearchInputCard(
                  keywordController: _keywordController,
                  focusNode: _searchFocusNode,
                  isSearching: _isSearching,
                  searchContentMode: _searchContentMode,
                  isPreciseBookMatch: _isPreciseBookMatch,
                  selectedSourceCount: _selectedSourceIds.length,
                  availableSourceCount: _availableSourceCount,
                  isLoadingSourceCount: _isLoadingSourceCount,
                  onSearch: _runSearch,
                  onClearResults: _clearResults,
                  onContentModeChanged: _onContentModeChanged,
                  onPreciseMatchChanged: _onPreciseMatchChanged,
                  onOpenSourceFilter: () => unawaited(_showSourceFilterSheet()),
                  onClearSourceFilter: _clearSourceFilter,
                ),
                if (_isSearching)
                  SearchProgressCard(report: report, isSearching: _isSearching),
                if (report != null) ...[
                  const SizedBox(height: 8),
                  SearchReportSummary(
                    report: report,
                    visibleBookCount: _visibleBooks.length,
                    isPreciseBookMatch: _isPreciseBookMatch,
                  ),
                  if (report.failures.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SearchFailureBanner(report: report),
                  ],
                  const SizedBox(height: 10),
                  _buildResultList(report, _visibleBooks),
                ] else if (!_isSearching)
                  SearchEmptyState(
                    history: _searchHistory,
                    onHistoryTap: _onHistoryTap,
                    onClearHistory: _onClearHistory,
                    onRemoveHistoryItem: _onRemoveHistoryItem,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Navigation ──

  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/bookshelf');
  }

  // ── Callbacks for SearchInputCard ──

  void _onContentModeChanged(SearchContentMode mode) {
    setState(() {
      _searchContentMode = mode;
      _selectedSourceIds = <String>{};
      _setReport(null);
    });
    unawaited(_refreshSourceCount());
  }

  void _onPreciseMatchChanged(bool value) {
    setState(() {
      _isPreciseBookMatch = value;
      _setReport(_report);
    });
  }

  void _clearResults() {
    _keywordController.clear();
    setState(() {
      _setReport(null);
    });
  }

  void _clearSourceFilter() {
    setState(() {
      _selectedSourceIds = <String>{};
      _setReport(null);
    });
  }

  // ── Search History ──

  Future<void> _loadSearchHistory() async {
    final history = await _historyService.getAll();
    if (!mounted) return;
    setState(() {
      _searchHistory = history;
    });
  }

  void _onHistoryTap(String keyword) {
    _keywordController.text = keyword;
    _keywordController.selection = TextSelection.fromPosition(
      TextPosition(offset: keyword.length),
    );
    _runSearch();
  }

  void _onClearHistory() {
    unawaited(_historyService.clear());
    setState(() {
      _searchHistory = const <String>[];
    });
  }

  void _onRemoveHistoryItem(String keyword) {
    unawaited(
      _historyService.remove(keyword).then((_) => _loadSearchHistory()),
    );
    // Optimistic UI: remove immediately
    setState(() {
      _searchHistory = _searchHistory
          .where((item) => item != keyword)
          .toList(growable: false);
    });
  }

  // ── Source filter ──

  Future<void> _refreshSourceCount() async {
    if (!mounted) return;

    final isMangaMode = _searchContentMode == SearchContentMode.manga;

    setState(() {
      _isLoadingSourceCount = true;
    });

    try {
      final count = await AppDatabase.instance
          .countSourceListItems(enabledOnly: true, isMangaSource: isMangaMode)
          .timeout(_sourceCountLoadTimeout);

      if (!mounted ||
          isMangaMode != (_searchContentMode == SearchContentMode.manga)) {
        return;
      }

      setState(() {
        _availableSourceCount = count;
      });
    } catch (error) {
      if (!mounted ||
          isMangaMode != (_searchContentMode == SearchContentMode.manga)) {
        return;
      }

      debugPrint('Failed to load source count: $error');
      setState(() {
        _availableSourceCount = 0;
      });
    } finally {
      if (mounted &&
          isMangaMode == (_searchContentMode == SearchContentMode.manga)) {
        setState(() {
          _isLoadingSourceCount = false;
        });
      }
    }
  }

  Future<void> _showSourceFilterSheet() async {
    final selected = await showSourceFilterSheet(
      context: context,
      config: SourceFilterSheetConfig(
        initialSelectedIds: _selectedSourceIds,
        enabledOnly: true,
        isMangaSource: _searchContentMode == SearchContentMode.manga,
        allSelectionLabel: '全部书源',
        allSummaryLabel: '全部',
      ),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _selectedSourceIds = selected;
      _setReport(null);
    });
  }

  // ── Scroll pagination ──

  void _onPageScroll() {
    if (!_pageScrollController.hasClients || _isSearching) return;

    final position = _pageScrollController.position;
    if (position.pixels + _paginationTriggerDistance <
        position.maxScrollExtent) {
      return;
    }

    _appendMoreRenderedResults();
  }

  void _appendMoreRenderedResults() {
    if (_isAppendingResults) return;

    final total = _visibleBooks.length;
    if (total == 0 || _renderedResultCount >= total) return;

    _isAppendingResults = true;
    setState(() {
      _renderedResultCount = (_renderedResultCount + _searchResultPageSize)
          .clamp(0, total);
    });
    _isAppendingResults = false;
    _scheduleAutoAppendIfNeeded();
  }

  void _scheduleAutoAppendIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isSearching || _isAppendingResults) return;
      if (!_pageScrollController.hasClients) return;
      if (_renderedResultCount >= _visibleBooks.length) return;

      final position = _pageScrollController.position;
      final isNearBottom =
          position.pixels + _paginationTriggerDistance >=
          position.maxScrollExtent;
      final isScrollable = position.maxScrollExtent > 0;

      if (!isScrollable || isNearBottom) {
        _appendMoreRenderedResults();
      }
    });
  }

  // ── Report & snippet pre-processing ──

  void _setReport(SearchExecutionReport? report) {
    _report = report;
    _visibleBooks =
        report == null
            ? const <Book>[]
            : _applyPreciseFilter(report.books, report.keyword);

    // Pre-process snippets to avoid regex work during build
    if (report != null && _visibleBooks.isNotEmpty) {
      final intros = <String, String?>{};
      final chapters = <String, String?>{};
      for (final book in _visibleBooks) {
        final key = '${book.sourceId}_${book.id}_${book.detailUrl.hashCode}';
        intros[key] = _normalizeSnippet(book.intro);
        chapters[key] = _normalizeSnippet(book.latestChapter);
      }
      _normalizedIntros = intros;
      _normalizedLatestChapters = chapters;
    } else {
      _normalizedIntros = const <String, String?>{};
      _normalizedLatestChapters = const <String, String?>{};
    }

    if (_visibleBooks.isEmpty) {
      _renderedResultCount = 0;
      return;
    }

    final target =
        _visibleBooks.length > _searchResultPageSize
            ? _searchResultPageSize
            : _visibleBooks.length;
    _renderedResultCount = target;
    _scheduleAutoAppendIfNeeded();
  }

  // ── Result list ──

  Widget _buildResultList(SearchExecutionReport report, List<Book> books) {
    if (books.isEmpty) {
      final theme = Theme.of(context);
      final emptyTip =
          _isPreciseBookMatch && report.books.isNotEmpty
              ? '已开启精准匹配，当前关键词未命中精准书名。'
              : '暂无可展示结果，请检查书源规则或更换关键词。';

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(emptyTip, style: theme.textTheme.bodyMedium),
        ),
      );
    }

    final visibleCount = _renderedResultCount.clamp(0, books.length);

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleCount,
          itemBuilder: (context, index) {
            final book = books[index];
            final sourceName =
                report.sourceNames[book.sourceId] ?? book.sourceId;
            final heroTag = _buildBookCoverHeroTag(
              book: book,
              listIndex: index,
            );
            final snippetKey =
                '${book.sourceId}_${book.id}_${book.detailUrl.hashCode}';

            return SearchBookCard(
              book: book,
              sourceName: sourceName,
              heroTag: heroTag,
              normalizedIntro: _normalizedIntros[snippetKey],
              normalizedLatestChapter: _normalizedLatestChapters[snippetKey],
              onTap: () {
                final route =
                    Uri(
                      path: '/book/${book.id}',
                      queryParameters: {
                        'sourceId': book.sourceId,
                        'detailUrl': book.detailUrl,
                        'title': book.title,
                        'heroTag': heroTag,
                      },
                    ).toString();
                context.push(route);
              },
            );
          },
        ),
      ],
    );
  }

  String _buildBookCoverHeroTag({required Book book, required int listIndex}) {
    return 'book_cover_${book.sourceId}_${book.id}_${book.detailUrl.hashCode}_$listIndex';
  }

  // ── Snippet normalization (used at _setReport time, not during build) ──

  String? _normalizeSnippet(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;

    var normalized = text
        .replaceAll(r'\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    normalized = normalized
        .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'\{\{[^{}]*\}\}'), '')
        .replaceAll(RegExp(r'\{\{[^\n\r]*'), '');

    if (RegExp(r'<[^>]+>').hasMatch(normalized)) {
      normalized = html_parser.parseFragment(normalized).text ?? '';
    }

    normalized =
        normalized
            .replaceAll(RegExp(r'[ \t\u00A0]+'), ' ')
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')
            .trim();

    return normalized.isEmpty ? null : normalized;
  }

  // ── Precise matching ──

  List<Book> _applyPreciseFilter(List<Book> books, String keyword) {
    if (!_isPreciseBookMatch) return books;

    final normalizedKeyword = _normalizePreciseText(keyword);
    if (normalizedKeyword.isEmpty) return books;

    return books
        .where((book) => _isPreciseTitleMatch(book.title, normalizedKeyword))
        .toList(growable: false);
  }

  bool _isPreciseTitleMatch(String title, String normalizedKeyword) {
    final normalizedTitle = _normalizePreciseText(title);
    if (normalizedTitle.isEmpty) return false;

    if (normalizedTitle == normalizedKeyword) return true;

    if (!normalizedTitle.startsWith(normalizedKeyword) ||
        normalizedTitle.length <= normalizedKeyword.length) {
      return false;
    }

    final nextChar = normalizedTitle[normalizedKeyword.length];
    return _preciseTitleSeparators.contains(nextChar);
  }

  String _normalizePreciseText(String raw) {
    var normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return '';

    if (normalized.contains('<') && normalized.contains('>')) {
      normalized = normalized.replaceAll(_htmlTagRegex, ' ');
    }

    normalized = normalized.replaceAll(_preciseSpaceRegex, ' ').trim();
    return _trimPreciseWrappers(normalized);
  }

  String _trimPreciseWrappers(String value) {
    var normalized = value;
    while (normalized.isNotEmpty &&
        _preciseLeadingWrappers.contains(normalized[0])) {
      normalized = normalized.substring(1).trimLeft();
    }

    while (normalized.isNotEmpty &&
        _preciseTrailingWrappers.contains(normalized[normalized.length - 1])) {
      normalized = normalized.substring(0, normalized.length - 1).trimRight();
    }

    return normalized;
  }

  // ── Progress throttling ──

  void _clearProgressUiThrottle() {
    _progressUiTimer?.cancel();
    _progressUiTimer = null;
    _pendingProgressReport = null;
    _lastProgressUiUpdateAt = null;
  }

  void _updateProgressReportThrottled({
    required SearchExecutionReport report,
    required SearchCancellationToken token,
    required int sessionId,
  }) {
    final now = DateTime.now();
    final lastUpdateAt = _lastProgressUiUpdateAt;
    final shouldFlushNow =
        lastUpdateAt == null ||
        now.difference(lastUpdateAt) >= _progressUiThrottleWindow ||
        report.processedSourceCount >= report.sourceCount;

    if (shouldFlushNow) {
      _progressUiTimer?.cancel();
      _progressUiTimer = null;
      _pendingProgressReport = null;
      _lastProgressUiUpdateAt = now;
      setState(() {
        _setReport(report);
      });
      return;
    }

    _pendingProgressReport = report;
    if (_progressUiTimer?.isActive ?? false) return;

    final delay = _progressUiThrottleWindow - now.difference(lastUpdateAt);
    _progressUiTimer = Timer(delay, () {
      _progressUiTimer = null;
      final pending = _pendingProgressReport;
      _pendingProgressReport = null;
      if (pending == null ||
          !mounted ||
          token.isCancelled ||
          sessionId != _searchSessionId) {
        return;
      }

      _lastProgressUiUpdateAt = DateTime.now();
      setState(() {
        _setReport(pending);
      });
    });
  }

  // ── Search execution ──

  Future<void> _runSearch() async {
    if (_isSearching) {
      _cancelSearch();
      return;
    }

    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      _showMessage('请输入关键词。');
      return;
    }

    FocusScope.of(context).unfocus();

    final sessionId = ++_searchSessionId;
    final token = SearchCancellationToken();
    _activeSearchToken = token;

    _clearProgressUiThrottle();
    setState(() {
      _isSearching = true;
      _setReport(null);
    });

    try {
      final report = await _searchService.search(
        keyword: keyword,
        contentMode: _searchContentMode,
        sourceIds:
            _selectedSourceIds.isEmpty
                ? null
                : _selectedSourceIds.toList(growable: false),
        cancellationToken: token,
        onProgress: (progress) {
          if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
            return;
          }
          _updateProgressReportThrottled(
            report: progress,
            token: token,
            sessionId: sessionId,
          );
        },
      );

      if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
        return;
      }

      setState(() {
        _setReport(report);
      });

      // Save to search history
      unawaited(_historyService.add(keyword).then((_) => _loadSearchHistory()));

      if (report.books.isEmpty) {
        _showMessage('搜索完成，但没有命中结果。');
      }
    } on AppException catch (error) {
      if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
        return;
      }
      _showMessage(error.briefMessage);
    } catch (error) {
      if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
        return;
      }
      debugPrint('Search failed: $error');
      _showMessage('搜索失败，请稍后重试。');
    } finally {
      _clearProgressUiThrottle();
      if (mounted && sessionId == _searchSessionId) {
        setState(() {
          _isSearching = false;
          if (identical(_activeSearchToken, token)) {
            _activeSearchToken = null;
          }
        });
      }
    }
  }

  void _cancelSearch() {
    if (!_isSearching) return;

    _activeSearchToken?.cancel();
    _clearProgressUiThrottle();
    setState(() {
      _isSearching = false;
      _activeSearchToken = null;
    });
    _showMessage('已取消搜索。');
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
