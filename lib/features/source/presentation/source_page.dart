import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/network/request_context.dart';
import '../../../core/result/result.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/source_repository_impl.dart';
import '../../../domain/entities/source_definition.dart';
import '../../../domain/repositories/source_repository.dart';
import '../../search/application/search_service.dart';
import '../application/source_capability_analyzer.dart';
import '../application/source_import_service.dart';

class SourcePage extends StatefulWidget {
  const SourcePage({super.key});

  @override
  State<SourcePage> createState() => _SourcePageState();
}

class _SourcePageState extends State<SourcePage> {
  final SourceImportService _importService = SourceImportService();
  final SourceRepository _repository = SourceRepositoryImpl(
    AppDatabase.instance,
  );

  SearchService? _searchService;

  bool _isImporting = false;
  bool _isSelectionMode = false;
  bool _isBatchDeleting = false;
  final Set<String> _testingSourceIds = <String>{};
  final Set<String> _changingEnabledSourceIds = <String>{};
  final Set<String> _deletingSourceIds = <String>{};
  final Set<String> _selectedSourceIds = <String>{};
  final Set<String> _expandedCommentSourceIds = <String>{};
  List<SourceListItem> _visibleSources = const <SourceListItem>[];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  String _searchKeyword = '';
  bool _showSearchBar = false;
  bool _isPageLoading = false;
  bool _isInitialLoading = true;
  bool _hasMorePages = true;
  String? _listErrorText;
  int _nextOffset = 0;
  int _totalCount = 0;
  int _enabledCount = 0;
  int _totalImportedCount = 0;
  int _novelCount = 0;
  int _mangaCount = 0;
  int _queryTicket = 0;

  static const int _kPageSize = 60;
  static const String _defaultConnectivityKeyword = '凡人修仙传';
  static const Duration _kSourceListLoadTimeout = Duration(seconds: 8);
  static const Duration _kSourceCardEntryDuration = Duration(milliseconds: 420);
  static const Duration _kCommentExpandDuration = Duration(milliseconds: 220);
  static const int _kSourceCardEntryStaggerGroup = 8;
  static const double _kSourceCardEntryStaggerStep = 0.08;
  static const double _kSourceCardEntryCurveSpan = 0.4;

