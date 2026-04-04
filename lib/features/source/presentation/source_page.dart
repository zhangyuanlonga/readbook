import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../domain/entities/script_source.dart';
import '../application/source_runtime_facade.dart';
import 'script_source_debug_page.dart';

enum _ScriptSourceSortOption { updatedDesc, nameAsc, nameDesc }

enum _SourcePageMenuAction { create, importLocal, importNetwork }

enum _SourceItemMenuAction { debug, delete }

class SourcePage extends StatefulWidget {
  const SourcePage({
    super.key,
    this.sourceRuntimeFacade,
    this.bootstrapOnInit = true,
    this.enableRouterNavigation = true,
  });

  final SourceRuntimeFacade? sourceRuntimeFacade;
  final bool bootstrapOnInit;
  final bool enableRouterNavigation;

  @override
  State<SourcePage> createState() => _SourcePageState();
}

class _SourcePageState extends State<SourcePage> {
  static const String _ungroupedGroupKey = '__ungrouped__';

  late final SourceRuntimeFacade _sourceRuntimeFacade;
  late final TextEditingController _searchController;

  String _searchQuery = '';
  String? _selectedGroupKey;
  _ScriptSourceSortOption _sortOption = _ScriptSourceSortOption.updatedDesc;

  final Set<String> _changingEnabledScriptSourceIds = <String>{};
  final Set<String> _deletingScriptSourceIds = <String>{};

