import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/layout/app_adaptive.dart';
import '../../application/search_models.dart';
import '../../application/server_online_search_service.dart';

typedef SearchSourcePageLoader =
    Future<ServerSearchSourcePage> Function({
      required SearchContentMode contentMode,
      int page,
      int pageSize,
      String? keyword,
    });

class SearchSourceFilterSheet extends StatefulWidget {
  const SearchSourceFilterSheet({
    super.key,
    required this.loadSourcePage,
    required this.contentMode,
    required this.initialSelectedIds,
    this.pageSize = 60,
  });

  final SearchSourcePageLoader loadSourcePage;
  final SearchContentMode contentMode;
  final Set<String> initialSelectedIds;
  final int pageSize;

  @override
  State<SearchSourceFilterSheet> createState() =>
      _SearchSourceFilterSheetState();
}

class _SearchSourceFilterSheetState extends State<SearchSourceFilterSheet> {
  final TextEditingController _filterController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ServerSearchSourceSummary> _sources =
      const <ServerSearchSourceSummary>[];
  late Set<String> _draftSelectedIds;
  bool _allSourcesSelected = true;
  bool _isLoadingInitial = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  int _total = 0;
  String _filterKeyword = '';
  String? _errorText;
  Timer? _filterDebounceTimer;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _draftSelectedIds = Set<String>.of(widget.initialSelectedIds);
    _allSourcesSelected = widget.initialSelectedIds.isEmpty;
    _scrollController.addListener(_maybeLoadMore);
    unawaited(_reloadSources());
  }

  @override
  void dispose() {
    _filterDebounceTimer?.cancel();
    _scrollController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _reloadSources() async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoadingInitial = true;
      _isLoadingMore = false;
      _hasMore = true;
      _page = 0;
      _total = 0;
      _sources = const <ServerSearchSourceSummary>[];
      _errorText = null;
    });

    await _loadSourcePage(page: 1, generation: generation, reset: true);
  }

  Future<void> _loadMoreSources() async {
    if (_isLoadingInitial || _isLoadingMore || !_hasMore) {
      return;
    }
    await _loadSourcePage(
      page: _page + 1,
      generation: _loadGeneration,
      reset: false,
    );
  }

  Future<void> _loadSourcePage({
    required int page,
    required int generation,
    required bool reset,
  }) async {
    if (!reset) {
      setState(() {
        _isLoadingMore = true;
        _errorText = null;
      });
    }
    try {
      final sourcePage = await widget.loadSourcePage(
        contentMode: widget.contentMode,
        page: page,
        pageSize: widget.pageSize,
        keyword: _filterKeyword,
      );
      if (!mounted || generation != _loadGeneration) return;
      final nextSources =
          reset
              ? sourcePage.items
              : _mergeSourceSummaries(_sources, sourcePage.items);
      setState(() {
        _sources = nextSources;
        _page = sourcePage.page;
        _total = sourcePage.total;
        _hasMore = sourcePage.hasMore;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _errorText = '可用书源加载失败：$error';
      });
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _isLoadingInitial = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  List<ServerSearchSourceSummary> _mergeSourceSummaries(
    List<ServerSearchSourceSummary> current,
    List<ServerSearchSourceSummary> next,
  ) {
    if (next.isEmpty) return current;
    final seen = current.map((source) => source.id).toSet();
    final merged = <ServerSearchSourceSummary>[...current];
    for (final source in next) {
      if (seen.add(source.id)) {
        merged.add(source);
      }
    }
    return merged;
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.extentAfter < 420) {
      unawaited(_loadMoreSources());
    }
  }

  void _onFilterChanged(String value) {
    _filterDebounceTimer?.cancel();
    _filterDebounceTimer = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      final nextKeyword = value.trim();
      if (nextKeyword == _filterKeyword) {
        return;
      }
      _filterKeyword = nextKeyword;
      unawaited(_reloadSources());
    });
  }

  Set<String> _resultSelection() {
    if (_allSourcesSelected) {
      return <String>{};
    }
    return Set<String>.of(_draftSelectedIds);
  }

  void _toggleItem(String id, bool selected) {
    setState(() {
      if (_allSourcesSelected) {
        _allSourcesSelected = false;
        _draftSelectedIds.clear();
      }
      if (selected) {
        _draftSelectedIds.add(id);
      } else {
        _draftSelectedIds.remove(id);
      }
      if (_draftSelectedIds.isEmpty) {
        _allSourcesSelected = true;
      }
    });
  }

  String get _selectionLabel {
    if (_allSourcesSelected) {
      return _total > 0 ? '搜索全部可用书源' : '暂无可用书源';
    }
    return '搜索已选 ${_draftSelectedIds.length} 个书源';
  }

  Widget _buildSourceListItem(BuildContext context, int index) {
    final theme = Theme.of(context);
    if (index == 0) {
      return _SearchSourceAllTile(
        total: _total,
        selected: _allSourcesSelected,
        onChanged: (value) {
          setState(() {
            _allSourcesSelected = value != false;
            if (_allSourcesSelected) {
              _draftSelectedIds.clear();
            }
          });
        },
      );
    }

    final groupIndex = index - 1;
    if (groupIndex >= _sources.length) {
      if (_isLoadingInitial || _isLoadingMore) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      if (_sources.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              _filterKeyword.isEmpty ? '暂无可用书源' : '没有匹配的书源或分组',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        );
      }
      if (!_hasMore) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              '已加载全部书源',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
      return const SizedBox(height: 8);
    }

    final source = _sources[groupIndex];
    return _SearchSourceTile(
      source: source,
      allSourcesSelected: _allSourcesSelected,
      selected: !_allSourcesSelected && _draftSelectedIds.contains(source.id),
      onChanged: (value) => _toggleItem(source.id, value == true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = AppAdaptiveMetrics.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          metrics.pagePadding,
          metrics.contentGap,
          metrics.pagePadding,
          metrics.sectionGap,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '选择搜索范围',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _SearchSourceCountPill(
                    label:
                        _isLoadingInitial && _total == 0
                            ? '加载中'
                            : _total > 0
                            ? '已加载 ${_sources.length}/$_total'
                            : '暂无可用',
                    loading: _isLoadingInitial && _total == 0,
                  ),
                ],
              ),
              SizedBox(height: metrics.contentGap),
              TextField(
                controller: _filterController,
                onChanged: _onFilterChanged,
                decoration: InputDecoration(
                  hintText: '搜索书源或分组',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon:
                      _filterController.text.isEmpty
                          ? null
                          : IconButton(
                            tooltip: '清空筛选',
                            onPressed: () {
                              _filterController.clear();
                              _onFilterChanged('');
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              SizedBox(height: metrics.contentGap),
              _SearchSourceSelectionSummary(
                allSourcesSelected: _allSourcesSelected,
                selectedCount: _draftSelectedIds.length,
                total: _total,
                onSelectAll:
                    _allSourcesSelected
                        ? null
                        : () {
                          setState(() {
                            _allSourcesSelected = true;
                            _draftSelectedIds.clear();
                          });
                        },
              ),
              SizedBox(height: metrics.contentGap),
              Expanded(
                child:
                    _errorText != null && _sources.isEmpty
                        ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _errorText!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        )
                        : DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow
                                .withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.36),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: _sources.length + 2,
                              itemBuilder: _buildSourceListItem,
                            ),
                          ),
                        ),
              ),
              SizedBox(height: metrics.contentGap),
              _SearchSourcePickerActions(
                selectionLabel: _selectionLabel,
                canApply: _allSourcesSelected || _draftSelectedIds.isNotEmpty,
                onCancel: () => Navigator.of(context).pop(),
                onApply: () => Navigator.of(context).pop(_resultSelection()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchSourceStatusChip extends StatelessWidget {
  const SearchSourceStatusChip({super.key, required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final label = searchSourceHealthLabel(status);
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final isFailed = label == '检测失败' || label == '配置异常';
    final background =
        isFailed
            ? colorScheme.errorContainer
            : colorScheme.surfaceContainerHigh;
    final foreground =
        isFailed ? colorScheme.onErrorContainer : colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          '【$label】',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class SearchSourceScopeChip extends StatelessWidget {
  const SearchSourceScopeChip({super.key, required this.source});

  final ServerSearchSourceSummary source;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scope = searchSourceScopeLabel(source);
    final isPrivate = scope == '私人';
    final background =
        isPrivate
            ? colorScheme.tertiaryContainer
            : colorScheme.secondaryContainer;
    final foreground =
        isPrivate
            ? colorScheme.onTertiaryContainer
            : colorScheme.onSecondaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          '【$scope】',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

String searchSourceScopeLabel(ServerSearchSourceSummary source) {
  final raw =
      (source.sourceType ?? source.visibility ?? '').trim().toLowerCase();
  return switch (raw) {
    'private' || 'mine' => '私人',
    'submitted' => '投稿',
    _ => '共享',
  };
}

String searchSourceHealthLabel(String? status) {
  final normalized = (status ?? '').trim().replaceAll('_', '').toLowerCase();
  return switch (normalized) {
    'passed' => '检测通过',
    'failed' => '检测失败',
    'unknown' || 'pending' => '未检测',
    'normalizationfailed' || 'normalizefailed' => '配置异常',
    'coolingdown' => '冷却中',
    'ignored' => '已忽略',
    _ => '',
  };
}

class _SearchSourceCountPill extends StatelessWidget {
  const _SearchSourceCountPill({required this.label, required this.loading});

  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (loading) ...<Widget>[
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSourceSelectionSummary extends StatelessWidget {
  const _SearchSourceSelectionSummary({
    required this.allSourcesSelected,
    required this.selectedCount,
    required this.total,
    required this.onSelectAll,
  });

  final bool allSourcesSelected;
  final int selectedCount;
  final int total;
  final VoidCallback? onSelectAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            allSourcesSelected ? '当前搜索全部可用书源' : '已选 $selectedCount / $total',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onSelectAll,
          icon: const Icon(Icons.done_all_rounded, size: 18),
          label: const Text('全部书源'),
        ),
      ],
    );
  }
}

class _SearchSourceAllTile extends StatelessWidget {
  const _SearchSourceAllTile({
    required this.total,
    required this.selected,
    required this.onChanged,
  });

  final int total;
  final bool selected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: selected,
      title: Text(total > 0 ? '全部可用书源 ($total)' : '全部可用书源'),
      subtitle: const Text('不指定时默认搜索全部可用书源'),
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: onChanged,
    );
  }
}

class _SearchSourceTile extends StatelessWidget {
  const _SearchSourceTile({
    required this.source,
    required this.allSourcesSelected,
    required this.selected,
    required this.onChanged,
  });

  final ServerSearchSourceSummary source;
  final bool allSourcesSelected;
  final bool selected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final group = (source.group ?? '').trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!selected),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color:
                  selected
                      ? colorScheme.primaryContainer.withValues(alpha: 0.34)
                      : colorScheme.surfaceContainerLowest.withValues(
                        alpha: 0.38,
                      ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    selected
                        ? colorScheme.primary.withValues(alpha: 0.34)
                        : colorScheme.outlineVariant.withValues(alpha: 0.28),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: <Widget>[
                  Checkbox(
                    value: !allSourcesSelected && selected,
                    onChanged: onChanged,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                source.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SearchSourceScopeChip(source: source),
                            const SizedBox(width: 6),
                            SearchSourceStatusChip(status: source.healthStatus),
                          ],
                        ),
                        if (group.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            '分组：$group',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }
}

class _SearchSourcePickerActions extends StatelessWidget {
  const _SearchSourcePickerActions({
    required this.selectionLabel,
    required this.canApply,
    required this.onCancel,
    required this.onApply,
  });

  final String selectionLabel;
  final bool canApply;
  final VoidCallback onCancel;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    if (metrics.isCompactWindow) {
      return Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton(onPressed: onCancel, child: const Text('取消')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: canApply ? onApply : null,
              child: Text(selectionLabel),
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        TextButton(onPressed: onCancel, child: const Text('取消')),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: canApply ? onApply : null,
          child: Text(selectionLabel),
        ),
      ],
    );
  }
}
