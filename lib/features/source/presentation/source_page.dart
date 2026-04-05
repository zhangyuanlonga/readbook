import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../domain/entities/script_source.dart';
import '../../../domain/entities/source_health.dart';
import '../application/external_source_import_bridge.dart';
import '../application/source_health_action_policy_service.dart';
import '../application/source_check_service.dart';
import '../application/source_health_service.dart';
import '../application/source_runtime_facade.dart';
import 'script_source_debug_page.dart';

enum _ScriptSourceSortOption { updatedDesc, nameAsc, nameDesc }

enum _SourcePageMenuAction {
  create,
  importLocal,
  importNetwork,
  importPaste,
  batchCheck,
}

enum _SourceItemMenuAction { debug, check, delete }

enum _BatchCheckScope {
  selectedSources,
  enabledSources,
  filteredEnabledSources,
  recentFailedSources,
  coolingDownSources,
}

class _SingleCheckRequest {
  const _SingleCheckRequest({required this.keyword, required this.level});

  final String keyword;
  final SourceCheckLevel level;
}

class _BatchCheckRequest {
  const _BatchCheckRequest({
    required this.keyword,
    required this.level,
    required this.scope,
  });

  final String keyword;
  final SourceCheckLevel level;
  final _BatchCheckScope scope;
}

class _BatchCheckProgressState {
  const _BatchCheckProgressState({
    required this.completedCount,
    required this.totalCount,
    required this.results,
    this.currentSourceName,
    this.finished = false,
  });

  final int completedCount;
  final int totalCount;
  final List<SourceCheckResult> results;
  final String? currentSourceName;
  final bool finished;

  _BatchCheckProgressState copyWith({
    int? completedCount,
    int? totalCount,
    List<SourceCheckResult>? results,
    Object? currentSourceName = _batchCheckSentinel,
    bool? finished,
  }) {
    return _BatchCheckProgressState(
      completedCount: completedCount ?? this.completedCount,
      totalCount: totalCount ?? this.totalCount,
      results: results ?? this.results,
      currentSourceName:
          identical(currentSourceName, _batchCheckSentinel)
              ? this.currentSourceName
              : currentSourceName as String?,
      finished: finished ?? this.finished,
    );
  }
}

const Object _batchCheckSentinel = Object();

class _CheckRequestDialog<T> extends StatefulWidget {
  const _CheckRequestDialog({
    required this.title,
    required this.helperText,
    required this.initialKeyword,
    required this.allowEmptyKeyword,
    required this.includeScope,
    required this.levelLabelBuilder,
    required this.scopeLabelBuilder,
    required this.onSubmit,
  });

  final String title;
  final String helperText;
  final String initialKeyword;
  final bool allowEmptyKeyword;
  final bool includeScope;
  final String Function(SourceCheckLevel level) levelLabelBuilder;
  final String Function(_BatchCheckScope scope) scopeLabelBuilder;
  final T Function(
    String keyword,
    SourceCheckLevel level,
    _BatchCheckScope scope,
  ) onSubmit;

  @override
  State<_CheckRequestDialog<T>> createState() => _CheckRequestDialogState<T>();
}

class _CheckRequestDialogState<T> extends State<_CheckRequestDialog<T>> {
  late final TextEditingController _controller;
  SourceCheckLevel _selectedLevel = SourceCheckLevel.searchOnly;
  _BatchCheckScope _selectedScope = _BatchCheckScope.enabledSources;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialKeyword);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.helperText),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '检测关键词',
              hintText: '留空时自动使用书源默认检测词',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<SourceCheckLevel>(
            initialValue: _selectedLevel,
            decoration: const InputDecoration(
              labelText: '检测级别',
              border: OutlineInputBorder(),
            ),
            items: SourceCheckLevel.values
                .map(
                  (level) => DropdownMenuItem<SourceCheckLevel>(
                    value: level,
                    child: Text(widget.levelLabelBuilder(level)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedLevel = value;
              });
            },
          ),
          if (widget.includeScope) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<_BatchCheckScope>(
              initialValue: _selectedScope,
              decoration: const InputDecoration(
                labelText: '检测范围',
                border: OutlineInputBorder(),
              ),
              items: _BatchCheckScope.values
                  .map(
                    (scope) => DropdownMenuItem<_BatchCheckScope>(
                      value: scope,
                      child: Text(widget.scopeLabelBuilder(scope)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedScope = value;
                });
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final keyword = _controller.text.trim();
            if (!widget.allowEmptyKeyword && keyword.isEmpty) {
              return;
            }
            Navigator.of(context).pop(
              widget.onSubmit(keyword, _selectedLevel, _selectedScope),
            );
          },
          child: const Text('开始'),
        ),
      ],
    );
  }
}