  SearchService get _searchServiceClient =>
      _searchService ??= SearchService(sourceRepository: _repository);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchInputChanged);
    _scrollController.addListener(_onSourceListScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_reloadSourceList(reset: true));
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onSourceListScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchInputChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSourceListScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels + 360 >= position.maxScrollExtent) {
      unawaited(_loadNextPage());
    }
  }

  Future<void> _reloadSourceList({required bool reset}) async {
    final keyword = _searchKeyword.trim();
    final ticket = ++_queryTicket;
    final refreshLimit =
        reset
            ? _kPageSize
            : (_nextOffset > _kPageSize ? _nextOffset : _kPageSize);

    if (reset) {
      setState(() {
        _isInitialLoading = true;
        _isPageLoading = true;
        _listErrorText = null;
        _hasMorePages = true;
        _nextOffset = 0;
        _visibleSources = const <SourceListItem>[];
      });
    } else {
      setState(() {
        _isPageLoading = true;
      });
    }

    try {
      final pageFuture = AppDatabase.instance.querySourceListItems(
        offset: 0,
        limit: refreshLimit,
        keyword: keyword,
      );
      final summaryFuture = AppDatabase.instance.summarizeSourceListItems(
        keyword: keyword,
      );
      final overviewSummaryFuture =
          keyword.isEmpty
              ? Future<SourceListCountSummary?>.value(null)
              : AppDatabase.instance.summarizeSourceListItems();

      final results = await Future.wait<Object?>([
        pageFuture,
        summaryFuture,
        overviewSummaryFuture,
      ]).timeout(_kSourceListLoadTimeout);

      final page = results[0] as List<SourceListItem>;
      final summary = results[1] as SourceListCountSummary;
      final overviewSummary = results[2] as SourceListCountSummary?;
      final overview = overviewSummary ?? summary;

      if (!mounted || ticket != _queryTicket) {
        return;
      }

      setState(() {
        _visibleSources = page;
        _totalCount = summary.totalCount;
        _enabledCount = overview.enabledCount;
        _totalImportedCount = overview.totalCount;
        _novelCount = overview.novelCount;
        _mangaCount = overview.mangaCount;
        _nextOffset = page.length;
        _hasMorePages = page.length < summary.totalCount;
        _isInitialLoading = false;
        _isPageLoading = false;
        _listErrorText = null;
      });

      _syncSelectionWithVisibleSources();
      _syncExpandedCommentsWithVisibleSources();
    } on TimeoutException {
      if (!mounted || ticket != _queryTicket) {
        return;
      }
      setState(() {
        _isInitialLoading = false;
        _isPageLoading = false;
        _listErrorText = '加载书源超时，请稍后重试。';
      });
    } catch (error) {
      if (!mounted || ticket != _queryTicket) {
        return;
      }
      setState(() {
        _isInitialLoading = false;
        _isPageLoading = false;
        _listErrorText = '加载书源失败：$error';
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_isInitialLoading || _isPageLoading || !_hasMorePages) {
      return;
    }

    final keyword = _searchKeyword.trim();
    final ticket = _queryTicket;

    setState(() {
      _isPageLoading = true;
    });

    try {
      final page = await AppDatabase.instance
          .querySourceListItems(
            offset: _nextOffset,
            limit: _kPageSize,
            keyword: keyword,
          )
          .timeout(_kSourceListLoadTimeout);

      if (!mounted || ticket != _queryTicket) {
        return;
      }

      setState(() {
        _visibleSources = [..._visibleSources, ...page];
        _nextOffset += page.length;
        _hasMorePages = _nextOffset < _totalCount;
        _isPageLoading = false;
      });
    } catch (_) {
      if (!mounted || ticket != _queryTicket) {
        return;
      }
      setState(() {
        _isPageLoading = false;
      });
    }
  }

  void _syncSelectionWithVisibleSources() {
    if (!_isSelectionMode) {
      return;
    }

    final visibleIds = _visibleSources.map((item) => item.id).toSet();
    final nextSelected =
        _selectedSourceIds.where((id) => visibleIds.contains(id)).toSet();

    final needUpdate =
        nextSelected.length != _selectedSourceIds.length ||
        (_visibleSources.isEmpty && _isSelectionMode);

    if (!needUpdate || !mounted) {
      return;
    }

    setState(() {
      _selectedSourceIds
        ..clear()
        ..addAll(nextSelected);
      if (_visibleSources.isEmpty) {
        _isSelectionMode = false;
        _selectedSourceIds.clear();
      }
    });
  }

  void _syncExpandedCommentsWithVisibleSources() {
    if (_expandedCommentSourceIds.isEmpty) {
      return;
    }

    final visibleIds = _visibleSources.map((item) => item.id).toSet();
    final nextExpanded =
        _expandedCommentSourceIds
            .where((id) => visibleIds.contains(id))
            .toSet();

    if (nextExpanded.length == _expandedCommentSourceIds.length || !mounted) {
      return;
    }

    setState(() {
      _expandedCommentSourceIds
        ..clear()
        ..addAll(nextExpanded);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final isSearchActive = _showSearchBar || _searchKeyword.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading:
            _isSelectionMode
                ? IconButton(
                  onPressed: _exitSelectionMode,
                  tooltip: '取消选择',
                  icon: const Icon(Icons.close),
                )
                : null,
        title: Text(
          _isSelectionMode ? '已选择 ${_selectedSourceIds.length} 项' : '书源',
        ),
        actions: [
          if (!_isSelectionMode) ...[
            if (isSearchActive)
              IconButton.filledTonal(
                onPressed: _toggleSearchBar,
                tooltip: '收起搜索',
                icon: const Icon(Icons.search_off_rounded),
              )
            else
              IconButton(
                onPressed: _toggleSearchBar,
                tooltip: '搜索书源',
                icon: const Icon(Icons.search_rounded),
              ),
            IconButton(
              onPressed: _openBatchDiagnostics,
              tooltip: '批量诊断',
              icon: const Icon(Icons.fact_check_outlined),
            ),
            if (_isImporting)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              PopupMenuButton<_ImportAction>(
                tooltip: '导入书源',
                icon: const Icon(Icons.add),
                onSelected: (action) {
                  switch (action) {
                    case _ImportAction.paste:
                      _importFromPaste();
                    case _ImportAction.url:
                      _importFromUrl();
                    case _ImportAction.file:
                      _importFromFile();
                    case _ImportAction.batchSample:
                      _importFromBuiltInBatch();
                  }
                },
                itemBuilder:
                    (context) => const [
                      PopupMenuItem(
                        value: _ImportAction.paste,
                        child: Text('粘贴导入 JSON'),
                      ),
                      PopupMenuItem(
                        value: _ImportAction.url,
                        child: Text('链接导入'),
                      ),
                      PopupMenuItem(
                        value: _ImportAction.file,
                        child: Text('文件导入'),
                      ),
                      PopupMenuItem(
                        value: _ImportAction.batchSample,
                        child: Text('批量导入 read/test'),
                      ),
                    ],
              ),
          ],
        ],
      ),
      bottomNavigationBar: _isSelectionMode ? _buildSelectionActionBar() : null,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorScheme.surface, colorScheme.surfaceContainerLow],
          ),
        ),
        child: _buildSourceListContent(
          horizontal: horizontal,
          bottomSafe: bottomSafe,
        ),
      ),
    );
  }

  Widget _buildSourceListContent({
    required double horizontal,
    required double bottomSafe,
  }) {
    final hasKeyword = _searchKeyword.trim().isNotEmpty;
    final showSearchPanel = _showSearchBar || hasKeyword;
    final showEmpty = !_isInitialLoading && _visibleSources.isEmpty;
    final showErrorCard = _listErrorText != null && _visibleSources.isEmpty;
    final showLoadingCard = _isInitialLoading;

    const headerCount = 2;
    final listCount =
        showLoadingCard || showErrorCard || showEmpty
            ? 1
            : _visibleSources.length;
    final showFooter =
        !showLoadingCard &&
        !showErrorCard &&
        !showEmpty &&
        _visibleSources.isNotEmpty;
    final itemCount = headerCount + listCount + (showFooter ? 1 : 0);

    const searchPanelIndex = 1;
    const listStartIndex = 2;

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 16 + bottomSafe),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildOverviewCard(
            totalSourceCount: _totalImportedCount,
            enabledCount: _enabledCount,
            novelCount: _novelCount,
            mangaCount: _mangaCount,
          );
        }

        if (index == searchPanelIndex) {
          return _buildSearchPanelSlot(showSearchPanel: showSearchPanel);
        }

        final itemListIndex = index - listStartIndex;

        if (_isInitialLoading) {
          if (itemListIndex == 0) {
            return const Padding(
              padding: EdgeInsets.only(top: 10),
              child: _SourceLoadingCard(),
            );
          }
          return const SizedBox.shrink();
        }

        if (_listErrorText != null && _visibleSources.isEmpty) {
          if (itemListIndex == 0) {
            return Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 10),
              child: _buildListErrorCard(_listErrorText!),
            );
          }
          return const SizedBox.shrink();
        }

        if (showEmpty) {
          if (itemListIndex == 0) {
            return Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 10),
              child: _buildEmptySourceCard(hasKeyword: hasKeyword),
            );
          }
          return const SizedBox.shrink();
        }

        if (itemListIndex >= 0 && itemListIndex < _visibleSources.length) {
          final source = _visibleSources[itemListIndex];
          if (itemListIndex >= _visibleSources.length - 8) {
            unawaited(_loadNextPage());
          }
          return _buildAnimatedSourceCard(
            source: source,
            listIndex: itemListIndex,
          );
        }

        if (showFooter && itemListIndex == _visibleSources.length) {
          return _buildPagingFooter();
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSearchPanelSlot({required bool showSearchPanel}) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: child,
          ),
        );
      },
      child:
          showSearchPanel
              ? Padding(
                key: const ValueKey('search_panel_visible'),
                padding: const EdgeInsets.only(top: 10, bottom: 10),
                child: _buildSearchPanel(),
              )
              : const SizedBox.shrink(key: ValueKey('search_panel_hidden')),
    );
  }

  Widget _buildSelectionActionBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isBatchDeleting || _visibleSources.isEmpty
                          ? null
                          : _selectAllVisibleSources,
                  child: const Text('全选'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isBatchDeleting || _totalImportedCount == 0
                          ? null
                          : _clearAllSources,
                  child: const Text('清空全部'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed:
                      _isBatchDeleting || _selectedSourceIds.isEmpty
                          ? null
                          : _deleteSelectedSources,
                  child: const Text('删除'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPagingFooter() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isPageLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 12, bottom: 4),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final text = _hasMorePages ? '继续下滑加载更多书源' : '已显示全部书源';
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Center(
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildListErrorCard(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasKeyword = _searchKeyword.trim().isNotEmpty;

    return Card(
      shape: _buildOutlinedCardShape(context),
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '书源列表加载失败',
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => unawaited(_reloadSourceList(reset: true)),
                  child: const Text('重试'),
                ),
                OutlinedButton(
                  onPressed:
                      hasKeyword
                          ? _clearSourceSearchFilter
                          : _showImportActionSheet,
                  child: Text(hasKeyword ? '清空筛选' : '导入书源'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard({
    required int totalSourceCount,
    required int enabledCount,
    required int novelCount,
    required int mangaCount,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      shape: _buildOutlinedCardShape(context),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '书源概览',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildOverviewChip('书源总数', '$totalSourceCount'),
                _buildOverviewChip('启用', '$enabledCount'),
                _buildOverviewChip('小说源', '$novelCount'),
                _buildOverviewChip('漫画源', '$mangaCount'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchPanel() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      shape: _buildOutlinedCardShape(context),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.search_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '书源搜索',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '收起搜索',
                  onPressed: _toggleSearchBar,
                  icon: const Icon(Icons.expand_less_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colorScheme.outline),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                textAlignVertical: TextAlignVertical.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 13.5, height: 1.25),
                decoration: InputDecoration(
                  hintText: '例如：3A小说 / aaawz.cc / 小说',
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    height: 1.25,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  border: InputBorder.none,
                  filled: false,
                  isDense: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsetsDirectional.only(start: 12, end: 6),
                    child: Icon(Icons.search_rounded, size: 18),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  suffixIcon:
                      _searchKeyword.isEmpty
                          ? null
                          : IconButton(
                            tooltip: '清空关键词',
                            onPressed: () => _searchController.clear(),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewChip(String label, String value) {
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

  Widget _buildEmptySourceCard({required bool hasKeyword}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      shape: _buildOutlinedCardShape(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 26,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 10),
            Text(
              hasKeyword ? '未匹配到书源' : '当前没有书源',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              hasKeyword ? '可以清空筛选后再查看。' : '点击下方按钮开始导入书源。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      hasKeyword
                          ? _clearSourceSearchFilter
                          : _showImportActionSheet,
                  icon: Icon(
                    hasKeyword
                        ? Icons.filter_alt_off_rounded
                        : Icons.upload_file_rounded,
                  ),
                  label: Text(hasKeyword ? '清空筛选' : '导入书源'),
                ),
                if (hasKeyword)
                  OutlinedButton(
                    onPressed: _showImportActionSheet,
                    child: const Text('继续导入'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedSourceCard({
    required SourceListItem source,
    required int listIndex,
  }) {
    final delay =
        (listIndex % _kSourceCardEntryStaggerGroup) *
        _kSourceCardEntryStaggerStep;
    final begin = delay.clamp(0.0, 1 - _kSourceCardEntryCurveSpan);
    final end = begin + _kSourceCardEntryCurveSpan;
    final card = _buildSourceCard(source);

    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('source_entry_${source.id}'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: _kSourceCardEntryDuration,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
      child: card,
      builder: (context, value, child) {
        final translateY = (1 - value) * 18;
        final scale = 0.985 + (0.015 * value);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.scale(
              alignment: Alignment.topCenter,
              scale: scale,
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceCard(SourceListItem source) {
    final checkedAtText = _buildConnectivityTestTimeText(source);
    final isTesting = _testingSourceIds.contains(source.id);
    final isChangingEnabled = _changingEnabledSourceIds.contains(source.id);
    final isDeleting = _deletingSourceIds.contains(source.id);
    final selected = _selectedSourceIds.contains(source.id);
    final isActionLocked = _isBatchDeleting || isDeleting;
    final colorScheme = Theme.of(context).colorScheme;
    final hasComment = _hasSourceComment(source.comment);
    final isCommentExpanded = _expandedCommentSourceIds.contains(source.id);
    final commentText = _trimSourceComment(source.comment);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: _buildOutlinedCardShape(context),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: () => _startSelectionMode(source.id),
        onTap: _isSelectionMode ? () => _toggleSelected(source.id) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 6),
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) => _toggleSelected(source.id),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            source.name,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!_isSelectionMode)
                          _buildSourceTrailingActions(
                            source: source,
                            isTesting: isTesting,
                            isChangingEnabled: isChangingEnabled,
                            isDeleting: isDeleting,
                            isActionLocked: isActionLocked,
                            status: source.lastCheckStatus,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final secondaryTextStyle = Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant);
                        final checkedAtTextStyle = Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        );
                        final secondary = Text(
                          _buildSourceSecondaryLine(source),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: secondaryTextStyle,
                        );
                        final checked = Text(
                          '测试时间: $checkedAtText',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: checkedAtTextStyle,
                        );

                        if (constraints.maxWidth < 340) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              secondary,
                              const SizedBox(height: 2),
                              checked,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: secondary),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth * 0.45,
                              ),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: checked,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (hasComment) ...[
                      const SizedBox(height: 3),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _toggleCommentExpanded(source.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sticky_note_2_outlined,
                                size: 15,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isCommentExpanded ? '收起备注' : '展开备注',
                                style: Theme.of(
                                  context,
                                ).textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 2),
                              AnimatedRotation(
                                turns: isCommentExpanded ? 0.5 : 0,
                                duration: _kCommentExpandDuration,
                                curve: Curves.easeOutCubic,
                                child: Icon(
                                  Icons.expand_more_rounded,
                                  size: 15,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: _kCommentExpandDuration,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final slideAnimation = Tween<Offset>(
                            begin: const Offset(0, -0.08),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SizeTransition(
                              sizeFactor: animation,
                              axisAlignment: -1,
                              child: SlideTransition(
                                position: slideAnimation,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child:
                            isCommentExpanded
                                ? Padding(
                                  key: ValueKey<String>(
                                    'source_comment_open_${source.id}',
                                  ),
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      commentText,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                )
                                : const SizedBox.shrink(
                                  key: ValueKey<String>(
                                    'source_comment_closed',
                                  ),
                                ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceTrailingActions({
    required SourceListItem source,
    required bool isTesting,
    required bool isChangingEnabled,
    required bool isDeleting,
    required bool isActionLocked,
    required SourceHealthStatus status,
  }) {
    final showProgress = isTesting || isChangingEnabled || isDeleting;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHealthStatusDot(status),
        const SizedBox(width: 6),
        if (showProgress)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        Transform.scale(
          scale: 0.82,
          child: Switch(
            value: source.enabled,
            onChanged:
                isActionLocked || isChangingEnabled
                    ? null
                    : (value) => _setEnabled(source.id, value),
          ),
        ),
        PopupMenuButton<_SourceAction>(
          tooltip: '更多操作',
          icon: const Icon(Icons.more_vert, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onSelected:
              isActionLocked
                  ? null
                  : (action) => _handleSourceAction(
                    action: action,
                    source: source,
                    isTesting: isTesting,
                  ),
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: _SourceAction.test,
                  enabled: !isTesting && !isActionLocked,
                  child: const Text('连通性测试'),
                ),
                PopupMenuItem(
                  value: _SourceAction.delete,
                  enabled: !isActionLocked,
                  child: const Text('删除书源'),
                ),
              ],
        ),
      ],
    );
  }

  Widget _buildHealthStatusDot(SourceHealthStatus status) {
    final colorScheme = Theme.of(context).colorScheme;

    final color = switch (status) {
      SourceHealthStatus.healthy => const Color(0xFF2E7D32),
      SourceHealthStatus.degraded ||
      SourceHealthStatus.unavailable => colorScheme.error,
      SourceHealthStatus.unknown => colorScheme.onSurfaceVariant.withValues(
        alpha: 0.55,
      ),
    };

    final label = switch (status) {
      SourceHealthStatus.healthy => '可用',
      SourceHealthStatus.degraded || SourceHealthStatus.unavailable => '异常',
      SourceHealthStatus.unknown => '未测',
    };

    return Tooltip(
      message: '测试状态: $label',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  RoundedRectangleBorder _buildOutlinedCardShape(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: colorScheme.outlineVariant.withValues(alpha: 0.72),
      ),
    );
  }

  String _buildSourceSecondaryLine(SourceListItem source) {
    final host = _resolveSourceHost(source.baseUrl);
    final group = (source.group ?? '').trim();
    final groupText = group.isEmpty ? '未分组' : group;
    final typeText = source.isMangaSource ? '漫画' : '小说';
    return '$host · $typeText · $groupText';
  }

  String _resolveSourceHost(String baseUrl) {
    final raw = baseUrl.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) {
      return raw.replaceFirst(RegExp(r'^https?://'), '');
    }

    if (uri.port > 0) {
      return '${uri.host}:${uri.port}';
    }
    return uri.host;
  }

  bool _hasSourceComment(String? comment) {
    return comment != null && comment.trim().isNotEmpty;
  }

  String _trimSourceComment(String? comment) {
    return (comment ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _handleSourceAction({
    required _SourceAction action,
    required SourceListItem source,
    required bool isTesting,
  }) {
    switch (action) {
      case _SourceAction.test:
        if (!isTesting) {
          _runConnectivityTest(source);
        }
        return;
      case _SourceAction.delete:
        _deleteSource(source.id);
        return;
    }
  }

  void _openBatchDiagnostics() {
    context.push('/source-diagnostics');
  }

  Future<void> _showImportActionSheet() async {
    if (_isImporting) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.paste_rounded),
                title: const Text('粘贴导入 JSON'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _importFromPaste();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('链接导入'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _importFromUrl();
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file_rounded),
                title: const Text('文件导入'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _importFromFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importFromPaste() async {
    final text = await _showPasteDialog();
    if (!mounted || text == null) {
      return;
    }

    final content = text.trim();
    if (content.isEmpty) {
      _showMessage('请先粘贴 JSON 内容。');
      return;
    }

    await _importSingleText(content: content, sourceLabel: '粘贴内容');
  }

  Future<void> _importFromUrl() async {
    final input = await _showUrlImportDialog();
    if (!mounted || input == null) {
      return;
    }

    final rawUrl = input.trim();
    if (rawUrl.isEmpty) {
      _showMessage('链接不能为空。');
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    final scheme = uri?.scheme.toLowerCase();
    final isHttpScheme = scheme == 'http' || scheme == 'https';
    if (uri == null || uri.host.isEmpty || !isHttpScheme) {
      _showMessage('链接格式无效，请输入 http/https 开头的 JSON 地址。');
      return;
    }

    _setImporting(true);
    String? content;
    try {
      final response = await Dio(
        BaseOptions(
          responseType: ResponseType.bytes,
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 12),
          followRedirects: true,
          maxRedirects: 5,
          validateStatus:
              (status) => status != null && status >= 200 && status < 400,
          headers: const {'Accept': 'application/json,text/plain,*/*'},
        ),
      ).getUri(uri);

      final payload = response.data;
      final bytes =
          payload is List<int>
              ? payload
              : payload is String
              ? utf8.encode(payload)
              : const <int>[];

      if (bytes.isEmpty) {
        _showMessage('链接导入失败：响应内容为空。');
        return;
      }

      content = _importService.decodeSourceBytes(bytes);
      if (content.trim().isEmpty) {
        _showMessage('链接导入失败：未解析到有效 JSON 内容。');
        return;
      }
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null) {
        _showMessage('链接导入失败：HTTP $statusCode。');
        return;
      }

      final message = error.message?.trim();
      _showMessage(
        '链接导入失败：${message == null || message.isEmpty ? '网络请求异常' : message}',
      );
      return;
    } catch (error) {
      _showMessage('链接导入失败：$error');
      return;
    } finally {
      _setImporting(false);
    }

    final sourceLabel =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.last : uri.host;

    await _importSingleText(content: content, sourceLabel: sourceLabel);
  }

  Future<void> _importFromFile() async {
    XFile? file;

    try {
      file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'JSON',
            extensions: ['json', 'txt'],
            uniformTypeIdentifiers: ['public.json', 'public.plain-text'],
          ),
        ],
        confirmButtonText: '导入书源',
      );
    } on PlatformException catch (error) {
      _showMessage('打开文件选择器失败：${error.message ?? error.code}');
      return;
    } catch (error) {
      _showMessage('打开文件选择器失败：$error');
      return;
    }

    if (!mounted || file == null) {
      return;
    }

    try {
      final bytes = await file.readAsBytes();
      final content = _importService.decodeSourceBytes(bytes);
      await _importSingleText(content: content, sourceLabel: file.name);
    } catch (_) {
      _showMessage('读取文件失败：${file.name}');
    }
  }

  Future<void> _importFromBuiltInBatch() async {
    const assetFiles = ['read.json', 'test_read.json'];

    _setImporting(true);
    try {
      final reports = <SourceImportPreviewReport>[];
      for (final assetFile in assetFiles) {
        try {
          final content = await rootBundle.loadString(assetFile);
          final preview = await _importService.previewFromTextInBackground(
            content,
          );
          if (preview case Success<SourceImportPreviewReport>(
            data: final report,
          )) {
            reports.add(_attachSourceLabel(report, assetFile));
          } else if (preview case Failure<SourceImportPreviewReport>(
            exception: final error,
          )) {
            reports.add(
              SourceImportPreviewReport(
                validSources: const [],
                issues: [
                  SourceImportIssue(
                    sourceLabel: assetFile,
                    message: error.briefMessage,
                  ),
                ],
                compatibilityHints: const [],
                totalCount: 0,
              ),
            );
          }
        } catch (_) {
          reports.add(
            SourceImportPreviewReport(
              validSources: const [],
              issues: [
                SourceImportIssue(
                  sourceLabel: assetFile,
                  message: '读取内置文件失败，请确认已在 pubspec.yaml 注册资源。',
                ),
              ],
              compatibilityHints: const [],
              totalCount: 0,
            ),
          );
        }
      }

      final merged = _mergePreviewReports(reports);
      await _applyImportPreview(merged, actionLabel: '批量导入');
    } finally {
      _setImporting(false);
    }
  }

  Future<void> _importSingleText({
    required String content,
    required String sourceLabel,
  }) async {
    _setImporting(true);
    try {
      final preview = await _importService.previewFromTextInBackground(content);
      if (preview case Failure<SourceImportPreviewReport>(
        exception: final error,
      )) {
        _showMessage(error.briefMessage);
        return;
      }

      final report = _attachSourceLabel(
        (preview as Success<SourceImportPreviewReport>).data,
        sourceLabel,
      );
      await _applyImportPreview(report, actionLabel: '导入');
    } finally {
      _setImporting(false);
    }
  }

  Future<void> _applyImportPreview(
    SourceImportPreviewReport report, {
    required String actionLabel,
  }) async {
    if (report.totalCount == 0 &&
        !report.hasIssues &&
        !report.hasCompatibilityHints) {
      _showMessage('$actionLabel未发现可处理书源。');
      return;
    }

    if (report.validSources.isEmpty) {
      _showMessage('$actionLabel失败：没有可导入书源。');
      return;
    }

    await _repository.upsertAll(report.validSources);
    await _reloadSourceList(reset: true);

    if (report.invalidCount == 0 && report.compatibilityHintCount == 0) {
      _showMessage('$actionLabel成功：共 ${report.validCount} 条。');
      return;
    }

    if (report.invalidCount == 0 && report.compatibilityHintCount > 0) {
      _showMessage(
        '$actionLabel完成：成功 ${report.validCount} 条，兼容提示 ${report.compatibilityHintCount} 条。',
      );
      return;
    }

    _showMessage(
      '$actionLabel完成：成功 ${report.validCount} 条，失败 ${report.invalidCount} 条，兼容提示 ${report.compatibilityHintCount} 条。',
    );
  }

  SourceImportPreviewReport _attachSourceLabel(
    SourceImportPreviewReport report,
    String sourceLabel,
  ) {
    return SourceImportPreviewReport(
      validSources: report.validSources,
      issues: report.issues
          .map((issue) => issue.withSourceLabel(sourceLabel))
          .toList(growable: false),
      compatibilityHints: report.compatibilityHints
          .map((hint) => hint.withSourceLabel(sourceLabel))
          .toList(growable: false),
      totalCount: report.totalCount,
    );
  }

  SourceImportPreviewReport _mergePreviewReports(
    List<SourceImportPreviewReport> reports,
  ) {
    final validSources = <SourceDefinition>[];
    final issues = <SourceImportIssue>[];
    final compatibilityHints = <SourceCompatibilityHint>[];
    var totalCount = 0;

    for (final report in reports) {
      validSources.addAll(report.validSources);
      issues.addAll(report.issues);
      compatibilityHints.addAll(report.compatibilityHints);
      totalCount += report.totalCount;
    }

    return SourceImportPreviewReport(
      validSources: List.unmodifiable(validSources),
      issues: List.unmodifiable(issues),
      compatibilityHints: List.unmodifiable(compatibilityHints),
      totalCount: totalCount,
    );
  }

  void _startSelectionMode(String sourceId) {
    setState(() {
      _isSelectionMode = true;
      _selectedSourceIds.add(sourceId);
    });
  }

  void _toggleSelected(String sourceId) {
    setState(() {
      if (_selectedSourceIds.contains(sourceId)) {
        _selectedSourceIds.remove(sourceId);
      } else {
        _selectedSourceIds.add(sourceId);
      }

      if (_selectedSourceIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  Future<void> _clearAllSources() async {
    if (_isBatchDeleting || _totalImportedCount == 0) {
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: '清空全部书源',
      content: '确认清空全部书源吗？此操作不可恢复。',
      confirmText: '清空',
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isBatchDeleting = true;
    });

    try {
      await _repository.clear();
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedSourceIds.clear();
        _expandedCommentSourceIds.clear();
        _isSelectionMode = false;
      });

      await _reloadSourceList(reset: true);
      _showMessage('已清空全部书源。');
    } catch (_) {
      _showMessage('清空书源失败，请稍后重试。');
    } finally {
      if (mounted) {
        setState(() {
          _isBatchDeleting = false;
        });
      }
    }
  }

  void _toggleCommentExpanded(String sourceId) {
    setState(() {
      if (_expandedCommentSourceIds.contains(sourceId)) {
        _expandedCommentSourceIds.remove(sourceId);
      } else {
        _expandedCommentSourceIds.add(sourceId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedSourceIds.clear();
    });
  }

  void _clearSourceSearchFilter() {
    if (!_showSearchBar &&
        _searchKeyword.isEmpty &&
        _searchController.text.isEmpty) {
      return;
    }

    _searchDebounce?.cancel();
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _showSearchBar = false;
      _searchKeyword = '';
    });
    unawaited(_reloadSourceList(reset: true));
  }

  void _toggleSearchBar() {
    if (_showSearchBar || _searchKeyword.isNotEmpty) {
      _clearSourceSearchFilter();
      return;
    }

    setState(() {
      _showSearchBar = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _searchFocusNode.requestFocus();
    });
  }

  void _onSearchInputChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) {
        return;
      }

      final keyword = _searchController.text.trim();
      if (keyword == _searchKeyword) {
        return;
      }

      setState(() {
        _searchKeyword = keyword;
      });

      unawaited(_reloadSourceList(reset: true));
    });
  }

  void _selectAllVisibleSources() {
    if (_visibleSources.isEmpty || _isBatchDeleting) {
      return;
    }

    setState(() {
      _isSelectionMode = true;
      _selectedSourceIds
        ..clear()
        ..addAll(_visibleSources.map((source) => source.id));
    });
  }

  Future<void> _deleteSelectedSources() async {
    final total = _selectedSourceIds.length;
    if (total == 0 || _isBatchDeleting) {
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: '删除书源',
      content: '确定删除选中的 $total 个书源吗？',
      confirmText: '删除',
    );

    if (confirmed != true) {
      return;
    }

    final ids = _selectedSourceIds.toList(growable: false);
    setState(() {
      _isBatchDeleting = true;
    });

    try {
      await _repository.deleteByIds(ids);

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedSourceIds.clear();
        _isSelectionMode = false;
      });

      await _reloadSourceList(reset: true);
      _showMessage('已删除 $total 条书源。');
    } catch (_) {
      _showMessage('批量删除失败，请稍后重试。');
    } finally {
      if (mounted) {
        setState(() {
          _isBatchDeleting = false;
        });
      }
    }
  }

  Future<void> _setEnabled(String sourceId, bool enabled) async {
    if (_changingEnabledSourceIds.contains(sourceId) || _isBatchDeleting) {
      return;
    }

    setState(() {
      _changingEnabledSourceIds.add(sourceId);
    });

    try {
      await _repository.setEnabled(sourceId: sourceId, enabled: enabled);
      await _reloadSourceList(reset: false);
    } catch (_) {
      _showMessage('更新书源状态失败，请重试。');
    } finally {
      if (mounted) {
        setState(() {
          _changingEnabledSourceIds.remove(sourceId);
        });
      }
    }
  }

  Future<void> _deleteSource(String sourceId) async {
    if (_deletingSourceIds.contains(sourceId) || _isBatchDeleting) {
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: '删除书源',
      content: '确认删除该书源吗？',
      confirmText: '删除',
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _deletingSourceIds.add(sourceId);
    });

    try {
      await _repository.deleteById(sourceId);
      await _reloadSourceList(reset: true);
      _showMessage('已删除书源。');
    } catch (_) {
      _showMessage('删除书源失败，请重试。');
    } finally {
      if (mounted) {
        setState(() {
          _deletingSourceIds.remove(sourceId);
        });
      }
    }
  }

  Future<void> _runConnectivityTest(SourceListItem source) async {
    final keyword = _defaultConnectivityKeyword;

    setState(() {
      _testingSourceIds.add(source.id);
    });

    try {
      final latestSource = await _getSourceById(source.id);
      if (latestSource == null) {
        _showMessage('书源不存在，无法测试。');
        return;
      }

      final capability = SourceCapabilityAnalyzer.fromSource(latestSource);
      final report = await _searchServiceClient
          .testSingleSource(
            source: latestSource,
            keyword: keyword,
            validateRules: false,
            skipInit: true,
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 6),
          )
          .timeout(
            const Duration(seconds: 12),
            onTimeout:
                () => SourceConnectivityTestReport(
                  sourceId: latestSource.id,
                  sourceName: latestSource.name,
                  keyword: keyword,
                  method: HttpRequestMethod.get,
                  matchedBookCount: 0,
                  error: const AppException(
                    code: ErrorCode.network,
                    stage: ErrorStage.search,
                    briefMessage: '连通性测试超时，请检查网络或切换书源后重试。',
                  ),
                  probeOnly: true,
                ),
          );

      if (!mounted) {
        return;
      }

      await _showConnectivityResultDialog(report, capability: capability);
      await _reloadSourceList(reset: false);
    } finally {
      if (mounted) {
        setState(() {
          _testingSourceIds.remove(source.id);
        });
      }
    }
  }

  Future<SourceDefinition?> _getSourceById(String sourceId) {
    return AppDatabase.instance.getSourceById(sourceId);
  }

  Future<void> _showConnectivityResultDialog(
    SourceConnectivityTestReport report, {
    SourceCapabilityProfile? capability,
  }) {
    final error = report.error;
    final isSuccess = report.isSuccess;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final maxWidth = AppLayout.dialogMaxWidth(dialogContext);

        return AlertDialog(
          insetPadding: AppSpacing.dialogInsetPadding(dialogContext),
          title: Text('连通性测试 - ${report.sourceName}'),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSuccess
                        ? report.probeOnly
                            ? '结果: 通过（网络可达）'
                            : '结果: 通过'
                        : '结果: 失败',
                  ),
                  const SizedBox(height: 8),
                  Text('关键词: ${report.keyword}'),
                  const SizedBox(height: 4),
                  Text('请求方法: ${report.method.name.toUpperCase()}'),
                  if (report.statusCode != null) ...[
                    const SizedBox(height: 4),
                    Text('响应状态: ${report.statusCode}'),
                  ],
                  if (report.requestUrl != null &&
                      report.requestUrl!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    SelectableText('请求地址: ${report.requestUrl}'),
                  ],
                  if (capability != null) ...[
                    const SizedBox(height: 8),
                    Text('能力检查: ${capability.compatibilityLabel}'),
                    if (capability.reasons.isNotEmpty)
                      ...capability.reasons.map(
                        (reason) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('- $reason'),
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                  if (isSuccess)
                    Text(
                      report.probeOnly
                          ? '探活模式: 已验证网络可达（未执行规则解析）'
                          : '规则命中: ${report.matchedBookCount} 条',
                    )
                  else ...[
                    Text('失败分类: ${_failureTypeText(error!.code)}'),
                    const SizedBox(height: 4),
                    Text('错误码: ${error.code.name}'),
                    const SizedBox(height: 4),
                    Text('错误信息: ${error.briefMessage}'),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  String _failureTypeText(ErrorCode code) {
    return switch (code) {
      ErrorCode.network => '网络失败',
      ErrorCode.ruleParse || ErrorCode.decode => '解析失败',
      ErrorCode.ruleMatchEmpty => '规则命中为空',
      ErrorCode.validation => '规则为空或配置不完整',
      ErrorCode.unknownSource || ErrorCode.unknown => '未知失败',
    };
  }

  String _buildConnectivityTestTimeText(SourceListItem source) {
    if (source.lastCheckStatus == SourceHealthStatus.unknown ||
        source.lastCheckedAt == null) {
      return '未测试';
    }

    return _formatDateTime(source.lastCheckedAt);
  }

  String _formatDateTime(DateTime? time) {
    if (time == null) {
      return '未测试';
    }

    final local = time.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  void _setImporting(bool value) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isImporting = value;
    });
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<String?> _showPasteDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final maxWidth = AppLayout.dialogMaxWidth(dialogContext);
        final keyboardInset = AppLayout.keyboardInset(dialogContext);

        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: AlertDialog(
            insetPadding: AppSpacing.dialogInsetPadding(dialogContext),
            scrollable: true,
            title: const Text('粘贴 JSON 内容'),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: TextField(
                controller: controller,
                minLines: 10,
                maxLines: 16,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: '{...} 或 [{...}]',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.of(dialogContext).pop(controller.text),
                child: const Text('导入'),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<String?> _showUrlImportDialog() async {
    final controller = TextEditingController(
      text: 'https://www.yck.email/yuedu/shuyuan/json/id/6930.json',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final maxWidth = AppLayout.dialogMaxWidth(dialogContext);
        final keyboardInset = AppLayout.keyboardInset(dialogContext);

        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: AlertDialog(
            insetPadding: AppSpacing.dialogInsetPadding(dialogContext),
            scrollable: true,
            title: const Text('链接导入书源'),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'https://example.com/source.json',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.of(dialogContext).pop(controller.text),
                child: const Text('导入'),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding: AppSpacing.dialogInsetPadding(dialogContext),
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }
}

class _SourceLoadingCard extends StatelessWidget {
  const _SourceLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '正在加载书源列表...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ImportAction { paste, url, file, batchSample }

enum _SourceAction { test, delete }
