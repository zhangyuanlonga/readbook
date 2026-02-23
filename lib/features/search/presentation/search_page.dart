import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../app/layout/app_spacing.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/source_repository_impl.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/source_definition.dart';
import '../../../domain/repositories/source_repository.dart';
import '../application/search_failure_export_service.dart';
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
  late final SearchFailureExportService _failureExportService;

  bool _isSearching = false;
  bool _isExportingFailures = false;
  bool _isLoadingSourceFilters = false;
  SearchExecutionReport? _report;
  SearchCancellationToken? _activeSearchToken;
  int _searchSessionId = 0;
  SearchContentMode _searchContentMode = SearchContentMode.novel;
  List<SourceDefinition> _filterableSources = const [];
  Set<String> _selectedSourceIds = <String>{};

  @override
  void initState() {
    super.initState();
    _searchService = SearchService(sourceRepository: _sourceRepository);
    _failureExportService = SearchFailureExportService();
    unawaited(_refreshSourceFilters());
  }

  @override
  void dispose() {
    _activeSearchToken?.cancel();
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final canPopRoute = context.canPop();

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
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              12,
              horizontal,
              16 + bottomSafe,
            ),
            children: [
              _buildSearchInputCard(),
              const SizedBox(height: 12),
              if (_isSearching || _report != null) _buildProgressCard(),
              if (_report != null) ...[
                const SizedBox(height: 12),
                _buildReportSummary(_report!),
                if (_report!.failures.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildFailureBanner(_report!),
                ],
                const SizedBox(height: 12),
                _buildResultList(_report!),
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
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<SearchContentMode>(
                segments: const [
                  ButtonSegment<SearchContentMode>(
                    value: SearchContentMode.novel,
                    icon: Icon(Icons.menu_book_rounded),
                    label: Text('搜索小说'),
                  ),
                  ButtonSegment<SearchContentMode>(
                    value: SearchContentMode.manga,
                    icon: Icon(Icons.auto_stories_rounded),
                    label: Text('搜索漫画'),
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
                            _report = null;
                          });
                          unawaited(_refreshSourceFilters());
                        },
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colorScheme.outline),
              ),
              child: TextField(
                controller: _keywordController,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _runSearch(),
                decoration: InputDecoration(
                  hintText: hintText,
                  border: InputBorder.none,
                  filled: false,
                  prefixIcon: const Icon(Icons.search),
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildSourceFilterRow(),
            const SizedBox(height: 10),
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
                                _report = null;
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
    final allCount = _filterableSources.length;
    final selectedCount = _selectedSourceIds.length;

    final summaryText =
        allCount == 0
            ? '当前类型没有可选书源'
            : selectedCount == 0
            ? '书源: 全部 ($allCount)'
            : '书源: 指定 $selectedCount / $allCount';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
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
          if (_isLoadingSourceFilters)
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
                            _report = null;
                          });
                        },
                icon: const Icon(Icons.clear_rounded, size: 18),
              ),
            TextButton.icon(
              onPressed:
                  (_isSearching || allCount == 0)
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

  Future<void> _refreshSourceFilters() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingSourceFilters = true;
    });

    try {
      final all = await _sourceRepository.getAll();
      final filtered = all
        .where(
          (source) =>
              source.enabled &&
              ((_searchContentMode == SearchContentMode.manga &&
                      source.isMangaSource) ||
                  (_searchContentMode == SearchContentMode.novel &&
                      !source.isMangaSource)),
        )
        .toList(growable: false)..sort((a, b) => a.name.compareTo(b.name));

      if (!mounted) {
        return;
      }

      setState(() {
        _filterableSources = List.unmodifiable(filtered);
        _selectedSourceIds =
            _selectedSourceIds
                .where((id) => filtered.any((item) => item.id == id))
                .toSet();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSourceFilters = false;
        });
      }
    }
  }

  Future<void> _showSourceFilterSheet() async {
    if (_filterableSources.isEmpty) {
      _showMessage('当前类型没有可用书源。');
      return;
    }

    final initialSelected = <String>{..._selectedSourceIds};
    final keywordController = TextEditingController();

    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        var draftSelected = <String>{...initialSelected};

        return StatefulBuilder(
          builder: (context, setModalState) {
            final keyword = keywordController.text.trim().toLowerCase();
            final visibleSources = _filterableSources
                .where((source) {
                  if (keyword.isEmpty) {
                    return true;
                  }
                  return source.name.toLowerCase().contains(keyword) ||
                      source.baseUrl.toLowerCase().contains(keyword);
                })
                .toList(growable: false);

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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: keywordController,
                      onChanged: (_) => setModalState(() {}),
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
                            setModalState(() {
                              draftSelected = <String>{};
                            });
                          },
                          child: const Text('全部书源'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              draftSelected =
                                  _filterableSources
                                      .map((item) => item.id)
                                      .toSet();
                            });
                          },
                          child: const Text('全选'),
                        ),
                        const Spacer(),
                        Text(
                          draftSelected.isEmpty
                              ? '当前：全部'
                              : '当前：${draftSelected.length} 个',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child:
                          visibleSources.isEmpty
                              ? Center(
                                child: Text(
                                  '未匹配到书源',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              )
                              : ListView.builder(
                                itemCount: visibleSources.length,
                                itemBuilder: (context, index) {
                                  final source = visibleSources[index];
                                  final selected = draftSelected.contains(
                                    source.id,
                                  );
                                  return CheckboxListTile(
                                    value: selected,
                                    dense: true,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
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
                                      setModalState(() {
                                        if (value ?? false) {
                                          draftSelected.add(source.id);
                                        } else {
                                          draftSelected.remove(source.id);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                    ),
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
                              () => Navigator.of(context).pop(draftSelected),
                          child: const Text('应用筛选'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    keywordController.dispose();

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _selectedSourceIds = selected;
      _report = null;
    });
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
        padding: const EdgeInsets.all(14),
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
            const SizedBox(height: 8),
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

  Widget _buildReportSummary(SearchExecutionReport report) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildSummaryChip('关键词', report.keyword),
        _buildSummaryChip(
          '类型',
          _searchContentMode == SearchContentMode.manga ? '漫画' : '小说',
        ),
        _buildSummaryChip('结果', '${report.books.length} 本'),
        _buildSummaryChip(
          '成功源',
          '${report.successSourceCount}/${report.sourceCount}',
        ),
        _buildSummaryChip('筛选', _selectedSourceIds.isEmpty ? '全部书源' : '指定书源'),
        if (report.failedSourceCount > 0)
          _buildSummaryChip('失败源', '${report.failedSourceCount}'),
      ],
    );
  }

  Widget _buildSummaryChip(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFailureBanner(SearchExecutionReport report) {
    final colorScheme = Theme.of(context).colorScheme;
    final preview = report.failures.take(3).toList(growable: false);
    final canOpenDetail = report.failures.length > 3;
    final canExport = !_isSearching && !_isExportingFailures;

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
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onErrorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onPressed:
                canExport
                    ? () => unawaited(_exportFailedSources(report))
                    : null,
            icon:
                _isExportingFailures
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.download_rounded, size: 18),
            label: Text(_isExportingFailures ? '导出中...' : '导出失败书源'),
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

  Widget _buildResultList(SearchExecutionReport report) {
    final books = report.books;
    if (books.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '暂无可展示结果，请检查书源规则或更换关键词。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      children: books
          .map((book) => _buildBookCard(book, report.sourceNames))
          .toList(growable: false),
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

    setState(() {
      _isSearching = true;
      _report = null;
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
          setState(() {
            _report = progress;
          });
        },
      );

      if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
        return;
      }

      setState(() {
        _report = report;
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
    setState(() {
      _isSearching = false;
      _activeSearchToken = null;
    });
    _showMessage('已取消搜索。');
  }

  Future<void> _exportFailedSources(SearchExecutionReport report) async {
    if (_isExportingFailures || report.failures.isEmpty) {
      return;
    }

    setState(() {
      _isExportingFailures = true;
    });

    try {
      String? preferredFilePath;
      try {
        final saveLocation = await getSaveLocation(
          suggestedName: _failureExportService.buildSuggestedFileName(),
          acceptedTypeGroups: const [
            XTypeGroup(label: 'JSON', extensions: ['json']),
          ],
        );
        if (saveLocation == null) {
          _showMessage('已取消导出。');
          return;
        }
        preferredFilePath = saveLocation.path;
      } catch (_) {
        _showMessage('当前平台暂不支持选择保存位置，已使用默认目录导出。');
      }

      final allSources = await _sourceRepository.getAll();
      final result = await _failureExportService.exportFailedSources(
        report: report,
        sources: allSources,
        contentMode: _searchContentMode,
        preferredFilePath: preferredFilePath,
      );

      if (!mounted) {
        return;
      }

      final missingTips =
          result.missingSourceCount > 0
              ? '\n其中 ${result.missingSourceCount} 条未匹配到当前本地书源配置。'
              : '';
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('导出完成'),
              content: SelectableText(
                '已导出 ${result.failureCount} 条失败书源。\n'
                '文件路径：\n${result.filePath}$missingTips',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('知道了'),
                ),
              ],
            ),
      );
    } on AppException catch (error) {
      _showMessage(error.briefMessage);
    } catch (error) {
      _showMessage('导出失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isExportingFailures = false;
        });
      }
    }
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