class _SourceSuggestionAction {
  const _SourceSuggestionAction({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;
}

class _SourceWebsiteClusterSummary {
  const _SourceWebsiteClusterSummary({
    required this.key,
    required this.title,
    required this.sourceCount,
    required this.healthSummary,
    required this.recommendedSourceId,
  });

  final String key;
  final String title;
  final int sourceCount;
  final String healthSummary;
  final String? recommendedSourceId;
}

class SourcePage extends StatefulWidget {
  const SourcePage({
    super.key,
    this.sourceRuntimeFacade,
    this.sourceCheckService,
    this.sourceHealthService,
    this.bootstrapOnInit = true,
    this.enableRouterNavigation = true,
  });

  final SourceRuntimeFacade? sourceRuntimeFacade;
  final SourceCheckService? sourceCheckService;
  final SourceHealthService? sourceHealthService;
  final bool bootstrapOnInit;
  final bool enableRouterNavigation;

  @override
  State<SourcePage> createState() => _SourcePageState();
}

class _SourcePageState extends State<SourcePage> {
  static const String _ungroupedGroupKey = '__ungrouped__';
  static const String _duplicateGroupKey = '__duplicate__';
  static const XTypeGroup _scriptSourceFileTypeGroup = XTypeGroup(
    label: 'Script Sources',
    extensions: <String>['js', 'mjs', 'txt'],
    mimeTypes: <String>[
      'text/javascript',
      'application/javascript',
      'text/plain',
    ],
    uniformTypeIdentifiers: <String>[
      'com.netscape.javascript-source',
      'public.plain-text',
    ],
  );

  late final SourceRuntimeFacade _sourceRuntimeFacade;
  late final SourceCheckService _sourceCheckService;
  late final SourceHealthService _sourceHealthService;
  late final SourceHealthActionPolicyService _policyService;
  late final TextEditingController _searchController;
  List<ScriptSource> _lastRawSources = const <ScriptSource>[];
  List<ScriptSource> _lastVisibleSources = const <ScriptSource>[];

  String _searchQuery = '';
  String? _selectedGroupKey;
  _ScriptSourceSortOption _sortOption = _ScriptSourceSortOption.updatedDesc;
  final Set<String> _selectedBatchSourceIds = <String>{};
  final Set<String> _changingEnabledScriptSourceIds = <String>{};
  final Set<String> _deletingScriptSourceIds = <String>{};
  final Dio _importDio = Dio();
  StreamSubscription<IncomingExternalImportPayload>? _incomingImportSub;
  bool _isConsumingExternalImportPayloads = false;

  @override
  void initState() {
    super.initState();
    _sourceRuntimeFacade =
        widget.sourceRuntimeFacade ?? SourceRuntimeFacade.instance;
    _sourceCheckService = widget.sourceCheckService ?? SourceCheckService();
    _sourceHealthService =
        widget.sourceHealthService ?? SourceHealthService.instance;
    _policyService = const SourceHealthActionPolicyService();
    _searchController = TextEditingController();
    _incomingImportSub = ExternalImportBridge.instance.payloadStream.listen((
      payload,
    ) {
      if (payload.type != ExternalImportPayloadType.scriptSource) {
        return;
      }
      unawaited(_consumePendingExternalImportPayloads());
    });
    if (widget.bootstrapOnInit) {
      unawaited(_reloadScriptSourcesSilently());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_consumePendingExternalImportPayloads());
    });
  }

