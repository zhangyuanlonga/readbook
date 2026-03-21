import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

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
import '../application/external_source_import_bridge.dart';
import '../application/source_import_service.dart';

enum _SourceSort { smart, nameAsc, enabledFirst }

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
  final Set<String> _changingGroupSourceIds = <String>{};
  final Set<String> _deletingSourceIds = <String>{};
  final Set<String> _exportingSourceIds = <String>{};
  final Set<String> _selectedSourceIds = <String>{};
  List<SourceListItem> _visibleSources = const <SourceListItem>[];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  StreamSubscription<IncomingSourceImportPayload>? _incomingImportSubscription;
  String _searchKeyword = '';
  _SourceSort _sourceSort = _SourceSort.smart;
  bool _isPageLoading = false;
  bool _isInitialLoading = true;
  bool _hasMorePages = true;
  String? _listErrorText;
  int _nextOffset = 0;
  int _totalCount = 0;
  int _queryTicket = 0;
  bool _loadMoreScheduledFromBuild = false;
  bool _isConsumingExternalImportPayloads = false;
  String? _selectedGroupFilter;
  bool _filterUngroupedOnly = false;
  bool _isGroupFilterLoading = false;

  bool get _hasSearchKeyword => _searchKeyword.trim().isNotEmpty;
  bool get _isGroupFilterActive =>
      _selectedGroupFilter != null || _filterUngroupedOnly;
  bool get _hasActiveFilters => _hasSearchKeyword || _isGroupFilterActive;

  static const int _kPageSize = 60;
  static const String _defaultConnectivityKeyword = '凡人修仙传';
  static const Duration _kSourceListLoadTimeout = Duration(seconds: 8);
  static const Duration _kSourceCardEntryDuration = Duration(milliseconds: 420);
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
    _incomingImportSubscription = ExternalSourceImportBridge
        .instance
        .payloadStream
        .listen((_) {
          unawaited(_consumePendingExternalImportPayloads());
        });
    unawaited(ExternalSourceImportBridge.instance.initialize());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_consumePendingExternalImportPayloads());
      unawaited(_reloadSourceList(reset: true));
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _incomingImportSubscription?.cancel();
    _scrollController.removeListener(_onSourceListScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchInputChanged);
    _searchController.dispose();
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
    final groupEquals = _selectedGroupFilter;
    final includeUngroupedOnly = _filterUngroupedOnly;
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
        groupEquals: groupEquals,
        includeUngroupedOnly: includeUngroupedOnly,
      );
      final summaryFuture = AppDatabase.instance.summarizeSourceListItems(
        keyword: keyword,
        groupEquals: groupEquals,
        includeUngroupedOnly: includeUngroupedOnly,
      );

      final results = await Future.wait<Object?>([
        pageFuture,
        summaryFuture,
      ]).timeout(_kSourceListLoadTimeout);

      final page = results[0] as List<SourceListItem>;
      final summary = results[1] as SourceListCountSummary;

      if (!mounted || ticket != _queryTicket) {
        return;
      }

      setState(() {
        _visibleSources = _applySort(page);
        _totalCount = summary.totalCount;
        _nextOffset = page.length;
        _hasMorePages = page.length < summary.totalCount;
        _isInitialLoading = false;
        _isPageLoading = false;
        _listErrorText = null;
      });

      _syncSelectionWithVisibleSources();
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
    final groupEquals = _selectedGroupFilter;
    final includeUngroupedOnly = _filterUngroupedOnly;

    setState(() {
      _isPageLoading = true;
    });

    try {
      final page = await AppDatabase.instance
          .querySourceListItems(
            offset: _nextOffset,
            limit: _kPageSize,
            keyword: keyword,
            groupEquals: groupEquals,
            includeUngroupedOnly: includeUngroupedOnly,
          )
          .timeout(_kSourceListLoadTimeout);

      if (!mounted || ticket != _queryTicket) {
        return;
      }

      setState(() {
        _visibleSources = _applySort([..._visibleSources, ...page]);
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

  void _scheduleLoadNextPageFromBuild() {
    if (_loadMoreScheduledFromBuild || !mounted) {
      return;
    }
    _loadMoreScheduledFromBuild = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreScheduledFromBuild = false;
      if (!mounted) {
        return;
      }
      unawaited(_loadNextPage());
    });
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
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted || _isSelectionMode) {
          return;
        }
        context.go('/mine');
      },
      child: Scaffold(
        appBar: AppBar(
          leading:
              _isSelectionMode
                  ? IconButton(
                    onPressed: _exitSelectionMode,
                    tooltip: '取消选择',
                    icon: const Icon(Icons.close),
                  )
                  : IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                        return;
                      }
                      context.go('/mine');
                    },
                    tooltip: '返回',
                    icon: const Icon(Icons.arrow_back),
                  ),
          title: Text(
            _isSelectionMode ? '已选择 ${_selectedSourceIds.length} 项' : '书源',
          ),
          actions: [
            if (!_isSelectionMode) ...[
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
        bottomNavigationBar:
            _isSelectionMode ? _buildSelectionActionBar() : null,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surfaceContainerLow,
              ],
            ),
          ),
          child: _buildSourceListContent(
            horizontal: horizontal,
            bottomSafe: bottomSafe,
          ),
        ),
      ),
    );
  }

  Widget _buildSourceListContent({
    required double horizontal,
    required double bottomSafe,
  }) {
    final showEmpty = !_isInitialLoading && _visibleSources.isEmpty;
    final showErrorCard = _listErrorText != null && _visibleSources.isEmpty;
    final showLoadingCard = _isInitialLoading;

    const headerCount = 1;
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

    const headerIndex = 0;
    const listStartIndex = 1;

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 16 + bottomSafe),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == headerIndex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildTopFilterBar(),
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
              child: _buildEmptySourceCard(),
            );
          }
          return const SizedBox.shrink();
        }

        if (itemListIndex >= 0 && itemListIndex < _visibleSources.length) {
          final source = _visibleSources[itemListIndex];
          if (itemListIndex >= _visibleSources.length - 8) {
            _scheduleLoadNextPageFromBuild();
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
                      _isBatchDeleting || _totalCount == 0
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
    final hasFilters = _hasActiveFilters;

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
                      hasFilters
                          ? _clearSourceSearchFilter
                          : _showImportActionSheet,
                  child: Text(hasFilters ? '清空筛选' : '导入书源'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopFilterBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      shape: _buildOutlinedCardShape(context),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  textAlignVertical: TextAlignVertical.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    height: 1.25,
                  ),
                  decoration: InputDecoration(
                    hintText: '搜索书源名称或域名',
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
                              onPressed: _clearSourceSearchFilter,
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildSortButton(),
            IconButton(
              tooltip: '分组筛选',
              onPressed: _isGroupFilterLoading ? null : _showGroupFilterSheet,
              icon:
                  _isGroupFilterLoading
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.filter_alt_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<_SourceSort>(
      tooltip: '排序',
      onSelected: (value) {
        if (value == _sourceSort) {
          return;
        }
        setState(() {
          _sourceSort = value;
          _visibleSources = _applySort(_visibleSources);
        });
      },
      itemBuilder:
          (context) => [
            CheckedPopupMenuItem<_SourceSort>(
              value: _SourceSort.nameAsc,
              checked: _sourceSort == _SourceSort.nameAsc,
              child: const Text('名称排序'),
            ),
            CheckedPopupMenuItem<_SourceSort>(
              value: _SourceSort.smart,
              checked: _sourceSort == _SourceSort.smart,
              child: const Text('智能排序'),
            ),
            CheckedPopupMenuItem<_SourceSort>(
              value: _SourceSort.enabledFirst,
              checked: _sourceSort == _SourceSort.enabledFirst,
              child: const Text('是否启用'),
            ),
          ],
      child: Container(
        height: 46,
        width: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: const Icon(Icons.reorder_rounded, size: 20),
      ),
    );
  }

  List<SourceListItem> _applySort(List<SourceListItem> input) {
    final output = [...input];
    switch (_sourceSort) {
      case _SourceSort.smart:
        output.sort((a, b) {
          if (a.enabled != b.enabled) {
            return a.enabled ? -1 : 1;
          }

          final healthDiff = _smartHealthPriority(
            a.lastCheckStatus,
          ).compareTo(_smartHealthPriority(b.lastCheckStatus));
          if (healthDiff != 0) {
            return healthDiff;
          }

          final aCheckedAt = a.lastCheckedAt;
          final bCheckedAt = b.lastCheckedAt;
          if (aCheckedAt != null && bCheckedAt != null) {
            final checkedDiff = bCheckedAt.compareTo(aCheckedAt);
            if (checkedDiff != 0) {
              return checkedDiff;
            }
          } else if (aCheckedAt != null || bCheckedAt != null) {
            return aCheckedAt != null ? -1 : 1;
          }

          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case _SourceSort.nameAsc:
        output.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case _SourceSort.enabledFirst:
        output.sort((a, b) {
          if (a.enabled != b.enabled) {
            return a.enabled ? -1 : 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
    }
    return output;
  }

  int _smartHealthPriority(SourceHealthStatus status) {
    return switch (status) {
      SourceHealthStatus.healthy => 0,
      SourceHealthStatus.degraded => 1,
      SourceHealthStatus.unknown => 2,
      SourceHealthStatus.unavailable => 3,
    };
  }

  Widget _buildEmptySourceCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final hasFilters = _hasActiveFilters;

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
              hasFilters ? '未匹配到书源' : '当前没有书源',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters ? '可以清空筛选后再查看。' : '点击下方按钮开始导入书源。',
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
                      hasFilters
                          ? _clearSourceSearchFilter
                          : _showImportActionSheet,
                  icon: Icon(
                    hasFilters
                        ? Icons.filter_alt_off_rounded
                        : Icons.upload_file_rounded,
                  ),
                  label: Text(hasFilters ? '清空筛选' : '导入书源'),
                ),
                if (hasFilters)
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
    final isTesting = _testingSourceIds.contains(source.id);
    final isChangingEnabled = _changingEnabledSourceIds.contains(source.id);
    final isDeleting = _deletingSourceIds.contains(source.id);
    final isExporting = _exportingSourceIds.contains(source.id);
    final selected = _selectedSourceIds.contains(source.id);
    final isActionLocked = _isBatchDeleting || isDeleting || isExporting;

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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        source.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
                        isExporting: isExporting,
                        isActionLocked: isActionLocked,
                      ),
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
    required bool isExporting,
    required bool isActionLocked,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
        const SizedBox(width: 4),
        _buildGroupChip(source),
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
                  value: _SourceAction.export,
                  enabled: !isActionLocked,
                  child: const Text('导出书源'),
                ),
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

  RoundedRectangleBorder _buildOutlinedCardShape(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: colorScheme.outlineVariant.withValues(alpha: 0.72),
      ),
    );
  }

  Widget _buildGroupChip(SourceListItem source) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final normalized = _normalizeGroupLabel(source.group);
    final label = normalized ?? '未分组';
    final isUpdating = _changingGroupSourceIds.contains(source.id);
    final isLocked = _isSelectionMode || _isBatchDeleting;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: isLocked ? null : () => _onGroupChipTapped(source),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open_rounded,
                size: 14,
                color:
                    isLocked
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.primary,
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 90),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        isLocked
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (isUpdating)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                )
              else if (!isLocked)
                Icon(
                  Icons.expand_more_rounded,
                  size: 14,
                  color: colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _normalizeGroupLabel(String? group) {
    final normalized = group?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  void _handleSourceAction({
    required _SourceAction action,
    required SourceListItem source,
    required bool isTesting,
  }) {
    switch (action) {
      case _SourceAction.export:
        unawaited(_exportSource(source));
        return;
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

  Future<void> _showGroupFilterSheet() async {
    if (_isGroupFilterLoading) {
      return;
    }

    setState(() {
      _isGroupFilterLoading = true;
    });

    List<String> groups = const <String>[];
    try {
      groups = await AppDatabase.instance.listSourceGroups();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isGroupFilterLoading = false;
      });
      _showMessage('加载分组失败：$error');
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isGroupFilterLoading = false;
    });

    final selection = await showModalBottomSheet<_GroupFilterResult>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _SourceGroupFilterSheet(
          availableGroups: groups,
          initialGroup: _selectedGroupFilter,
          initialUngrouped: _filterUngroupedOnly,
        );
      },
    );

    if (!mounted || selection == null) {
      return;
    }

    if (_selectedGroupFilter == selection.group &&
        _filterUngroupedOnly == selection.ungrouped) {
      return;
    }

    setState(() {
      _selectedGroupFilter = selection.group;
      _filterUngroupedOnly = selection.ungrouped;
    });
    unawaited(_reloadSourceList(reset: true));
  }

  Future<void> _onGroupChipTapped(SourceListItem source) async {
    if (_isSelectionMode || _isBatchDeleting) {
      return;
    }

    List<String> groups = const <String>[];
    try {
      groups = await AppDatabase.instance.listSourceGroups();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('加载分组失败：$error');
      return;
    }

    if (!mounted) {
      return;
    }

    final normalizedGroups =
        groups.map(_normalizeGroupLabel).whereType<String>().toSet().toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final selection = await showModalBottomSheet<_SourceGroupPickerResult>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _SourceGroupPickerSheet(
          availableGroups: normalizedGroups,
          initialGroup: _normalizeGroupLabel(source.group),
        );
      },
    );

    if (!mounted || selection == null) {
      return;
    }

    final currentGroup = _normalizeGroupLabel(source.group);
    final nextGroup = _normalizeGroupLabel(selection.group);

    if (currentGroup == nextGroup) {
      return;
    }

    await _updateSourceGroup(source: source, nextGroup: nextGroup);
  }

  Future<void> _updateSourceGroup({
    required SourceListItem source,
    required String? nextGroup,
  }) async {
    if (_changingGroupSourceIds.contains(source.id)) {
      return;
    }

    setState(() {
      _changingGroupSourceIds.add(source.id);
    });

    try {
      await _repository.setGroup(sourceId: source.id, group: nextGroup);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _changingGroupSourceIds.remove(source.id);
      });
      _showMessage('更新分组失败：$error');
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _changingGroupSourceIds.remove(source.id);
      final index = _visibleSources.indexWhere((item) => item.id == source.id);
      if (index == -1) {
        return;
      }

      final updated = SourceListItem(
        id: source.id,
        name: source.name,
        baseUrl: source.baseUrl,
        group: nextGroup,
        enabled: source.enabled,
        comment: source.comment,
        sourceType: source.sourceType,
        lastCheckStatus: source.lastCheckStatus,
        lastCheckedAt: source.lastCheckedAt,
      );

      final nextList = [..._visibleSources];
      nextList[index] = updated;
      _visibleSources = nextList;
    });
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
    final input = await _showUrlImportPage();
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

  Future<void> _consumePendingExternalImportPayloads() async {
    if (_isConsumingExternalImportPayloads) {
      return;
    }

    _isConsumingExternalImportPayloads = true;
    try {
      while (mounted) {
        final payload =
            ExternalSourceImportBridge.instance.consumePendingPayload();
        if (payload == null) {
          break;
        }
        await _importFromExternalPayload(payload);
      }
    } finally {
      _isConsumingExternalImportPayloads = false;
    }
  }

  Future<void> _importFromExternalPayload(
    IncomingSourceImportPayload payload,
  ) async {
    final sourceLabel =
        payload.label.trim().isEmpty ? '外部书源' : payload.label.trim();

    try {
      final content = _importService.decodeSourceBytes(payload.bytes);
      if (content.trim().isEmpty) {
        _showMessage('导入失败：$sourceLabel 内容为空。');
        return;
      }
      await _importSingleText(content: content, sourceLabel: sourceLabel);
    } catch (_) {
      _showMessage('读取外部文件失败：$sourceLabel');
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
    if (_isBatchDeleting || _totalCount == 0) {
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

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedSourceIds.clear();
    });
  }

  void _clearSourceSearchFilter() {
    final hasPendingInput = _searchController.text.isNotEmpty;
    final hasFilters = _hasActiveFilters;
    if (!hasPendingInput && !hasFilters) {
      return;
    }

    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchKeyword = '';
      _selectedGroupFilter = null;
      _filterUngroupedOnly = false;
    });
    unawaited(_reloadSourceList(reset: true));
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

  Future<void> _exportSource(SourceListItem source) async {
    if (_exportingSourceIds.contains(source.id)) {
      return;
    }

    setState(() {
      _exportingSourceIds.add(source.id);
    });

    try {
      final latestSource = await _getSourceById(source.id);
      if (latestSource == null) {
        _showMessage('书源不存在或已被删除。');
        return;
      }

      final suggestedName =
          '${_sanitizeFileToken(latestSource.name)}_${_timestampToken()}.json';
      final outputPath = await _resolveSourceExportTargetPath(suggestedName);
      if (outputPath == null || outputPath.trim().isEmpty) {
        _showMessage('已取消导出。');
        return;
      }

      final file = File(outputPath.trim());
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      final exportEntry = _buildSourceExportEntry(latestSource);
      final content = const JsonEncoder.withIndent(
        '  ',
      ).convert(<Map<String, dynamic>>[exportEntry]);
      await file.writeAsString(content, flush: true);

      final hasOriginalSource =
          latestSource.originalSource != null &&
          latestSource.originalSource!.isNotEmpty;
      if (hasOriginalSource) {
        _showMessage('导出成功：${file.path}');
      } else {
        _showMessage('导出成功：${file.path}（已按兼容格式生成）');
      }
    } catch (error) {
      _showMessage('导出失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _exportingSourceIds.remove(source.id);
        });
      }
    }
  }

  Map<String, dynamic> _buildSourceExportEntry(SourceDefinition source) {
    final original = source.originalSource;
    if (original != null && original.isNotEmpty) {
      return Map<String, dynamic>.from(original);
    }
    return _buildFallbackExportEntry(source);
  }

  Map<String, dynamic> _buildFallbackExportEntry(SourceDefinition source) {
    final payload = <String, dynamic>{
      'bookSourceName': source.name,
      'bookSourceUrl': source.baseUrl,
      'bookSourceType': source.sourceType,
      'enabled': source.enabled,
    };
    final group = source.group?.trim();
    if (group != null && group.isNotEmpty) {
      payload['bookSourceGroup'] = group;
    }
    final comment = source.comment?.trim();
    if (comment != null && comment.isNotEmpty) {
      payload['bookSourceComment'] = comment;
    }
    if (source.headers.isNotEmpty) {
      payload['header'] = source.headers;
    }

    final rules = source.rules;
    _putStringIfNotBlank(payload, 'searchUrl', rules.searchRule);
    _putStringIfNotBlank(payload, 'searchInitRule', rules.searchInitRule);
    _putStringIfNotBlank(payload, 'ruleSearchList', rules.searchListRule);
    _putStringIfNotBlank(payload, 'ruleSearchName', rules.searchTitleRule);
    _putStringIfNotBlank(
      payload,
      'ruleSearchBookUrl',
      rules.searchDetailUrlRule,
    );
    _putStringIfNotBlank(payload, 'ruleSearchAuthor', rules.searchAuthorRule);
    _putStringIfNotBlank(payload, 'ruleSearchIntro', rules.searchIntroRule);
    _putStringIfNotBlank(
      payload,
      'ruleSearchCoverUrl',
      rules.searchCoverUrlRule,
    );
    _putStringIfNotBlank(
      payload,
      'ruleSearchLastChapter',
      rules.searchLatestChapterRule,
    );

    _putStringIfNotBlank(payload, 'ruleBookInfo', rules.detailRule);
    _putStringIfNotBlank(payload, 'detailInitRule', rules.detailInitRule);
    _putStringIfNotBlank(payload, 'ruleBookName', rules.detailTitleRule);
    _putStringIfNotBlank(payload, 'ruleBookAuthor', rules.detailAuthorRule);
    _putStringIfNotBlank(payload, 'ruleBookIntro', rules.detailIntroRule);
    _putStringIfNotBlank(payload, 'ruleCoverUrl', rules.detailCoverUrlRule);
    _putStringIfNotBlank(payload, 'ruleTocUrl', rules.detailTocUrlRule);

    _putStringIfNotBlank(payload, 'ruleToc', rules.tocRule);
    _putStringIfNotBlank(payload, 'tocInitRule', rules.tocInitRule);
    _putStringIfNotBlank(payload, 'ruleChapterList', rules.tocListRule);
    _putStringIfNotBlank(payload, 'ruleChapterName', rules.tocTitleRule);
    _putStringIfNotBlank(payload, 'ruleChapterUrl', rules.tocChapterUrlRule);
    if (rules.tocReversed) {
      payload['reverseToc'] = true;
    }

    _putStringIfNotBlank(payload, 'ruleContent', rules.contentRule);
    _putStringIfNotBlank(payload, 'contentInitRule', rules.contentInitRule);
    _putStringIfNotBlank(
      payload,
      'contentDecryptRule',
      rules.contentDecryptRule,
    );

    final exploreUrl = source.exploreUrl?.trim();
    if (exploreUrl != null && exploreUrl.isNotEmpty) {
      payload['exploreUrl'] = exploreUrl;
      payload['enabledExplore'] = source.exploreEnabled;
    }
    _putStringIfNotBlank(payload, 'exploreInitRule', rules.exploreInitRule);
    _putStringIfNotBlank(payload, 'ruleExploreList', rules.exploreListRule);
    _putStringIfNotBlank(payload, 'ruleExploreName', rules.exploreTitleRule);
    _putStringIfNotBlank(
      payload,
      'ruleExploreBookUrl',
      rules.exploreDetailUrlRule,
    );
    _putStringIfNotBlank(payload, 'ruleExploreAuthor', rules.exploreAuthorRule);
    _putStringIfNotBlank(payload, 'ruleExploreIntro', rules.exploreIntroRule);
    _putStringIfNotBlank(
      payload,
      'ruleExploreCoverUrl',
      rules.exploreCoverUrlRule,
    );
    _putStringIfNotBlank(
      payload,
      'ruleExploreLastChapter',
      rules.exploreLatestChapterRule,
    );
    _putStringIfNotBlank(payload, 'ruleExploreKind', rules.exploreKindRule);
    _putStringIfNotBlank(
      payload,
      'ruleExploreWordCount',
      rules.exploreWordCountRule,
    );

    return payload;
  }

  void _putStringIfNotBlank(
    Map<String, dynamic> payload,
    String key,
    String? value,
  ) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    payload[key] = normalized;
  }

  Future<String?> _resolveSourceExportTargetPath(String suggestedName) async {
    try {
      final saveLocation = await getSaveLocation(
        suggestedName: suggestedName,
        confirmButtonText: '保存书源',
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'JSON',
            extensions: ['json'],
            uniformTypeIdentifiers: ['public.json'],
          ),
        ],
      );
      if (saveLocation == null) {
        return null;
      }
      return _normalizeJsonPath(saveLocation.path);
    } catch (_) {
      try {
        final directoryPath = await getDirectoryPath(
          confirmButtonText: '选择导出目录',
        );
        if (directoryPath == null || directoryPath.trim().isEmpty) {
          return null;
        }

        _showMessage('保存文件窗口不可用，已切换为目录选择。');
        return _joinPath(directoryPath.trim(), suggestedName);
      } catch (_) {
        final fallbackPath = await _buildFallbackExportPath(suggestedName);
        _showMessage('路径选择不可用，已导出到应用文稿目录。');
        return fallbackPath;
      }
    }
  }

  String _normalizeJsonPath(String rawPath) {
    final value = rawPath.trim();
    if (value.toLowerCase().endsWith('.json')) {
      return value;
    }
    return '$value.json';
  }

  Future<String> _buildFallbackExportPath(String fileName) async {
    final baseDirectory = await getApplicationDocumentsDirectory();
    final exportDirectory = Directory(
      _joinPath(baseDirectory.path, 'flutter_appread_exports'),
    );
    if (!await exportDirectory.exists()) {
      await exportDirectory.create(recursive: true);
    }
    return _joinPath(exportDirectory.path, fileName);
  }

  String _joinPath(String left, String right) {
    final separator = Platform.pathSeparator;
    if (left.endsWith(separator)) {
      return '$left$right';
    }
    return '$left$separator$right';
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

  String _timestampToken() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    return '$year$month$day-$hour$minute$second';
  }

  String _sanitizeFileToken(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    if (sanitized.isEmpty) {
      return 'source';
    }
    return sanitized;
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
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (pageContext) => const _PasteImportPage(),
      ),
    );
  }

  Future<String?> _showUrlImportPage() async {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (pageContext) => const _UrlImportPage(),
      ),
    );
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