  @override
  void initState() {
    super.initState();
    _sourceRuntimeFacade =
        widget.sourceRuntimeFacade ?? SourceRuntimeFacade.instance;
    _searchController = TextEditingController();
    if (widget.bootstrapOnInit) {
      unawaited(_reloadScriptSourcesSilently());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPopRoute =
        widget.enableRouterNavigation
            ? context.canPop()
            : Navigator.of(context).canPop();

    return PopScope<void>(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted) {
          return;
        }
        if (widget.enableRouterNavigation) {
          context.go('/mine');
        }
      },
      child: StreamBuilder<List<ScriptSource>>(
        stream: _sourceRuntimeFacade.watchScriptSources(),
        builder: (context, snapshot) {
          final rawSources = snapshot.data ?? const <ScriptSource>[];
          final visibleSources = _resolveVisibleSources(rawSources);
          final availableGroups = _collectGroupKeys(rawSources);

          if (_selectedGroupKey != null &&
              !_isCurrentGroupSelectionAvailable(
                selectedGroupKey: _selectedGroupKey,
                availableGroups: availableGroups,
                sources: rawSources,
              )) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              setState(() {
                _selectedGroupKey = null;
              });
            });
          }

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: _handleBackNavigation,
                tooltip: '返回',
                icon: const Icon(Icons.arrow_back),
              ),
              titleSpacing: 0,
              title: _buildSearchField(context),
              actions: [
                PopupMenuButton<_ScriptSourceSortOption>(
                  tooltip: '排序',
                  initialValue: _sortOption,
                  onSelected: (value) {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _sortOption = value;
                    });
                  },
                  itemBuilder:
                      (context) => const [
                        PopupMenuItem(
                          value: _ScriptSourceSortOption.updatedDesc,
                          child: Text('最近更新'),
                        ),
                        PopupMenuItem(
                          value: _ScriptSourceSortOption.nameAsc,
                          child: Text('名称 A-Z'),
                        ),
                        PopupMenuItem(
                          value: _ScriptSourceSortOption.nameDesc,
                          child: Text('名称 Z-A'),
                        ),
                      ],
                  icon: const Icon(Icons.swap_vert_rounded),
                ),
                PopupMenuButton<String?>(
                  tooltip: '分组',
                  initialValue: _selectedGroupKey,
                  onSelected: (value) {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _selectedGroupKey = value;
                    });
                  },
                  itemBuilder: (context) {
                    final items = <PopupMenuEntry<String?>>[
                      const PopupMenuItem<String?>(
                        value: null,
                        child: Text('全部'),
                      ),
                    ];
                    if (_hasUngrouped(rawSources)) {
                      items.add(
                        const PopupMenuItem<String?>(
                          value: _ungroupedGroupKey,
                          child: Text('未分组'),
                        ),
                      );
                    }
                    for (final group in availableGroups) {
                      items.add(
                        PopupMenuItem<String?>(
                          value: group,
                          child: Text(group),
                        ),
                      );
                    }
                    return items;
                  },
                  icon: const Icon(Icons.filter_list_rounded),
                ),
                PopupMenuButton<_SourcePageMenuAction>(
                  tooltip: '更多',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: _handlePageMenuAction,
                  itemBuilder:
                      (context) => const [
                        PopupMenuItem(
                          value: _SourcePageMenuAction.create,
                          child: Text('新增'),
                        ),
                        PopupMenuItem(
                          value: _SourcePageMenuAction.importLocal,
                          child: Text('本地导入'),
                        ),
                        PopupMenuItem(
                          value: _SourcePageMenuAction.importNetwork,
                          child: Text('网络导入'),
                        ),
                      ],
                ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: _buildBody(
                context,
                snapshot: snapshot,
                rawSources: rawSources,
                visibleSources: visibleSources,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required AsyncSnapshot<List<ScriptSource>> snapshot,
    required List<ScriptSource> rawSources,
    required List<ScriptSource> visibleSources,
  }) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final hasAnySource = rawSources.isNotEmpty;
    final hasFilter =
        _searchQuery.trim().isNotEmpty || _selectedGroupKey != null;

    if (snapshot.connectionState == ConnectionState.waiting && !hasAnySource) {
      return const Center(child: CircularProgressIndicator());
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppLayout.pageContentMaxWidth(
            context,
            maxWidth: AppLayout.searchContentMaxWidth,
          ),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            12,
            horizontal,
            12 + bottomSafe,
          ),
          children: [
            _buildFilterSummary(
              context,
              totalCount: rawSources.length,
              visibleCount: visibleSources.length,
            ),
            const SizedBox(height: 12),
            if (!hasAnySource)
              _buildEmptyStateCard(context)
            else if (visibleSources.isEmpty && hasFilter)
              _buildNoResultCard(context)
            else
              ...visibleSources.map(
                (source) => _buildSourceTile(context, source),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            if (!mounted) {
              return;
            }
            setState(() {
              _searchQuery = value;
            });
          },
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '搜索书源',
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon:
                _searchQuery.trim().isEmpty
                    ? null
                    : IconButton(
                      tooltip: '清空',
                      onPressed: () {
                        _searchController.clear();
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
            filled: true,
            fillColor: colorScheme.surfaceContainerLow,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.75),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSummary(
    BuildContext context, {
    required int totalCount,
    required int visibleCount,
  }) {
    final chips = <Widget>[
      _buildSummaryChip(context, '$visibleCount / $totalCount'),
    ];

    if (_selectedGroupKey != null) {
      chips.add(
        _buildSummaryChip(context, '分组：${_groupLabel(_selectedGroupKey)}'),
      );
    }
    if (_searchQuery.trim().isNotEmpty) {
      chips.add(_buildSummaryChip(context, '搜索：${_searchQuery.trim()}'));
    }
    if (_sortOption != _ScriptSourceSortOption.updatedDesc) {
      chips.add(_buildSummaryChip(context, '排序：${_sortLabel(_sortOption)}'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_searchQuery.trim().isNotEmpty || _selectedGroupKey != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _clearFilters,
              child: const Text('清空筛选'),
            ),
          ),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }

  Widget _buildSummaryChip(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard(BuildContext context) {
    return Card(
      shape: _buildOutlinedCardShape(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          children: [
            const Icon(Icons.javascript_rounded, size: 28),
            const SizedBox(height: 12),
            Text(
              '还没有书源',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '在右上角“更多”里新增书源，或等待导入入口接入后再导入。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultCard(BuildContext context) {
    return Card(
      shape: _buildOutlinedCardShape(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 28),
            const SizedBox(height: 10),
            Text(
              '没有匹配结果',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '试试修改关键词、切换分组，或清空当前筛选。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceTile(BuildContext context, ScriptSource source) {
    final isChangingEnabled = _changingEnabledScriptSourceIds.contains(
      source.id,
    );
    final isDeleting = _deletingScriptSourceIds.contains(source.id);
    final busy = isChangingEnabled || isDeleting;
    final subtitleParts = <String>[
      if (source.group?.trim().isNotEmpty == true)
        source.group!.trim()
      else
        '未分组',
      _formatDateTime(source.updatedAt),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: _buildOutlinedCardShape(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap:
                    busy
                        ? null
                        : () => unawaited(
                          _openScriptSourceEditorPage(source: source),
                        ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitleParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 56,
              child:
                  isChangingEnabled
                      ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                      : Switch.adaptive(
                        value: source.enabled,
                        onChanged:
                            busy
                                ? null
                                : (value) => unawaited(
                                  _setScriptSourceEnabled(source, value),
                                ),
                      ),
            ),
            IconButton(
              tooltip: '编辑',
              onPressed:
                  busy
                      ? null
                      : () => unawaited(
                        _openScriptSourceEditorPage(source: source),
                      ),
              icon: const Icon(Icons.edit_outlined),
            ),
            PopupMenuButton<_SourceItemMenuAction>(
              tooltip: '更多',
              icon: const Icon(Icons.more_vert_rounded),
              enabled: !busy,
              onSelected:
                  (action) => _handleSourceItemMenuAction(source, action),
              itemBuilder:
                  (context) => const [
                    PopupMenuItem(
                      value: _SourceItemMenuAction.debug,
                      child: Text('调试'),
                    ),
                    PopupMenuItem(
                      value: _SourceItemMenuAction.delete,
                      child: Text('删除'),
                    ),
                  ],
            ),
            if (isDeleting)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleBackNavigation() {
    if (widget.enableRouterNavigation && context.canPop()) {
      context.pop();
      return;
    }
    if (widget.enableRouterNavigation) {
      context.go('/mine');
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _handlePageMenuAction(_SourcePageMenuAction action) {
    switch (action) {
      case _SourcePageMenuAction.create:
        unawaited(_openScriptSourceEditorPage());
        break;
      case _SourcePageMenuAction.importLocal:
        _showMessage('本地导入入口还未接入这一版列表页。');
        break;
      case _SourcePageMenuAction.importNetwork:
        _showMessage('网络导入入口还未接入这一版列表页。');
        break;
    }
  }

  void _handleSourceItemMenuAction(
    ScriptSource source,
    _SourceItemMenuAction action,
  ) {
    switch (action) {
      case _SourceItemMenuAction.debug:
        unawaited(_openDebugPage(source));
        break;
      case _SourceItemMenuAction.delete:
        unawaited(_deleteScriptSource(source));
        break;
    }
  }

  List<ScriptSource> _resolveVisibleSources(List<ScriptSource> sources) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered =
        sources.where((source) {
          if (_selectedGroupKey != null) {
            final sourceGroupKey = _groupKeyOf(source);
            if (sourceGroupKey != _selectedGroupKey) {
              return false;
            }
          }

          if (query.isEmpty) {
            return true;
          }

          final values = <String>[
            source.name,
            source.group ?? '',
            source.author ?? '',
            source.description ?? '',
          ];
          return values.any((value) => value.toLowerCase().contains(query));
        }).toList();

    filtered.sort((a, b) {
      switch (_sortOption) {
        case _ScriptSourceSortOption.updatedDesc:
          return b.updatedAt.compareTo(a.updatedAt);
        case _ScriptSourceSortOption.nameAsc:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _ScriptSourceSortOption.nameDesc:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
      }
    });

    return filtered;
  }

  List<String> _collectGroupKeys(List<ScriptSource> sources) {
    final groups =
        sources
            .map((source) => source.group?.trim() ?? '')
            .where((group) => group.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return groups;
  }

  bool _hasUngrouped(List<ScriptSource> sources) {
    return sources.any((source) => _groupKeyOf(source) == _ungroupedGroupKey);
  }

  bool _isCurrentGroupSelectionAvailable({
    required String? selectedGroupKey,
    required List<String> availableGroups,
    required List<ScriptSource> sources,
  }) {
    if (selectedGroupKey == null) {
      return true;
    }
    if (selectedGroupKey == _ungroupedGroupKey) {
      return _hasUngrouped(sources);
    }
    return availableGroups.contains(selectedGroupKey);
  }

  String _groupKeyOf(ScriptSource source) {
    final group = source.group?.trim() ?? '';
    return group.isEmpty ? _ungroupedGroupKey : group;
  }

  String _groupLabel(String? groupKey) {
    if (groupKey == null) {
      return '全部';
    }
    if (groupKey == _ungroupedGroupKey) {
      return '未分组';
    }
    return groupKey;
  }

  String _sortLabel(_ScriptSourceSortOption option) {
    return switch (option) {
      _ScriptSourceSortOption.updatedDesc => '最近更新',
      _ScriptSourceSortOption.nameAsc => '名称 A-Z',
      _ScriptSourceSortOption.nameDesc => '名称 Z-A',
    };
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedGroupKey = null;
    });
  }

  Future<void> _reloadScriptSourcesSilently() async {
    try {
      await _sourceRuntimeFacade.reloadScriptSources();
    } catch (_) {
      // Ignore bootstrap failures here and surface them on manual actions.
    }
  }

  Future<void> _openScriptSourceEditorPage({ScriptSource? source}) async {
    final queryParameters = <String, String>{
      if (source != null) 'id': source.id,
    };
    final result = await context.push<String>(
      Uri(
        path: '/source/script-editor',
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
      ).toString(),
    );
    if (!mounted || result == null || result.trim().isEmpty) {
      return;
    }
    _showMessage(result);
  }

  Future<void> _openDebugPage(ScriptSource source) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => ScriptSourceDebugPage(
              sourceCode: source.sourceCode,
              title: '${source.name} 调试',
            ),
      ),
    );
  }

  Future<void> _setScriptSourceEnabled(
    ScriptSource source,
    bool enabled,
  ) async {
    setState(() {
      _changingEnabledScriptSourceIds.add(source.id);
    });
    try {
      await _sourceRuntimeFacade.setScriptSourceEnabled(
        id: source.id,
        enabled: enabled,
      );
    } catch (error) {
      if (mounted) {
        _showMessage('更新书源状态失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _changingEnabledScriptSourceIds.remove(source.id);
        });
      }
    }
  }

  Future<void> _deleteScriptSource(ScriptSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除书源'),
          content: Text('确认删除「${source.name}」吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _deletingScriptSourceIds.add(source.id);
    });
    try {
      await _sourceRuntimeFacade.deleteScriptSource(source.id);
      if (mounted) {
        _showMessage('书源已删除。');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('删除书源失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingScriptSourceIds.remove(source.id);
        });
      }
    }
  }

  RoundedRectangleBorder _buildOutlinedCardShape(BuildContext context) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int input) => input.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}