  @override
  void dispose() {
    _incomingImportSub?.cancel();
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
          _lastRawSources = rawSources;
          final visibleSources = _resolveVisibleSources(rawSources);
          _lastVisibleSources = visibleSources;
          final clusterSummaries = _buildClusterSummaries(visibleSources);
          final filteredVisibleSources = _applyClusterFilter(
            visibleSources,
            clusterSummaries,
          );
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
                    if (_hasDuplicateSources(rawSources)) {
                      items.add(
                        const PopupMenuItem<String?>(
                          value: _duplicateGroupKey,
                          child: Text('重复源'),
                        ),
                      );
                    }
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
                      (context) => [
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
                        PopupMenuItem(
                          value: _SourcePageMenuAction.importPaste,
                          child: Text('粘贴导入'),
                        ),
                        PopupMenuItem(
                          value: _SourcePageMenuAction.batchCheck,
                          child: Text('批量检测'),
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
                visibleSources: filteredVisibleSources,
                clusterSummaries: clusterSummaries,
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
    required Map<String, _SourceWebsiteClusterSummary> clusterSummaries,
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
              ..._buildSourceListContent(
                context,
                visibleSources,
                clusterSummaries: clusterSummaries,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSourceListContent(
    BuildContext context,
    List<ScriptSource> visibleSources, {
    required Map<String, _SourceWebsiteClusterSummary> clusterSummaries,
  }) {
    return visibleSources
        .map(
          (source) => _buildSourceTile(
            context,
            source,
            clusterSummary: clusterSummaries[_clusterKeyOf(source)],
          ),
        )
        .toList(growable: false);
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
    if (_selectedBatchSourceIds.isNotEmpty) {
      chips.add(
        _buildSummaryChip(context, '已选：${_selectedBatchSourceIds.length}'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_searchQuery.trim().isNotEmpty ||
            _selectedGroupKey != null ||
            _selectedBatchSourceIds.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: [
                if (_selectedBatchSourceIds.isNotEmpty)
                  TextButton(
                    onPressed: _clearSelectedSources,
                    child: const Text('清空选中'),
                  ),
                if (_searchQuery.trim().isNotEmpty || _selectedGroupKey != null)
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('清空筛选'),
                  ),
              ],
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

  Widget _buildInfoChip(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(
    BuildContext context,
    String label, {
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSuggestedActionChips(
    BuildContext context, {
    required ScriptSource source,
    required SourceHealthSnapshot snapshot,
  }) {
    return List<Widget>.of(
      _suggestedActionsForSnapshot(source, snapshot).map(
        (suggestion) => _buildSuggestionChip(
          context,
          suggestion.label,
          onTap: suggestion.onTap,
        ),
      ),
      growable: false,
    );
  }

  List<_SourceSuggestionAction> _suggestedActionsForSnapshot(
    ScriptSource source,
    SourceHealthSnapshot snapshot,
  ) {
    final actions = <_SourceSuggestionAction>[];
    final needsCheck =
        snapshot.level == SourceHealthLevel.warning ||
        snapshot.level == SourceHealthLevel.risky ||
        snapshot.lastFailureReason?.trim().isNotEmpty == true;
    final suggestDisable = _policyService.shouldSuggestDisable(snapshot);

    if (needsCheck) {
      actions.add(
        _SourceSuggestionAction(
          label: '建议检测',
          onTap: () => unawaited(_runSingleCheck(source)),
        ),
      );
    }
    if (suggestDisable && source.enabled) {
      actions.add(
        _SourceSuggestionAction(
          label: '建议停用',
          onTap: () => unawaited(_confirmSuggestedDisable(source)),
        ),
      );
    }
    return actions;
  }

  Widget _buildEmptyStateCard(BuildContext context) {
    return Card(
      shape: _buildOutlinedCardShape(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          children: [
            Text(
              '还没有书源',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '可以新建脚本，或直接导入现成书源。',
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
              '改关键词、切换分组，或清空筛选后再试。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceTile(
    BuildContext context,
    ScriptSource source, {
    bool compact = false,
    bool highlightRecommended = false,
    _SourceWebsiteClusterSummary? clusterSummary,
  }) {
    final isChangingEnabled = _changingEnabledScriptSourceIds.contains(
      source.id,
    );
    final isDeleting = _deletingScriptSourceIds.contains(source.id);
    final busy = isChangingEnabled || isDeleting;
    final isSelected = _selectedBatchSourceIds.contains(source.id);
    final healthSnapshot = _sourceHealthService.snapshotFor(
      source.id,
      enabled: source.enabled,
    );
    final subtitleParts = <String>[
      if ((source.registrableDomain ?? '').isNotEmpty)
        source.registrableDomain!.trim(),
      if (source.group?.trim().isNotEmpty == true)
        source.group!.trim()
      else
        '未分组',
      _formatDateTime(source.updatedAt),
    ];

    return Card(
      margin: EdgeInsets.only(bottom: compact ? 6 : 8),
      shape: _buildOutlinedCardShape(context),
      color:
          highlightRecommended
              ? Theme.of(
                context,
              ).colorScheme.secondaryContainer.withValues(alpha: 0.28)
              : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, compact ? 6 : 8, 8, compact ? 6 : 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap:
                    busy
                        ? null
                        : () {
                          if (_selectedBatchSourceIds.isNotEmpty) {
                            _toggleSelectedSource(source.id);
                            return;
                          }
                          unawaited(
                            _openScriptSourceEditorPage(source: source),
                          );
                        },
                onLongPress:
                    busy ? null : () => _toggleSelectedSource(source.id),
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
                          fontWeight:
                              highlightRecommended
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                        ),
                      ),
                      if (highlightRecommended) ...[
                        const SizedBox(height: 4),
                        Text(
                          '推荐保留源',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        subtitleParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (clusterSummary != null &&
                              clusterSummary.sourceCount >= 2)
                            _buildInfoChip(
                              context,
                              '同站 ${clusterSummary.sourceCount} 个',
                            ),
                          if (clusterSummary != null &&
                              clusterSummary.recommendedSourceId == source.id)
                            _buildSuggestionChip(context, '推荐保留'),
                          if (clusterSummary != null &&
                              clusterSummary.sourceCount >= 2 &&
                              clusterSummary.recommendedSourceId == source.id)
                            _buildSuggestionChip(
                              context,
                              '停用同站其余源',
                              onTap:
                                  () => unawaited(
                                    _disableClusterOthersBySource(source),
                                  ),
                            ),
                          if (healthSnapshot.coolingDown)
                            _buildInfoChip(
                              context,
                              '冷却中${_formatCooldown(healthSnapshot.cooldownUntil)}',
                            ),
                          if (healthSnapshot.lastFailureReason
                                  ?.trim()
                                  .isNotEmpty ==
                              true)
                            _buildInfoChip(
                              context,
                              '失败: ${healthSnapshot.lastFailureReason!.trim()}',
                            ),
                          if (healthSnapshot.lastAutoDisableReason
                                  ?.trim()
                                  .isNotEmpty ==
                              true)
                            _buildInfoChip(
                              context,
                              '自动停用: ${healthSnapshot.lastAutoDisableReason!.trim()}',
                            ),
                          ..._buildSuggestedActionChips(
                            context,
                            source: source,
                            snapshot: healthSnapshot,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _buildSourceActionRail(
              context,
              source: source,
              busy: busy,
              isChangingEnabled: isChangingEnabled,
              isDeleting: isDeleting,
              isSelected: isSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceActionRail(
    BuildContext context, {
    required ScriptSource source,
    required bool busy,
    required bool isChangingEnabled,
    required bool isDeleting,
    required bool isSelected,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 84, maxWidth: 92),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_selectedBatchSourceIds.isNotEmpty || isSelected)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Checkbox(
                value: isSelected,
                visualDensity: VisualDensity.compact,
                onChanged:
                    busy ? null : (_) => _toggleSelectedSource(source.id),
              ),
            ),
          SizedBox(
            width: 48,
            child:
                isChangingEnabled
                    ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                    : Transform.scale(
                      scale: 0.88,
                      child: Switch.adaptive(
                        value: source.enabled,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged:
                            busy
                                ? null
                                : (value) => unawaited(
                                  _setScriptSourceEnabled(source, value),
                                ),
                      ),
                    ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: '编辑',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                iconSize: 18,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: _buildSourceMenuIcon(
                  context,
                  snapshot: _sourceHealthService.snapshotFor(
                    source.id,
                    enabled: source.enabled,
                  ),
                ),
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
                        value: _SourceItemMenuAction.check,
                        child: Text('检测'),
                      ),
                      PopupMenuItem(
                        value: _SourceItemMenuAction.delete,
                        child: Text('删除'),
                      ),
                    ],
              ),
            ],
          ),
          if (isDeleting)
            const Padding(
              padding: EdgeInsets.only(top: 4, right: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSourceMenuIcon(
    BuildContext context, {
    required SourceHealthSnapshot snapshot,
  }) {
    final dotColor = switch (snapshot.level) {
      SourceHealthLevel.unchecked => Theme.of(context).colorScheme.outline,
      SourceHealthLevel.healthy => const Color(0xFF35C759),
      SourceHealthLevel.warning => const Color(0xFFFFB020),
      SourceHealthLevel.risky => const Color(0xFFFF6B6B),
      SourceHealthLevel.unavailable => Theme.of(context).colorScheme.error,
    };

    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Align(
            alignment: Alignment.center,
            child: Icon(Icons.more_vert_rounded, size: 18),
          ),
          Positioned(
            right: 1,
            top: 1,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1.2,
                ),
              ),
            ),
          ),
        ],
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
        unawaited(_importLocalScriptSources());
        break;
      case _SourcePageMenuAction.importNetwork:
        unawaited(_importNetworkScriptSource());
        break;
      case _SourcePageMenuAction.importPaste:
        unawaited(_openPasteImportPage());
        break;
      case _SourcePageMenuAction.batchCheck:
        unawaited(_runBatchCheck());
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
      case _SourceItemMenuAction.check:
        unawaited(_runSingleCheck(source));
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
            if (_selectedGroupKey != _duplicateGroupKey &&
                sourceGroupKey != _selectedGroupKey) {
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

  bool _hasDuplicateSources(List<ScriptSource> sources) {
    return _buildClusterSummaries(sources).values.any(
      (summary) => summary.sourceCount >= 2,
    );
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
    if (selectedGroupKey == _duplicateGroupKey) {
      return _hasDuplicateSources(sources);
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
    if (groupKey == _duplicateGroupKey) {
      return '重复源';
    }
    if (groupKey == _ungroupedGroupKey) {
      return '未分组';
    }
    return groupKey;
  }

  String _clusterKeyOf(ScriptSource source) {
    final clusterKey = source.clusterKey?.trim();
    if (clusterKey != null && clusterKey.isNotEmpty) {
      return clusterKey.toLowerCase();
    }
    return '__unknown__:${source.id}';
  }

  String _clusterTitleOf(ScriptSource source) {
    final domain = source.registrableDomain?.trim();
    if (domain != null && domain.isNotEmpty) {
      return domain;
    }
    final host = source.primaryHost?.trim();
    if (host != null && host.isNotEmpty) {
      return host;
    }
    return '未识别站点';
  }

  Map<String, _SourceWebsiteClusterSummary> _buildClusterSummaries(
    List<ScriptSource> sources,
  ) {
    final groups = <String, List<ScriptSource>>{};
    for (final source in sources) {
      groups
          .putIfAbsent(_clusterKeyOf(source), () => <ScriptSource>[])
          .add(source);
    }

    final summaries = <String, _SourceWebsiteClusterSummary>{};
    for (final entry in groups.entries) {
      final clusterSources = entry.value..sort(_compareScriptSource);
      summaries[entry.key] = _SourceWebsiteClusterSummary(
        key: entry.key,
        title: _clusterTitleOf(clusterSources.first),
        sourceCount: clusterSources.length,
        healthSummary: _clusterHealthSummary(clusterSources),
        recommendedSourceId: _recommendedSourceOf(clusterSources)?.id,
      );
    }
    return summaries;
  }

  List<ScriptSource> _applyClusterFilter(
    List<ScriptSource> sources,
    Map<String, _SourceWebsiteClusterSummary> summaries,
  ) {
    if (_selectedGroupKey != _duplicateGroupKey) {
      return sources;
    }
    return sources
        .where((source) {
          final summary = summaries[_clusterKeyOf(source)];
          final count = summary?.sourceCount ?? 1;
          return count >= 2;
        })
        .toList(growable: false);
  }

  int _compareScriptSource(ScriptSource a, ScriptSource b) {
    final healthCompare = _healthRankOf(a).compareTo(_healthRankOf(b));
    if (healthCompare != 0) {
      return healthCompare;
    }
    final enabledCompare = (b.enabled ? 1 : 0).compareTo(a.enabled ? 1 : 0);
    if (enabledCompare != 0) {
      return enabledCompare;
    }
    final updatedCompare = b.updatedAt.compareTo(a.updatedAt);
    if (updatedCompare != 0) {
      return updatedCompare;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  int _healthRankOf(ScriptSource source) {
    final snapshot = _sourceHealthService.snapshotFor(
      source.id,
      enabled: source.enabled,
    );
    return switch (snapshot.level) {
      SourceHealthLevel.healthy => 0,
      SourceHealthLevel.unchecked => 1,
      SourceHealthLevel.warning => 2,
      SourceHealthLevel.risky => 3,
      SourceHealthLevel.unavailable => 4,
    };
  }

  String _clusterHealthSummary(List<ScriptSource> sources) {
    var unchecked = 0;
    var healthy = 0;
    var warning = 0;
    var risky = 0;
    var unavailable = 0;
    for (final source in sources) {
      final level =
          _sourceHealthService
              .snapshotFor(source.id, enabled: source.enabled)
              .level;
      switch (level) {
        case SourceHealthLevel.unchecked:
          unchecked += 1;
          break;
        case SourceHealthLevel.healthy:
          healthy += 1;
          break;
        case SourceHealthLevel.warning:
          warning += 1;
          break;
        case SourceHealthLevel.risky:
          risky += 1;
          break;
        case SourceHealthLevel.unavailable:
          unavailable += 1;
          break;
      }
    }
    final parts = <String>[
      if (unchecked > 0) '$unchecked 未检测',
      if (healthy > 0) '$healthy 正常',
      if (warning > 0) '$warning 注意',
      if (risky > 0) '$risky 高风险',
      if (unavailable > 0) '$unavailable 不可用',
    ];
    return parts.join(' / ');
  }

  ScriptSource? _recommendedSourceOf(List<ScriptSource> sources) {
    if (sources.isEmpty) {
      return null;
    }
    final sorted = List<ScriptSource>.of(sources)..sort(_compareScriptSource);
    return sorted.first;
  }

  Future<void> _disableClusterOthersBySource(ScriptSource source) async {
    final clusterKey = _clusterKeyOf(source);
    final clusterSources = _lastVisibleSources
        .where((item) => _clusterKeyOf(item) == clusterKey)
        .toList(growable: false);
    final recommended = _recommendedSourceOf(clusterSources);
    final keepSourceId = recommended?.id ?? source.id;
    final targets = clusterSources
        .where((item) => item.id != keepSourceId && item.enabled)
        .toList(growable: false);
    for (final source in targets) {
      await _sourceRuntimeFacade.setScriptSourceEnabled(
        id: source.id,
        enabled: false,
      );
    }
    if (!mounted) {
      return;
    }
    _showMessage('已停用 ${targets.length} 个同站重复源。');
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

  void _clearSelectedSources() {
    if (_selectedBatchSourceIds.isEmpty) {
      return;
    }
    setState(() {
      _selectedBatchSourceIds.clear();
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

  Future<void> _openPasteImportPage() async {
    final result = await context.push<String>('/source/paste-import');
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

  Future<void> _importLocalScriptSources() async {
    final files = await openFiles(
      acceptedTypeGroups: const <XTypeGroup>[_scriptSourceFileTypeGroup],
      confirmButtonText: '选择书源脚本',
    );
    if (!mounted || files.isEmpty) {
      return;
    }

    var successCount = 0;
    var failureCount = 0;
    String? lastError;

    for (final file in files) {
      try {
        final contents = await file.readAsString();
        await _sourceRuntimeFacade.saveScriptSource(sourceCode: contents);
        successCount += 1;
      } catch (error) {
        failureCount += 1;
        lastError = _toFriendlyImportError(error);
      }
    }

    if (!mounted) {
      return;
    }

    if (successCount > 0) {
      if (failureCount > 0) {
        _showMessage('已导入 $successCount 个书源，失败 $failureCount 个。');
      } else {
        _showMessage('已导入 $successCount 个书源。');
      }
      return;
    }

    _showMessage(lastError ?? '导入失败，请重试。');
  }

  Future<void> _importNetworkScriptSource() async {
    final url = await _promptImportUrl();
    if (url == null || !mounted) {
      return;
    }

    try {
      final response = await _importDio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final contents = (response.data ?? '').trim();
      if (contents.isEmpty) {
        _showMessage('网络导入失败：返回内容为空。');
        return;
      }
      await _sourceRuntimeFacade.saveScriptSource(sourceCode: contents);
      if (!mounted) {
        return;
      }
      _showMessage('网络书源导入成功。');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('网络导入失败：${_toFriendlyImportError(error)}');
    }
  }

  Future<String?> _promptImportUrl() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('网络导入书源'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '书源 URL',
              hintText: 'https://example.com/source.js',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final url = controller.text.trim();
                final uri = Uri.tryParse(url);
                if (uri == null ||
                    !uri.hasScheme ||
                    (uri.scheme != 'http' && uri.scheme != 'https')) {
                  return;
                }
                Navigator.of(context).pop(url);
              },
              child: const Text('导入'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _consumePendingExternalImportPayloads() async {
    if (_isConsumingExternalImportPayloads || !mounted) {
      return;
    }

    _isConsumingExternalImportPayloads = true;
    try {
      while (mounted) {
        final payload = ExternalImportBridge.instance.consumePendingPayload(
          type: ExternalImportPayloadType.scriptSource,
        );
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
    IncomingExternalImportPayload payload,
  ) async {
    final cached = await ExternalImportBridge.instance.cacheExternalFileFromUri(
      payload,
    );
    if (cached == null) {
      _showMessage('读取外部书源失败：${payload.label}');
      return;
    }

    final tempFile = File(cached.path);
    try {
      final extension = cached.label.contains('.')
          ? cached.label.substring(cached.label.lastIndexOf('.')).toLowerCase()
          : '';
      if (extension != '.js' && extension != '.mjs' && extension != '.txt') {
        _showMessage('暂不支持导入该书源文件：${cached.label}');
        return;
      }

      final contents = await tempFile.readAsString();
      await _sourceRuntimeFacade.saveScriptSource(sourceCode: contents);
      if (!mounted) {
        return;
      }
      _showMessage('已导入 ${cached.label}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('导入失败：${_toFriendlyImportError(error)}');
    } finally {
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
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

  Future<void> _runSingleCheck(ScriptSource source) async {
    final request = await _promptSingleCheckRequest(source);
    if (request == null || !mounted) {
      return;
    }

    final result = await _sourceCheckService.checkSource(
      sourceId: source.id,
      keyword: request.keyword,
      level: request.level,
    );
    if (!mounted) {
      return;
    }
    setState(() {});
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('检测结果 · ${source.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('状态：${_checkStatusLabel(result.status)}'),
              const SizedBox(height: 8),
              Text('关键词：${result.usedKeyword}'),
              const SizedBox(height: 8),
              Text('级别：${_checkLevelLabel(result.checkedLevel)}'),
              const SizedBox(height: 8),
              Text('步骤：${_checkStepLabel(result.stepReached)}'),
              const SizedBox(height: 8),
              Text('耗时：${result.duration.inMilliseconds} ms'),
              const SizedBox(height: 8),
              Text(result.message),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runBatchCheck() async {
    final request = await _promptBatchCheckRequest();
    if (request == null || !mounted) {
      return;
    }
    final candidates = _resolveBatchCheckSources(request.scope);
    if (candidates.isEmpty) {
      _showMessage('当前范围内没有可检测书源。');
      return;
    }

    final progress = ValueNotifier<_BatchCheckProgressState>(
      _BatchCheckProgressState(
        completedCount: 0,
        totalCount: candidates.length,
        results: const <SourceCheckResult>[],
        currentSourceName: candidates.first.name,
      ),
    );
    var started = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) {
        if (!started) {
          started = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final results = await _sourceCheckService.checkSources(
              sourceIds: candidates.map((source) => source.id),
              keyword: request.keyword,
              level: request.level,
              skipCooldown: true,
              onProgress: (result, completedCount, totalCount) {
                progress.value = progress.value.copyWith(
                  completedCount: completedCount,
                  totalCount: totalCount,
                  currentSourceName:
                      completedCount < candidates.length
                          ? candidates[completedCount].name
                          : null,
                  results: List<SourceCheckResult>.unmodifiable(
                    <SourceCheckResult>[
                      ...progress.value.results,
                      result,
                    ],
                  ),
                );
                if (mounted) {
                  setState(() {});
                }
              },
            );
            progress.value = progress.value.copyWith(
              finished: true,
              currentSourceName: null,
              results: List<SourceCheckResult>.unmodifiable(results),
            );
            if (mounted) {
              setState(() {});
            }
          });
        }

        final maxHeight = MediaQuery.of(context).size.height * 0.82;
        return ValueListenableBuilder<_BatchCheckProgressState>(
          valueListenable: progress,
          builder: (context, state, _) {
            final results = state.results;
            final healthyCount =
                results
                    .where((result) => result.status == SourceCheckStatus.healthy)
                    .length;
            final warningCount =
                results
                    .where((result) => result.status == SourceCheckStatus.warning)
                    .length;
            final skippedResults = results
                .where((result) => result.status == SourceCheckStatus.skipped)
                .toList(growable: false);
            final failedResults = results
                .where((result) => result.status == SourceCheckStatus.failed)
                .toList(growable: false);
            final warningResults = results
                .where((result) => result.status == SourceCheckStatus.warning)
                .toList(growable: false);
            final healthyResults = results
                .where((result) => result.status == SourceCheckStatus.healthy)
                .toList(growable: false);

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.finished ? '批量检测结果' : '批量检测中',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text('范围：${_batchCheckScopeLabel(request.scope)}'),
                      Text('级别：${_checkLevelLabel(request.level)}'),
                      Text('进度：${state.completedCount} / ${state.totalCount}'),
                      if (!state.finished &&
                          (state.currentSourceName?.trim().isNotEmpty ?? false))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '正在检测：${state.currentSourceName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value:
                            state.totalCount == 0
                                ? null
                                : state.completedCount / state.totalCount,
                      ),
                      const SizedBox(height: 12),
                      Text('通过：$healthyCount'),
                      Text('风险：$warningCount'),
                      Text('失败：${failedResults.length}'),
                      Text('跳过：${skippedResults.length}'),
                      const SizedBox(height: 12),
                      if (state.finished && failedResults.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await _batchDisableFailedSources(failedResults);
                              },
                              child: const Text('批量停用失败源'),
                            ),
                            OutlinedButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await _batchDeleteFailedSources(failedResults);
                              },
                              child: const Text('批量删除失败源'),
                            ),
                          ],
                        ),
                      if (state.finished) const SizedBox(height: 12),
                      Expanded(
                        child: ListView(
                          children: [
                            if (!state.finished && results.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Text('检测进行中，请稍候…'),
                              ),
                            _buildBatchResultSection(
                              context,
                              title: '失败',
                              results: failedResults,
                            ),
                            _buildBatchResultSection(
                              context,
                              title: '风险',
                              results: warningResults,
                            ),
                            _buildBatchResultSection(
                              context,
                              title: '跳过',
                              results: skippedResults,
                            ),
                            _buildBatchResultSection(
                              context,
                              title: '通过',
                              results: healthyResults,
                            ),
                          ],
                        ),
                      ),
                      if (state.finished)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('关闭'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    progress.dispose();
  }

  Widget _buildBatchResultSection(
    BuildContext context, {
    required String title,
    required List<SourceCheckResult> results,
  }) {
    if (results.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title (${results.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...results.map(
            (result) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${result.sourceName} · 关键词 ${result.usedKeyword} · ${_checkStepLabel(result.stepReached)} · ${result.message}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _batchDisableFailedSources(
    List<SourceCheckResult> failedResults,
  ) async {
    for (final result in failedResults) {
      await _sourceRuntimeFacade.setScriptSourceEnabled(
        id: result.sourceId,
        enabled: false,
      );
    }
    if (!mounted) {
      return;
    }
    _showMessage('已批量停用 ${failedResults.length} 个失败书源。');
  }

  Future<void> _batchDeleteFailedSources(
    List<SourceCheckResult> failedResults,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('批量删除失败源'),
          content: Text('确认删除 ${failedResults.length} 个失败书源吗？此操作不可撤销。'),
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

    for (final result in failedResults) {
      await _sourceRuntimeFacade.deleteScriptSource(result.sourceId);
    }
    if (!mounted) {
      return;
    }
    _showMessage('已批量删除 ${failedResults.length} 个失败书源。');
  }

  List<ScriptSource> _resolveBatchCheckSources(_BatchCheckScope scope) {
    switch (scope) {
      case _BatchCheckScope.selectedSources:
        return _lastRawSources
            .where((source) => _selectedBatchSourceIds.contains(source.id))
            .toList(growable: false);
      case _BatchCheckScope.enabledSources:
        return _lastRawSources
            .where((source) => source.enabled)
            .toList(growable: false);
      case _BatchCheckScope.filteredEnabledSources:
        return _lastVisibleSources
            .where((source) => source.enabled)
            .toList(growable: false);
      case _BatchCheckScope.recentFailedSources:
        return _lastRawSources
            .where(
              (source) =>
                  source.enabled &&
                  _sourceHealthService
                          .snapshotFor(source.id, enabled: source.enabled)
                          .lastFailureAt !=
                      null,
            )
            .toList(growable: false);
      case _BatchCheckScope.coolingDownSources:
        return _lastRawSources
            .where(
              (source) =>
                  source.enabled &&
                  _sourceHealthService
                      .snapshotFor(source.id, enabled: source.enabled)
                      .coolingDown,
            )
            .toList(growable: false);
    }
  }

  Future<void> _confirmSuggestedDisable(ScriptSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('建议停用'),
          content: Text('「${source.name}」近期风险较高，是否现在停用？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('停用'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await _setScriptSourceEnabled(source, false);
  }

  Future<_SingleCheckRequest?> _promptSingleCheckRequest(ScriptSource source) {
    return _showCheckRequestDialog<_SingleCheckRequest>(
      title: '单源检测',
      helperText: '默认建议先执行 searchOnly。留空时优先使用该书源的 checkKeyword，未配置则回退到系统默认关键词。',
      initialKeyword: source.checkKeyword ?? SourceCheckService.defaultCheckKeyword,
      allowEmptyKeyword: true,
      includeScope: false,
      onSubmit: (keyword, level, _) {
        return _SingleCheckRequest(keyword: keyword, level: level);
      },
    );
  }

  Future<_BatchCheckRequest?> _promptBatchCheckRequest() {
    return _showCheckRequestDialog<_BatchCheckRequest>(
      title: '批量检测',
      helperText: '默认会跳过冷却中的源。留空时优先使用每个书源自己的 checkKeyword，未配置的源再回退到系统默认关键词。',
      initialKeyword: '',
      allowEmptyKeyword: true,
      includeScope: true,
      onSubmit: (keyword, level, scope) {
        return _BatchCheckRequest(keyword: keyword, level: level, scope: scope);
      },
    );
  }

  Future<T?> _showCheckRequestDialog<T>({
    required String title,
    required String helperText,
    required String initialKeyword,
    required bool allowEmptyKeyword,
    required bool includeScope,
    required T Function(
      String keyword,
      SourceCheckLevel level,
      _BatchCheckScope scope,
    )
    onSubmit,
  }) async {
    return showDialog<T>(
      context: context,
      builder: (context) {
        return _CheckRequestDialog<T>(
          title: title,
          helperText: helperText,
          initialKeyword: initialKeyword,
          allowEmptyKeyword: allowEmptyKeyword,
          includeScope: includeScope,
          levelLabelBuilder: _checkLevelLabel,
          scopeLabelBuilder: _batchCheckScopeLabel,
          onSubmit: onSubmit,
        );
      },
    );
  }

  String _checkStatusLabel(SourceCheckStatus status) {
    return switch (status) {
      SourceCheckStatus.healthy => '通过',
      SourceCheckStatus.warning => '风险',
      SourceCheckStatus.failed => '失败',
      SourceCheckStatus.skipped => '跳过',
    };
  }

  String _checkLevelLabel(SourceCheckLevel level) {
    return switch (level) {
      SourceCheckLevel.searchOnly => '仅搜索',
      SourceCheckLevel.searchAndDetail => '搜索 + 详情',
      SourceCheckLevel.fullReadPath => '完整阅读链路',
    };
  }

  String _batchCheckScopeLabel(_BatchCheckScope scope) {
    return switch (scope) {
      _BatchCheckScope.selectedSources => '当前选中源',
      _BatchCheckScope.enabledSources => '当前启用源',
      _BatchCheckScope.filteredEnabledSources => '当前筛选结果',
      _BatchCheckScope.recentFailedSources => '最近失败源',
      _BatchCheckScope.coolingDownSources => '冷却中源',
    };
  }

  String _toFriendlyImportError(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) {
      return '导入失败，请检查书源格式后重试。';
    }
    if (raw.contains('书源缺少必须方法')) {
      return '书源缺少必须方法，至少需要实现 search / detail / chapters / content。';
    }
    if (raw.contains('无法读取书源导出的 meta')) {
      return '无法识别书源格式，请确认内容使用 export default 导出，并包含 meta.name。';
    }
    if (raw.contains('书源导出格式不支持') || raw.contains('当前仅支持以')) {
      return '书源导出格式不支持，请使用 export default { meta, ... }。';
    }
    if (raw.contains('Script source code cannot be empty')) {
      return '书源内容不能为空。';
    }
    return raw.replaceFirst('SourceScriptCompileException: ', '');
  }

  void _toggleSelectedSource(String sourceId) {
    setState(() {
      if (!_selectedBatchSourceIds.add(sourceId)) {
        _selectedBatchSourceIds.remove(sourceId);
      }
    });
  }

  String _checkStepLabel(SourceCheckStep step) {
    return switch (step) {
      SourceCheckStep.none => '未执行',
      SourceCheckStep.search => '搜索',
      SourceCheckStep.detail => '详情',
      SourceCheckStep.chapters => '目录',
      SourceCheckStep.content => '正文',
    };
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

  String _formatCooldown(DateTime? cooldownUntil) {
    if (cooldownUntil == null) {
      return '';
    }
    final diff = cooldownUntil.difference(DateTime.now());
    if (diff.inMinutes <= 0) {
      return '';
    }
    return ' ${diff.inMinutes}m';
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