class _PasteImportPage extends StatefulWidget {
  const _PasteImportPage();

  @override
  State<_PasteImportPage> createState() => _PasteImportPageState();
}

class _PasteImportPageState extends State<_PasteImportPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final maxWidth = AppLayout.pageContentMaxWidth(context, maxWidth: 920);
    final keyboardInset = AppLayout.keyboardInset(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final canSubmit = _controller.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('粘贴导入 JSON'),
        actions: [
          TextButton(
            onPressed: canSubmit ? _submit : null,
            child: const Text('导入'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  12,
                  horizontal,
                  12 + bottomSafe,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '粘贴书源 JSON 内容（对象或数组）',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: '{...} 或 [{...}]',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: canSubmit ? _submit : null,
                      icon: const Icon(Icons.file_download_rounded),
                      label: const Text('导入'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UrlImportPage extends StatefulWidget {
  const _UrlImportPage();

  @override
  State<_UrlImportPage> createState() => _UrlImportPageState();
}

class _UrlImportPageState extends State<_UrlImportPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final maxWidth = AppLayout.pageContentMaxWidth(context, maxWidth: 760);
    final keyboardInset = AppLayout.keyboardInset(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final canSubmit = _controller.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('链接导入书源'),
        actions: [
          TextButton(
            onPressed: canSubmit ? _submit : null,
            child: const Text('导入'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  12,
                  horizontal,
                  12 + bottomSafe,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '请输入书源 JSON 链接（http/https）',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) {
                        if (canSubmit) {
                          _submit();
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: 'https://example.com/source.json',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '支持直接粘贴链接，返回后会自动校验并开始导入。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: canSubmit ? _submit : null,
                      icon: const Icon(Icons.file_download_rounded),
                      label: const Text('导入'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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

enum _SourceAction { export, test, delete }

class _SourceGroupPickerResult {
  const _SourceGroupPickerResult({required this.group});

  final String? group;
}

class _SourceGroupPickerSheet extends StatefulWidget {
  const _SourceGroupPickerSheet({
    required this.availableGroups,
    required this.initialGroup,
  });

  final List<String> availableGroups;
  final String? initialGroup;

  @override
  State<_SourceGroupPickerSheet> createState() =>
      _SourceGroupPickerSheetState();
}

class _SourceGroupPickerSheetState extends State<_SourceGroupPickerSheet> {
  late final TextEditingController _controller;
  late final List<String> _groups;
  String? _selectedGroup;

  @override
  void initState() {
    super.initState();
    _selectedGroup = _normalizeGroup(widget.initialGroup);
    _groups = [...widget.availableGroups];
    _insertGroupIfMissing(_selectedGroup);
    _controller = TextEditingController();
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final canApplyInput = _controller.text.trim().isNotEmpty;
    final sectionStyle = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '选择分组',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '当前：${_displayGroup(_selectedGroup)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('新建分组', style: sectionStyle),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          hintText: '输入分组名称',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted:
                            (_) =>
                                canApplyInput
                                    ? _applyInputGroup()
                                    : FocusScope.of(context).unfocus(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: canApplyInput ? _applyInputGroup : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(72, 48),
                      ),
                      child: const Text('确认'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('快速选择', style: sectionStyle),
                const SizedBox(height: 8),
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildGroupOption(
                          context: context,
                          label: '未分组',
                          value: null,
                          icon: Icons.folder_off_rounded,
                        ),
                        if (_groups.isEmpty) ...[
                          const SizedBox(height: 8),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '暂无历史分组，可在上方创建。',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color:
                                                theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else
                          for (final group in _groups) ...[
                            const SizedBox(height: 8),
                            _buildGroupOption(
                              context: context,
                              label: group,
                              value: group,
                              icon: Icons.folder_rounded,
                            ),
                          ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _confirmSelection,
                        child: const Text('确定'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupOption({
    required BuildContext context,
    required String label,
    required String? value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final selected = _normalizeGroup(value) == _selectedGroup;
    final backgroundColor =
        selected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerLowest;
    final borderColor =
        selected
            ? theme.colorScheme.primary.withValues(alpha: 0.45)
            : theme.colorScheme.outlineVariant;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _selectedGroup = _normalizeGroup(value);
          });
          FocusScope.of(context).unfocus();
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color:
                      selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color:
                      selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _applyInputGroup() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    _insertGroupIfMissing(text);
    setState(() {
      _selectedGroup = text;
      _controller.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _confirmSelection() {
    Navigator.of(context).pop(_SourceGroupPickerResult(group: _selectedGroup));
  }

  void _insertGroupIfMissing(String? group) {
    final normalized = _normalizeGroup(group);
    if (normalized == null) {
      return;
    }
    final exists = _groups.any(
      (item) => item.toLowerCase() == normalized.toLowerCase(),
    );
    if (exists) {
      return;
    }
    _groups.add(normalized);
    _groups.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  String _displayGroup(String? group) {
    return _normalizeGroup(group) ?? '未分组';
  }

  String? _normalizeGroup(String? group) {
    final normalized = group?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

class _GroupFilterResult {
  const _GroupFilterResult({this.group, this.ungrouped = false});

  final String? group;
  final bool ungrouped;
}

class _SourceGroupFilterSheet extends StatelessWidget {
  const _SourceGroupFilterSheet({
    required this.availableGroups,
    required this.initialGroup,
    required this.initialUngrouped,
  });

  final List<String> availableGroups;
  final String? initialGroup;
  final bool initialUngrouped;

  static const String _kAllValue = '__group_filter_all__';
  static const String _kUngroupedValue = '__group_filter_ungrouped__';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedValue =
        initialUngrouped ? _kUngroupedValue : (initialGroup ?? _kAllValue);
    final tiles = <Widget>[
      const RadioListTile<String>(value: _kAllValue, title: Text('全部分组')),
      const RadioListTile<String>(value: _kUngroupedValue, title: Text('仅未分组')),
    ];

    if (availableGroups.isEmpty) {
      tiles.add(
        ListTile(
          enabled: false,
          leading: const Icon(Icons.info_outline_rounded),
          title: Text('暂无已命名分组', style: theme.textTheme.bodyMedium),
          subtitle: Text(
            '可以先在书源卡片上设置分组。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    } else {
      for (final group in availableGroups) {
        tiles.add(RadioListTile<String>(value: group, title: Text(group)));
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '按分组筛选',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '筛选特定分组或仅查看未分组书源。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.6,
              ),
              child: RadioGroup<String>(
                groupValue: selectedValue,
                onChanged: (value) {
                  if (value == _kAllValue) {
                    Navigator.of(context).pop(
                      const _GroupFilterResult(group: null, ungrouped: false),
                    );
                    return;
                  }
                  if (value == _kUngroupedValue) {
                    Navigator.of(context).pop(
                      const _GroupFilterResult(group: null, ungrouped: true),
                    );
                    return;
                  }
                  Navigator.of(
                    context,
                  ).pop(_GroupFilterResult(group: value, ungrouped: false));
                },
                child: ListView(shrinkWrap: true, children: tiles),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
