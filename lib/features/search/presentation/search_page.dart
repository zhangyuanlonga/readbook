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
import '../application/search_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _keywordController = TextEditingController();
  final SourceRepository _sourceRepository = SourceRepositoryImpl(
    AppDatabase.instance,
  );
  late final SearchService _searchService;

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
  static const int _failurePreviewLimit = 2;

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

  @override
  void initState() {
    super.initState();
    _searchService = SearchService(sourceRepository: _sourceRepository);
    _pageScrollController.addListener(_onPageScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_refreshSourceCount());
    });
  }

  @override
  void dispose() {
    _activeSearchToken?.cancel();
    _clearProgressUiThrottle();
    _pageScrollController.removeListener(_onPageScroll);
    _pageScrollController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final canPopRoute = context.canPop();
    final report = _report;

    return PopScope<void>(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted) {
          return;
        }
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
              padding: EdgeInsets.fromLTRB(
                horizontal,
                12,
                horizontal,
                16 + bottomSafe,
              ),
              children: [
                _buildSearchInputCard(),
                const SizedBox(height: 12),
                if (_isSearching || report != null) _buildProgressCard(),
                if (report != null) ...[
                  const SizedBox(height: 12),
                  _buildReportSummary(report, _visibleBooks.length),
                  if (report.failures.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildFailureBanner(report),
                  ],
                  const SizedBox(height: 12),
                  _buildResultList(report, _visibleBooks),
                ] else if (!_isSearching)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '输入关键词后开始搜索。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/bookshelf');
  }

  Widget _buildSearchInputCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final isMangaMode = _searchContentMode == SearchContentMode.manga;
    final hintText = isMangaMode ? '输入漫画名或作者，例如：一人之下' : '输入书名或作者，例如：凡人修仙传';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<SearchContentMode>(
                segments: const [
                  ButtonSegment<SearchContentMode>(
                    value: SearchContentMode.novel,
                    icon: Icon(Icons.menu_book_rounded),
                    label: Text('小说'),
                  ),
                  ButtonSegment<SearchContentMode>(
                    value: SearchContentMode.manga,
                    icon: Icon(Icons.auto_stories_rounded),
                    label: Text('漫画'),
                  ),
                ],
                selected: <SearchContentMode>{_searchContentMode},
                showSelectedIcon: false,
                onSelectionChanged:
                    _isSearching
                        ? null
                        : (selection) {
                          final mode =
                              selection.isEmpty ? null : selection.first;
                          if (mode == null || mode == _searchContentMode) {
                            return;
                          }
                          setState(() {
                            _searchContentMode = mode;
                            _selectedSourceIds = <String>{};
                            _setReport(null);
                          });
                          unawaited(_refreshSourceCount());
                        },
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline),
              ),
              child: TextField(
                controller: _keywordController,
                textInputAction: TextInputAction.search,
                textAlignVertical: TextAlignVertical.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  height: 1.2,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _runSearch(),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    height: 1.2,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  border: InputBorder.none,
                  filled: false,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 38,
                    minHeight: 38,
                  ),
                  suffixIcon:
                      _keywordController.text.isEmpty
                          ? null
                          : IconButton(
                            tooltip: '清空输入',
                            onPressed: () {
                              _keywordController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 9,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildSourceFilterRow(),
            const SizedBox(height: 8),
            _buildPreciseMatchRow(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _runSearch,
                    child: Text(_isSearching ? '取消搜索' : '搜索'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isSearching
                            ? null
                            : () {
                              _keywordController.clear();
                              setState(() {
                                _setReport(null);
                              });
                            },
                    child: const Text('清空结果'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceFilterRow() {
    final selectedCount = _selectedSourceIds.length;

    final summaryText =
        _isLoadingSourceCount && _availableSourceCount == 0
            ? '书源: 统计中...'
            : _availableSourceCount == 0
            ? '当前类型没有可选书源'
            : selectedCount == 0
            ? '书源: 全部 ($_availableSourceCount)'
            : '书源: 指定 $selectedCount / $_availableSourceCount';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              summaryText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_isLoadingSourceCount)
            const SizedBox(
              width: 20,
              height: 20,
              child: Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            if (_selectedSourceIds.isNotEmpty)
              IconButton(
                tooltip: '清空筛选',
                visualDensity: VisualDensity.compact,
                onPressed:
                    _isSearching
                        ? null
                        : () {
                          setState(() {
                            _selectedSourceIds = <String>{};
                            _setReport(null);
                          });
                        },
                icon: const Icon(Icons.clear_rounded, size: 18),
              ),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed:
                  (_isSearching || _availableSourceCount == 0)
                      ? null
                      : () => unawaited(_showSourceFilterSheet()),
              icon: const Icon(Icons.filter_list_rounded, size: 18),
              label: const Text('指定书源'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _refreshSourceCount() async {
    if (!mounted) {
      return;
    }

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
    } catch (_) {
      if (!mounted ||
          isMangaMode != (_searchContentMode == SearchContentMode.manga)) {
        return;
      }

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
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder:
          (context) => _SourceFilterSheet(
            initialSelectedIds: _selectedSourceIds,
            contentMode: _searchContentMode,
          ),
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _selectedSourceIds = selected;
      _setReport(null);
    });
  }

  void _onPageScroll() {
    if (!_pageScrollController.hasClients || _isSearching) {
      return;
    }

    final position = _pageScrollController.position;
    if (position.pixels + 280 < position.maxScrollExtent) {
      return;
    }

    _appendMoreRenderedResults();
  }

  void _appendMoreRenderedResults() {
    if (_isAppendingResults) {
      return;
    }

    final total = _visibleBooks.length;
    if (total == 0 || _renderedResultCount >= total) {
      return;
    }

    _isAppendingResults = true;
    setState(() {
      _renderedResultCount = (_renderedResultCount + _searchResultPageSize)
          .clamp(0, total);
    });
    _isAppendingResults = false;
  }

  void _setReport(SearchExecutionReport? report) {
    _report = report;
    _visibleBooks =
        report == null
            ? const <Book>[]
            : _applyPreciseFilter(report.books, report.keyword);

    if (_visibleBooks.isEmpty) {
      _renderedResultCount = 0;
      return;
    }

    final target =
        _visibleBooks.length > _searchResultPageSize
            ? _searchResultPageSize
            : _visibleBooks.length;
    _renderedResultCount = target;
  }

  Widget _buildProgressCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final report = _report;
    final sourceCount = report?.sourceCount ?? 1;
    final processedCount = report?.processedSourceCount ?? 0;
    final progressValue =
        sourceCount == 0 ? 0.0 : (processedCount / sourceCount).clamp(0.0, 1.0);
    final progressPercent = (progressValue * 100).round();

    final progressText =
        report == null ? '正在搜索书源...' : '正在搜索 $processedCount/$sourceCount 个书源';

    return Card(
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(progressText)),
                Text(
                  '$progressPercent%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progressValue,
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreciseMatchRow() {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap:
          _isSearching
              ? null
              : () {
                setState(() {
                  _isPreciseBookMatch = !_isPreciseBookMatch;
                  _setReport(_report);
                });
              },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: _isPreciseBookMatch,
              onChanged:
                  _isSearching
                      ? null
                      : (value) {
                        setState(() {
                          _isPreciseBookMatch = value ?? false;
                          _setReport(_report);
                        });
                      },
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 2),
            Text(
              '精准书名',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportSummary(
    SearchExecutionReport report,
    int visibleBookCount,
  ) {
    final resultText =
        _isPreciseBookMatch && visibleBookCount != report.books.length
            ? '$visibleBookCount/${report.books.length} 本'
            : '$visibleBookCount 本';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildSummaryChip('关键词', report.keyword),
        _buildSummaryChip(
          '类型',
          _searchContentMode == SearchContentMode.manga ? '漫画' : '小说',
        ),
        _buildSummaryChip('结果', resultText),
        _buildSummaryChip(
          '成功源',
          '${report.successSourceCount}/${report.sourceCount}',
        ),
        _buildSummaryChip('筛选', _selectedSourceIds.isEmpty ? '全部书源' : '指定书源'),
        _buildSummaryChip('匹配', _isPreciseBookMatch ? '精准' : '默认'),
        if (report.failedSourceCount > 0)
          _buildSummaryChip('失败源', '${report.failedSourceCount}'),
      ],
    );
  }

  Widget _buildSummaryChip(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFailureBanner(SearchExecutionReport report) {
    final colorScheme = Theme.of(context).colorScheme;
    final preview = report.failures
        .take(_failurePreviewLimit)
        .toList(growable: false);
    final canOpenDetail = report.failures.length > _failurePreviewLimit;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${report.failedSourceCount} 个书源异常',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (canOpenDetail)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onErrorContainer,
                  ),
                  onPressed: () => _showFailureDetails(report),
                  child: const Text('查看明细'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ...preview.map(
            (failure) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${failure.sourceName} (${failure.code.name}): ${failure.message}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFailureDetails(SearchExecutionReport report) async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '书源异常明细 (${report.failures.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: report.failures.length,
                    separatorBuilder:
                        (_, __) => Divider(
                          height: 1,
                          color: colorScheme.outlineVariant,
                        ),
                    itemBuilder: (context, index) {
                      final failure = report.failures[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          failure.sourceName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        subtitle: Text(
                          '[${failure.code.name}] ${failure.message}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultList(SearchExecutionReport report, List<Book> books) {
    if (books.isEmpty) {
      final emptyTip =
          _isPreciseBookMatch && report.books.isNotEmpty
              ? '已开启精准匹配，当前关键词未命中精准书名。'
              : '暂无可展示结果，请检查书源规则或更换关键词。';

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(emptyTip, style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }

    final visibleCount = _renderedResultCount.clamp(0, books.length);
    final visibleBooks = books.take(visibleCount).toList(growable: false);
    final hasMoreResults = visibleCount < books.length;

    return Column(
      children: [
        ...visibleBooks.map((book) => _buildBookCard(book, report.sourceNames)),
        if (hasMoreResults)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              children: [
                Text(
                  '继续滚动或点击加载更多（$visibleCount/${books.length}）',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _appendMoreRenderedResults,
                  icon: const Icon(Icons.expand_more_rounded),
                  label: const Text('加载下一批'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBookCard(Book book, Map<String, String> sourceNames) {
    final sourceName = sourceNames[book.sourceId] ?? book.sourceId;
    final latestChapter = _normalizeSnippet(book.latestChapter);
    final intro = _normalizeSnippet(book.intro);
    final author = book.author?.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final route =
              Uri(
                path: '/book/${book.id}',
                queryParameters: {
                  'sourceId': book.sourceId,
                  'detailUrl': book.detailUrl,
                  'title': book.title,
                },
              ).toString();
          context.push(route);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildCoverPreview(book.coverUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildInfoPill('来源', sourceName),
                        if (author != null && author.isNotEmpty)
                          _buildInfoPill('作者', author),
                      ],
                    ),
                    if (latestChapter != null && latestChapter.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '最新章节: $latestChapter',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    if (intro != null && intro.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            intro,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Center(
                child: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPill(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }

  Widget _buildCoverPreview(String? coverUrl) {
    final uri = Uri.tryParse(coverUrl ?? '');
    if (uri == null || !uri.hasScheme) {
      return _buildCoverFallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        coverUrl!,
        width: 56,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildCoverFallback(),
      ),
    );
  }

  Widget _buildCoverFallback() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 56,
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('封面', style: Theme.of(context).textTheme.labelSmall),
    );
  }

  String? _normalizeSnippet(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

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

  List<Book> _applyPreciseFilter(List<Book> books, String keyword) {
    if (!_isPreciseBookMatch) {
      return books;
    }

    final normalizedKeyword = _normalizePreciseText(keyword);
    if (normalizedKeyword.isEmpty) {
      return books;
    }

    return books
        .where((book) => _isPreciseTitleMatch(book.title, normalizedKeyword))
        .toList(growable: false);
  }

  bool _isPreciseTitleMatch(String title, String normalizedKeyword) {
    final normalizedTitle = _normalizePreciseText(title);
    if (normalizedTitle.isEmpty) {
      return false;
    }

    if (normalizedTitle == normalizedKeyword) {
      return true;
    }

    if (!normalizedTitle.startsWith(normalizedKeyword) ||
        normalizedTitle.length <= normalizedKeyword.length) {
      return false;
    }

    final nextChar = normalizedTitle[normalizedKeyword.length];
    return _preciseTitleSeparators.contains(nextChar);
  }

  String _normalizePreciseText(String raw) {
    var normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }

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
    if (_progressUiTimer?.isActive ?? false) {
      return;
    }

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

      if (report.books.isEmpty) {
        _showMessage('搜索完成，但没有命中结果。');
      }
    } on AppException catch (error) {
      if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
        return;
      }
      _showMessage(error.briefMessage);
    } catch (_) {
      if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
        return;
      }
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
    if (!_isSearching) {
      return;
    }

    _activeSearchToken?.cancel();
    _clearProgressUiThrottle();
    setState(() {
      _isSearching = false;
      _activeSearchToken = null;
    });
    _showMessage('已取消搜索。');
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _SourceFilterSheet extends StatefulWidget {
  const _SourceFilterSheet({
    required this.initialSelectedIds,
    required this.contentMode,
  });

  final Set<String> initialSelectedIds;
  final SearchContentMode contentMode;

  @override
  State<_SourceFilterSheet> createState() => _SourceFilterSheetState();
}

class _SourceFilterSheetState extends State<_SourceFilterSheet> {
  static const int _kPageSize = 80;
  static const Duration _kPageLoadTimeout = Duration(seconds: 8);

  final TextEditingController _keywordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _searchDebounce;
  late Set<String> _draftSelectedIds;
  List<SourceListItem> _visibleSources = const <SourceListItem>[];
  bool _isInitialLoading = true;
  bool _isPageLoading = false;
  bool _hasMorePages = true;
  int _nextOffset = 0;
  int _totalCount = 0;
  int _queryTicket = 0;
  String? _errorText;

  bool get _isMangaMode => widget.contentMode == SearchContentMode.manga;

  @override
  void initState() {
    super.initState();
    _draftSelectedIds = <String>{...widget.initialSelectedIds};
    _keywordController.addListener(_onKeywordChanged);
    _scrollController.addListener(_onScroll);
    unawaited(_reloadSourcePage(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _keywordController.removeListener(_onKeywordChanged);
    _keywordController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onKeywordChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_reloadSourcePage(reset: true));
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isInitialLoading || _isPageLoading) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels + 320 >= position.maxScrollExtent) {
      unawaited(_reloadSourcePage(reset: false));
    }
  }

  Future<void> _reloadSourcePage({required bool reset}) async {
    if (!reset && (!_hasMorePages || _isPageLoading)) {
      return;
    }

    final keyword = _keywordController.text.trim();
    final ticket = reset ? ++_queryTicket : _queryTicket;

    setState(() {
      _isPageLoading = true;
      if (reset) {
        _isInitialLoading = true;
        _hasMorePages = true;
        _nextOffset = 0;
        _totalCount = 0;
        _visibleSources = const <SourceListItem>[];
        _errorText = null;
      }
    });

    try {
      final pageFuture = AppDatabase.instance.querySourceListItems(
        offset: reset ? 0 : _nextOffset,
        limit: _kPageSize,
        keyword: keyword,
        enabledOnly: true,
        isMangaSource: _isMangaMode,
      );

      final totalFuture =
          reset
              ? AppDatabase.instance.countSourceListItems(
                keyword: keyword,
                enabledOnly: true,
                isMangaSource: _isMangaMode,
              )
              : Future<int>.value(_totalCount);

      final page = await pageFuture.timeout(_kPageLoadTimeout);
      final total = await totalFuture.timeout(_kPageLoadTimeout);

      if (!mounted || ticket != _queryTicket) {
        return;
      }

      setState(() {
        _totalCount = total;
        _visibleSources = reset ? page : [..._visibleSources, ...page];
        _nextOffset = reset ? page.length : (_nextOffset + page.length);
        _hasMorePages = _nextOffset < _totalCount;
        _isInitialLoading = false;
        _isPageLoading = false;
        _errorText = null;
      });
    } on TimeoutException {
      if (!mounted || ticket != _queryTicket) {
        return;
      }

      setState(() {
        _isInitialLoading = false;
        _isPageLoading = false;
        _errorText = '加载书源超时，请稍后重试。';
      });
    } catch (error) {
      if (!mounted || ticket != _queryTicket) {
        return;
      }

      setState(() {
        _isInitialLoading = false;
        _isPageLoading = false;
        _errorText = '加载书源失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '指定书源',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _keywordController,
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索书源名称或域名',
                prefixIcon: const Icon(Icons.search, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _draftSelectedIds = <String>{};
                    });
                  },
                  child: const Text('全部书源'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _draftSelectedIds.addAll(
                        _visibleSources.map((item) => item.id),
                      );
                    });
                  },
                  child: const Text('全选已加载'),
                ),
                const Spacer(),
                Text(
                  _draftSelectedIds.isEmpty
                      ? '当前：全部 ($_totalCount)'
                      : '当前：${_draftSelectedIds.length} 个',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(child: _buildBody()),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed:
                      () =>
                          Navigator.of(context).pop(_draftSelectedIds.toSet()),
                  child: const Text('应用筛选'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorText != null && _visibleSources.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorText!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => unawaited(_reloadSourcePage(reset: true)),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_visibleSources.isEmpty) {
      return Center(
        child: Text('未匹配到书源', style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    final itemCount = _visibleSources.length + (_isPageLoading ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= _visibleSources.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final source = _visibleSources[index];
        final selected = _draftSelectedIds.contains(source.id);
        return CheckboxListTile(
          value: selected,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            source.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            source.baseUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onChanged: (value) {
            setState(() {
              if (value ?? false) {
                _draftSelectedIds.add(source.id);
              } else {
                _draftSelectedIds.remove(source.id);
              }
            });
          },
        );
      },
    );
  }
}
