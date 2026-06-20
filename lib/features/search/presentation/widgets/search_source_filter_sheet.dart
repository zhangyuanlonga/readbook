import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/layout/app_adaptive.dart';
import '../../../../app/widgets/foundation/foundation.dart';
import '../../application/search_models.dart';
import '../../application/server_online_search_service.dart';

typedef SearchSourcePageLoader =
    Future<ServerSearchSourcePage> Function({
      required SearchContentMode contentMode,
      int page,
      int pageSize,
      String? keyword,
    });

typedef SearchSourceGroupLoader =
    Future<ServerSearchSourceGroupPage> Function({
      required SearchContentMode contentMode,
      int page,
      int pageSize,
      String? keyword,
    });

class SearchSourceFilterSheet extends StatefulWidget {
  const SearchSourceFilterSheet({
    super.key,
    required this.loadSourcePage,
    required this.loadSourceGroups,
    required this.contentMode,
    required this.initialSelection,
    this.pageSize = 60,
  });

  final SearchSourcePageLoader loadSourcePage;
  final SearchSourceGroupLoader loadSourceGroups;
  final SearchContentMode contentMode;
  final SearchSourceSelection initialSelection;
  final int pageSize;

  @override
  State<SearchSourceFilterSheet> createState() =>
      _SearchSourceFilterSheetState();
}

