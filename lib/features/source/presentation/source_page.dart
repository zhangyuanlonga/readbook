import 'dart:async';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  late final SearchService _searchService;

  bool _isImporting = false;
  bool _isSelectionMode = false;
  bool _isBatchDeleting = false;
  final Set<String> _testingSourceIds = <String>{};
  final Set<String> _changingEnabledSourceIds = <String>{};
  final Set<String> _deletingSourceIds = <String>{};
  final Set<String> _selectedSourceIds = <String>{};
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
  int _queryTicket = 0;

  static const int _kPageSize = 120;
  static const String _defaultConnectivityKeyword = '凡人修仙传';

  @override
  void initState() {
    super.initState();
    _searchService = SearchService(sourceRepository: _repository);
    _searchController.addListener(_onSearchInputChanged);
    _scrollController.addListener(_onSourceListScroll);
    unawaited(_reloadSourceList(reset: true));
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
      final totalFuture = AppDatabase.instance.countSourceListItems(
        keyword: keyword,
      );
      final enabledFuture = AppDatabase.instance.countSourceListItems(
        keyword: keyword,
        enabledOnly: true,
      );
      final importedFuture = AppDatabase.instance.countSourceListItems();

      final page = await pageFuture;
      final total = await totalFuture;
      final enabled = await enabledFuture;
      final imported = await importedFuture;

      if (!mounted || ticket != _queryTicket) {
        return;
      }

      setState(() {
        _visibleSources = page;
        _totalCount = total;
        _enabledCount = enabled.clamp(0, total);
        _totalImportedCount = imported;
        _nextOffset = page.length;
        _hasMorePages = page.length < total;
        _isInitialLoading = false;
        _isPageLoading = false;
        _listErrorText = null;
      });

      _syncSelectionWithVisibleSources();
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
      final page = await AppDatabase.instance.querySourceListItems(
        offset: _nextOffset,
        limit: _kPageSize,
        keyword: keyword,
      );

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
          if (_isSelectionMode) ...[
            IconButton(
              onPressed:
                  _visibleSources.isEmpty ? null : _selectAllVisibleSources,
              tooltip: '全选',
              icon: const Icon(Icons.select_all),
            ),
            IconButton(
              onPressed: _visibleSources.isEmpty ? null : _invertSelection,
              tooltip: '反选',
              icon: const Icon(Icons.flip),
            ),
            IconButton(
              onPressed:
                  _selectedSourceIds.isEmpty || _isBatchDeleting
                      ? null
                      : _deleteSelectedSources,
              tooltip: '删除已选',
              icon: const Icon(Icons.delete_outline),
            ),
          ] else ...[
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

    final headerCount = 2 + (_isSelectionMode ? 1 : 0);
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

    final searchPanelIndex = 1;
    final selectionIndex = _isSelectionMode ? 2 : -1;
    final listStartIndex = _isSelectionMode ? 3 : 2;

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 16 + bottomSafe),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildOverviewCard(
            totalCount: _totalCount,
            enabledCount: _enabledCount,
            totalImportedCount: _totalImportedCount,
          );
        }

        if (index == searchPanelIndex) {
          return _buildSearchPanelSlot(showSearchPanel: showSearchPanel);
        }

        if (index == selectionIndex) {
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _buildSelectionHintCard(),
          );
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
              padding: const EdgeInsets.only(top: 10),
              child: _buildListErrorCard(_listErrorText!),
            );
          }
          return const SizedBox.shrink();
        }

        if (showEmpty) {
          if (itemListIndex == 0) {
            return Padding(
              padding: const EdgeInsets.only(top: 10),
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
          return _buildSourceCard(source);
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
                padding: const EdgeInsets.only(top: 10),
                child: _buildSearchPanel(),
              )
              : const SizedBox.shrink(key: ValueKey('search_panel_hidden')),
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

    return Card(
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
            FilledButton.tonal(
              onPressed: () => unawaited(_reloadSourceList(reset: true)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard({
    required int totalCount,
    required int enabledCount,
    required int totalImportedCount,
  }) {
    final disabledCount = (totalCount - enabledCount).clamp(0, totalCount);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
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
                _buildOverviewChip('当前结果', '$totalCount'),
                _buildOverviewChip('启用', '$enabledCount'),
                _buildOverviewChip('停用', '$disabledCount'),
                _buildOverviewChip('已导入', '$totalImportedCount'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchPanel() {
    final colorScheme = Theme.of(context).colorScheme;

    final helperText =
        _searchKeyword.isEmpty ? '输入名称、域名、分组或备注进行筛选' : '匹配 $_totalCount 条书源';

    return Card(
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
                decoration: InputDecoration(
                  hintText: '例如：3A小说 / aaawz.cc / 小说',
                  border: InputBorder.none,
                  filled: false,
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  suffixIcon:
                      _searchKeyword.isEmpty
                          ? null
                          : IconButton(
                            tooltip: '清空关键词',
                            onPressed: () => _searchController.clear(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              helperText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
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
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 28,
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
              hasKeyword ? '换个关键词试试。' : '点击右上角 + 开始导入。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionHintCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 18,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedSourceIds.isEmpty
                  ? '多选模式：可点击条目进行选择，也可使用顶部全选/反选。'
                  : '多选模式：已选 ${_selectedSourceIds.length} 项，点击右上角删除。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(SourceListItem source) {
    final statusText = _healthStatusText(source.lastCheckStatus);
    final checkedAtText = _formatDateTime(source.lastCheckedAt);
    final isTesting = _testingSourceIds.contains(source.id);
    final isChangingEnabled = _changingEnabledSourceIds.contains(source.id);
    final isDeleting = _deletingSourceIds.contains(source.id);
    final selected = _selectedSourceIds.contains(source.id);
    final isActionLocked = _isBatchDeleting || isDeleting;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onLongPress: () => _startSelectionMode(source.id),
        onTap: _isSelectionMode ? () => _toggleSelected(source.id) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 6),
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
                        if (source.comment != null &&
                            source.comment!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.sticky_note_2_outlined,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        source.baseUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildSourceMetaChip('分组', source.group ?? '未分组'),
                        _buildSourceMetaChip('状态', statusText),
                        _buildSourceMetaChip('测试', checkedAtText),
                      ],
                    ),
                    if (source.comment != null &&
                        source.comment!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '备注：${source.comment!.trim()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (!_isSelectionMode)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: source.enabled,
                      onChanged:
                          isActionLocked || isChangingEnabled
                              ? null
                              : (value) => _setEnabled(source.id, value),
                    ),
                    if (isTesting || isChangingEnabled || isDeleting)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    PopupMenuButton<_SourceAction>(
                      tooltip: '更多操作',
                      icon: const Icon(Icons.more_vert),
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
                              value: _SourceAction.editComment,
                              enabled: !isActionLocked,
                              child: const Text('编辑备注'),
                            ),
                            PopupMenuItem(
                              value: _SourceAction.delete,
                              enabled: !isActionLocked,
                              child: const Text('删除书源'),
                            ),
                          ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceMetaChip(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
    );
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
      case _SourceAction.editComment:
        _editComment(source);
        return;
      case _SourceAction.delete:
        _deleteSource(source.id);
        return;
    }
  }

  Future<void> _importFromPaste() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final clipboardText = clipboardData?.text?.trim() ?? '';
      if (clipboardText.isNotEmpty) {
        await _importSingleText(content: clipboardText, sourceLabel: '剪贴板');
        return;
      }
    } on PlatformException {
      _showMessage('读取剪贴板失败，请手动粘贴 JSON 内容。');
    }

    final text = await _showPasteDialog();
    if (!mounted || text == null) {
      return;
    }

    await _importSingleText(content: text, sourceLabel: '粘贴内容');
  }

  Future<void> _importFromFile() async {
    XFile? file;

    try {
      file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON', extensions: ['json', 'txt']),
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
    if (report.totalCount == 0 && !report.hasIssues) {
      _showMessage('$actionLabel未发现可处理书源。');
      return;
    }

    var shouldImport = true;
    if (report.hasIssues) {
      shouldImport =
          await _showImportPreviewDialog(report, title: '$actionLabel预校验结果') ??
          false;
    }

    if (!shouldImport) {
      return;
    }

    if (report.validSources.isEmpty) {
      _showMessage('$actionLabel失败：没有可导入书源。');
      return;
    }

    await _repository.upsertAll(report.validSources);
    await _reloadSourceList(reset: true);

    if (report.invalidCount == 0) {
      _showMessage('$actionLabel成功：共 ${report.validCount} 条。');
      return;
    }

    _showMessage(
      '$actionLabel完成：成功 ${report.validCount} 条，失败 ${report.invalidCount} 条。',
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
      totalCount: report.totalCount,
    );
  }

  SourceImportPreviewReport _mergePreviewReports(
    List<SourceImportPreviewReport> reports,
  ) {
    final validSources = <SourceDefinition>[];
    final issues = <SourceImportIssue>[];
    var totalCount = 0;

    for (final report in reports) {
      validSources.addAll(report.validSources);
      issues.addAll(report.issues);
      totalCount += report.totalCount;
    }

    return SourceImportPreviewReport(
      validSources: List.unmodifiable(validSources),
      issues: List.unmodifiable(issues),
      totalCount: totalCount,
    );
  }

  Future<bool?> _showImportPreviewDialog(
    SourceImportPreviewReport report, {
    required String title,
  }) {
    final issueLines = report.issues
        .map((issue) => issue.toDisplayText())
        .take(80)
        .toList(growable: false);

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final maxWidth = AppLayout.dialogMaxWidth(dialogContext, maxWidth: 620);

        return AlertDialog(
          insetPadding: AppSpacing.dialogInsetPadding(dialogContext),
          scrollable: true,
          title: Text(title),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('总条目：${report.totalCount}'),
                  const SizedBox(height: 4),
                  Text('可导入：${report.validCount}'),
                  const SizedBox(height: 4),
                  Text('失败：${report.invalidCount}'),
                  const SizedBox(height: 10),
                  Text(
                    '失败明细（含条目和行号）',
                    style: Theme.of(dialogContext).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  ...issueLines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: SelectableText(line),
                    ),
                  ),
                  if (report.issues.length > issueLines.length)
                    Text(
                      '... 其余 ${report.issues.length - issueLines.length} 条请查看日志',
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton.tonal(
              onPressed:
                  report.validCount > 0
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
              child: const Text('仅导入可用书源'),
            ),
          ],
        );
      },
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
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedSourceIds.clear();
    });
  }

  void _toggleSearchBar() {
    if (_showSearchBar || _searchKeyword.isNotEmpty) {
      _searchDebounce?.cancel();
      _searchFocusNode.unfocus();
      _searchController.clear();
      setState(() {
        _showSearchBar = false;
        _searchKeyword = '';
      });
      unawaited(_reloadSourceList(reset: true));
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
    setState(() {
      _selectedSourceIds
        ..clear()
        ..addAll(_visibleSources.map((source) => source.id));
    });
  }

  void _invertSelection() {
    final allIds = _visibleSources.map((source) => source.id).toSet();
    setState(() {
      final next = <String>{};
      for (final id in allIds) {
        if (!_selectedSourceIds.contains(id)) {
          next.add(id);
        }
      }
      _selectedSourceIds
        ..clear()
        ..addAll(next);
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

  Future<void> _editComment(SourceListItem source) async {
    final input = await _showCommentDialog(source.comment);
    if (!mounted || input == null) {
      return;
    }

    final latestSource = await _getSourceById(source.id);
    if (latestSource == null) {
      _showMessage('书源不存在，无法更新备注。');
      return;
    }

    final trimmed = input.trim();
    await _repository.upsertAll([
      latestSource.copyWith(comment: trimmed, clearComment: trimmed.isEmpty),
    ]);
    await _reloadSourceList(reset: false);

    _showMessage(trimmed.isEmpty ? '备注已清空。' : '备注已更新。');
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

      final report = await _searchService
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

      await _showConnectivityResultDialog(report);
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
    SourceConnectivityTestReport report,
  ) {
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

  String _healthStatusText(SourceHealthStatus status) {
    return switch (status) {
      SourceHealthStatus.unknown => '未测试',
      SourceHealthStatus.healthy => '可用',
      SourceHealthStatus.degraded => '异常(规则/解析)',
      SourceHealthStatus.unavailable => '不可用(网络/服务)',
    };
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

  Future<String?> _showCommentDialog(String? initialValue) async {
    final controller = TextEditingController(text: initialValue ?? '');

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
            title: const Text('编辑备注'),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: TextField(
                controller: controller,
                minLines: 2,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '输入备注，留空可清空备注',
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
                child: const Text('保存'),
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

enum _ImportAction { paste, file, batchSample }

enum _SourceAction { test, editComment, delete }