class _SearchSourceFilterSheetState extends State<SearchSourceFilterSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _filterController = TextEditingController();
  final ScrollController _groupScrollController = ScrollController();
  final ScrollController _sourceScrollController = ScrollController();
  List<ServerSearchSourceGroupSummary> _groups =
      const <ServerSearchSourceGroupSummary>[];
  List<ServerSearchSourceSummary> _sources =
      const <ServerSearchSourceSummary>[];
  late Set<String> _draftGroupNames;
  late Set<String> _draftSourceIds;
  bool _isLoadingGroups = false;
  bool _isLoadingMoreGroups = false;
  bool _isLoadingInitialSources = false;
  bool _isLoadingMoreSources = false;
  bool _hasLoadedGroups = false;
  bool _hasLoadedSources = false;
  bool _hasMoreGroups = true;
  bool _hasMoreSources = true;
  int _groupPage = 0;
  int _groupTotal = 0;
  int _sourcePage = 0;
  int _sourceTotal = 0;
  String _filterKeyword = '';
  String? _groupErrorText;
  String? _sourceErrorText;
  Timer? _filterDebounceTimer;
  int _groupLoadGeneration = 0;
  int _sourceLoadGeneration = 0;

  bool get _allSourcesSelected =>
      _draftGroupNames.isEmpty && _draftSourceIds.isEmpty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _draftGroupNames = Set<String>.of(widget.initialSelection.groupNames);
    _draftSourceIds = widget.initialSelection.effectiveSourceIds;
    _groupScrollController.addListener(_maybeLoadMoreGroups);
    _sourceScrollController.addListener(_maybeLoadMoreSources);
    unawaited(_ensureActiveTabLoaded());
  }

  @override
  void dispose() {
    _filterDebounceTimer?.cancel();
    _tabController.dispose();
    _groupScrollController.dispose();
    _sourceScrollController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _reloadGroups() async {
    final generation = ++_groupLoadGeneration;
    setState(() {
      _isLoadingGroups = true;
      _isLoadingMoreGroups = false;
      _hasLoadedGroups = true;
      _hasMoreGroups = true;
      _groupPage = 0;
      _groupTotal = 0;
      _groups = const <ServerSearchSourceGroupSummary>[];
      _groupErrorText = null;
    });
    await _loadGroupPage(page: 1, generation: generation, reset: true);
  }

  Future<void> _loadMoreGroups() async {
    if (_isLoadingGroups || _isLoadingMoreGroups || !_hasMoreGroups) {
      return;
    }
    await _loadGroupPage(
      page: _groupPage + 1,
      generation: _groupLoadGeneration,
      reset: false,
    );
  }

  Future<void> _loadGroupPage({
    required int page,
    required int generation,
    required bool reset,
  }) async {
    if (!reset) {
      setState(() {
        _isLoadingMoreGroups = true;
        _groupErrorText = null;
      });
    }
    try {
      final groupPage = await widget.loadSourceGroups(
        contentMode: widget.contentMode,
        page: page,
        pageSize: 50,
        keyword: _filterKeyword,
      );
      if (!mounted || generation != _groupLoadGeneration) return;
      final nextGroups =
          reset
              ? groupPage.items
              : _mergeGroupSummaries(_groups, groupPage.items);
      setState(() {
        _groups = nextGroups;
        _groupPage = groupPage.page;
        _groupTotal = groupPage.total;
        _hasMoreGroups = groupPage.hasMore;
      });
    } catch (error) {
      if (!mounted || generation != _groupLoadGeneration) return;
      setState(() {
        _groupErrorText = '分组加载失败：$error';
      });
    } finally {
      if (mounted && generation == _groupLoadGeneration) {
        setState(() {
          _isLoadingGroups = false;
          _isLoadingMoreGroups = false;
        });
      }
    }
  }

  Future<void> _reloadSources() async {
    final generation = ++_sourceLoadGeneration;
    setState(() {
      _isLoadingInitialSources = true;
      _isLoadingMoreSources = false;
      _hasLoadedSources = true;
      _hasMoreSources = true;
      _sourcePage = 0;
      _sourceTotal = 0;
      _sources = const <ServerSearchSourceSummary>[];
      _sourceErrorText = null;
    });
    await _loadSourcePage(page: 1, generation: generation, reset: true);
  }

  Future<void> _loadMoreSources() async {
    if (_isLoadingInitialSources || _isLoadingMoreSources || !_hasMoreSources) {
      return;
    }
    await _loadSourcePage(
      page: _sourcePage + 1,
      generation: _sourceLoadGeneration,
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
        _isLoadingMoreSources = true;
        _sourceErrorText = null;
      });
    }
    try {
      final sourcePage = await widget.loadSourcePage(
        contentMode: widget.contentMode,
        page: page,
        pageSize: widget.pageSize,
        keyword: _filterKeyword,
      );
      if (!mounted || generation != _sourceLoadGeneration) return;
      final nextSources =
          reset
              ? sourcePage.items
              : _mergeSourceSummaries(_sources, sourcePage.items);
      setState(() {
        _sources = nextSources;
        _sourcePage = sourcePage.page;
        _sourceTotal = sourcePage.total;
        _hasMoreSources = sourcePage.hasMore;
      });
    } catch (error) {
      if (!mounted || generation != _sourceLoadGeneration) return;
      setState(() {
        _sourceErrorText = '书源加载失败：$error';
      });
    } finally {
      if (mounted && generation == _sourceLoadGeneration) {
        setState(() {
          _isLoadingInitialSources = false;
          _isLoadingMoreSources = false;
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

  List<ServerSearchSourceGroupSummary> _mergeGroupSummaries(
    List<ServerSearchSourceGroupSummary> current,
    List<ServerSearchSourceGroupSummary> next,
  ) {
    if (next.isEmpty) return current;
    final seen = current.map((group) => group.name).toSet();
    final merged = <ServerSearchSourceGroupSummary>[...current];
    for (final group in next) {
      if (seen.add(group.name)) {
        merged.add(group);
      }
    }
    return merged;
  }

  void _maybeLoadMoreGroups() {
    if (!_groupScrollController.hasClients) {
      return;
    }
    if (_groupScrollController.position.extentAfter < 420) {
      unawaited(_loadMoreGroups());
    }
  }

  void _maybeLoadMoreSources() {
    if (!_sourceScrollController.hasClients) {
      return;
    }
    if (_sourceScrollController.position.extentAfter < 420) {
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
      setState(() {
        _hasLoadedGroups = false;
        _hasLoadedSources = false;
        _groups = const <ServerSearchSourceGroupSummary>[];
        _sources = const <ServerSearchSourceSummary>[];
      });
      unawaited(_ensureActiveTabLoaded(force: true));
    });
  }

  Future<void> _ensureActiveTabLoaded({bool force = false}) async {
    if (_tabController.index == 0) {
      if (force || !_hasLoadedGroups) {
        await _reloadGroups();
      }
      return;
    }
    if (force || !_hasLoadedSources) {
      await _reloadSources();
    }
  }

  SearchSourceSelection _resultSelection() {
    if (_allSourcesSelected) {
      return SearchSourceSelection.all;
    }
    return SearchSourceSelection(
      groupNames: Set<String>.of(_draftGroupNames),
      sourceIds: Set<String>.of(_draftSourceIds),
    );
  }

  void _toggleGroup(String name, bool selected) {
    setState(() {
      _draftSourceIds.clear();
      if (selected) {
        _draftGroupNames.add(name);
      } else {
        _draftGroupNames.remove(name);
      }
    });
  }

  void _toggleSource(String id, bool selected) {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      return;
    }
    setState(() {
      _draftGroupNames.clear();
      if (selected) {
        _draftSourceIds.add(normalizedId);
      } else {
        _draftSourceIds.remove(normalizedId);
      }
    });
  }

  String get _selectionLabel {
    if (_allSourcesSelected) {
      return '搜索全部书源';
    }
    if (_draftSourceIds.isNotEmpty) {
      return '搜索已选 ${_draftSourceIds.length} 个书源';
    }
    return '搜索已选 ${_draftGroupNames.length} 个分组';
  }

  String get _countLabel {
    if (_tabController.index == 0) {
      if (_isLoadingGroups && _groups.isEmpty) return '加载中';
      return _groupTotal == 0 ? '暂无分组' : '已加载 ${_groups.length}/$_groupTotal';
    }
    if (_isLoadingInitialSources && _sourceTotal == 0) return '加载中';
    if (_sourceTotal == 0) return '暂无书源';
    return '已加载 ${_sources.length}/$_sourceTotal';
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
                      '搜索范围',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _tabController,
                    builder:
                        (context, _) => _SearchSourceCountPill(
                          label: _countLabel,
                          loading:
                              (_tabController.index == 0 &&
                                  _isLoadingGroups &&
                                  _groups.isEmpty) ||
                              (_tabController.index == 1 &&
                                  _isLoadingInitialSources &&
                                  _sourceTotal == 0),
                        ),
                  ),
                ],
              ),
              SizedBox(height: metrics.contentGap),
              TextField(
                controller: _filterController,
                onChanged: _onFilterChanged,
                decoration: InputDecoration(
                  hintText:
                      _tabController.index == 0 ? '搜索分组名称' : '搜索书源名称、URL或标签',
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
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: theme.colorScheme.onPrimaryContainer,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  indicator: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tabs: const [Tab(text: '分组'), Tab(text: '书源')],
                  onTap: (_) {
                    setState(() {});
                    unawaited(_ensureActiveTabLoaded());
                  },
                ),
              ),
              SizedBox(height: metrics.contentGap),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGroupPane(context),
                    _buildSourcePane(context),
                  ],
                ),
              ),
              SizedBox(height: metrics.contentGap),
              _SearchSourcePickerActions(
                selectionLabel: _selectionLabel,
                canApply:
                    _allSourcesSelected ||
                    _draftGroupNames.isNotEmpty ||
                    _draftSourceIds.isNotEmpty,
                onCancel: () => Navigator.of(context).pop(),
                onApply: () => Navigator.of(context).pop(_resultSelection()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupPane(BuildContext context) {
    final theme = Theme.of(context);
    if (_groupErrorText != null && _groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _groupErrorText!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }
    if (_isLoadingGroups && _groups.isEmpty) {
      return const Center(
        child: AppProgressIndicator(strokeWidth: 2, semanticLabel: '加载书源分组'),
      );
    }
    return _SearchPanelFrame(
      child: ListView.builder(
        controller: _groupScrollController,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _groups.length + 1,
        itemBuilder: (context, index) {
          final groupIndex = index;
          if (groupIndex >= _groups.length) {
            if (_isLoadingGroups || _isLoadingMoreGroups) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: AppProgressIndicator(
                    size: 20,
                    strokeWidth: 2,
                    semanticLabel: '加载更多分组',
                  ),
                ),
              );
            }
            if (_groups.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    _filterKeyword.isEmpty ? '暂无分组' : '没有匹配的分组',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              );
            }
            if (!_hasMoreGroups) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    '已加载全部分组',
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
          final group = _groups[groupIndex];
          return _SearchGroupTile(
            key: ValueKey<String>('search_source_group_${group.name.trim()}'),
            group: group,
            selected: _draftGroupNames.contains(group.name),
            onChanged: (value) => _toggleGroup(group.name, value == true),
          );
        },
      ),
    );
  }

  Widget _buildSourcePane(BuildContext context) {
    final theme = Theme.of(context);
    if (_sourceErrorText != null && _sources.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _sourceErrorText!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }
    return _SearchPanelFrame(
      child: ListView.builder(
        controller: _sourceScrollController,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _sources.length + 1,
        itemBuilder: _buildSourceListItem,
      ),
    );
  }

  Widget _buildSourceListItem(BuildContext context, int index) {
    final theme = Theme.of(context);
    final sourceIndex = index;
    if (sourceIndex >= _sources.length) {
      if (_isLoadingInitialSources || _isLoadingMoreSources) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: AppProgressIndicator(
              size: 20,
              strokeWidth: 2,
              semanticLabel: '加载更多书源',
            ),
          ),
        );
      }
      if (_sources.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              _filterKeyword.isEmpty ? '暂无书源' : '没有匹配的书源',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        );
      }
      if (!_hasMoreSources) {
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

    final source = _sources[sourceIndex];
    return _SearchSourceTile(
      key: ValueKey<String>('search_source_${source.id}'),
      source: source,
      selected: _draftSourceIds.contains(source.id),
      onChanged: (value) => _toggleSource(source.id, value == true),
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

class _SearchPanelFrame extends StatelessWidget {
  const _SearchPanelFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(color: Colors.transparent, child: child);
  }
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
              const AppProgressIndicator(
                size: 13,
                strokeWidth: 2,
                semanticLabel: '刷新数量',
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

class _SearchGroupTile extends StatelessWidget {
  const _SearchGroupTile({
    super.key,
    required this.group,
    required this.selected,
    required this.onChanged,
  });

  final ServerSearchSourceGroupSummary group;
  final bool selected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return _SearchScopeRowShell(
      selected: selected,
      onTap: () => onChanged(!selected),
      leading: AppSelectionIndicator(
        selected: selected,
        semanticLabel: selected ? '已选择分组' : '未选择分组',
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              group.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              child: Text(
                group.countLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchSourceTile extends StatelessWidget {
  const _SearchSourceTile({
    super.key,
    required this.source,
    required this.selected,
    required this.onChanged,
  });

  final ServerSearchSourceSummary source;
  final bool selected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return _SearchScopeRowShell(
      selected: selected,
      onTap: () => onChanged(!selected),
      leading: AppSelectionIndicator(
        selected: selected,
        semanticLabel: selected ? '已选择书源' : '未选择书源',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            source.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            searchSourceMetaLabel(source),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchScopeRowShell extends StatelessWidget {
  const _SearchScopeRowShell({
    required this.selected,
    required this.onTap,
    required this.leading,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget leading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color:
                selected
                    ? colorScheme.primaryContainer.withValues(alpha: 0.32)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SizedBox(width: 42, child: Center(child: leading)),
              const SizedBox(width: 8),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

String searchSourceMetaLabel(ServerSearchSourceSummary source) {
  final parts = <String>[
    searchSourceScopeLabel(source),
    searchSourceHealthLabel(source.healthStatus).ifEmpty('未检测'),
    if ((source.group ?? '').trim().isNotEmpty) (source.group ?? '').trim(),
  ];
  return parts.join(' · ');
}

extension _SearchSourceStringFallback on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
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
            child: AppButton(
              variant: AppButtonVariant.secondary,
              expanded: true,
              onPressed: onCancel,
              label: '取消',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppButton(
              expanded: true,
              onPressed: canApply ? onApply : null,
              label: selectionLabel,
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        AppButton(
          variant: AppButtonVariant.text,
          onPressed: onCancel,
          label: '取消',
        ),
        const SizedBox(width: 8),
        AppButton(onPressed: canApply ? onApply : null, label: selectionLabel),
      ],
    );
  }
}
