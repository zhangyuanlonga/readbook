part of 'source_page.dart';

extension on _SourcePageState {
  void _handleAuthEvent(AuthEvent event) {
    switch (event.type) {
      case AuthEventType.loggedIn:
      case AuthEventType.loggedOut:
      case AuthEventType.sessionExpired:
        unawaited(_loadFeatureAccess());
        break;
    }
  }

  Future<void> _loadFeatureAccess() async {
    if (!mounted) {
      return;
    }

    _updateSourcePageState(() {
      _canAccessSourcePage = true;
      _sourceImportLimit = 10;
      _isFeatureAccessLoading = true;
    });

    try {
      final access = await _accessService.loadFeatureAccess();
      if (!mounted) {
        return;
      }
      _updateSourcePageState(() {
        _canAccessSourcePage = access.canAccessSourcePage;
        _sourceImportLimit = access.sourceImportLimit;
        _isFeatureAccessLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      debugPrint('获取功能权限失败，使用默认配置: $e');
      _updateSourcePageState(() {
        _canAccessSourcePage = true;
        _sourceImportLimit = 10;
        _isFeatureAccessLoading = false;
      });
    }
  }

  Future<bool> _ensureCanAddSource() async {
    if (_isFeatureAccessLoading) {
      _showMessage('正在初始化书源功能，请稍后重试。');
      return false;
    }

    if (!_accessService.canAddSource(
      isLoading: _isFeatureAccessLoading,
      sourceImportLimit: _sourceImportLimit,
      currentSourceCount: _lastRawSources.length,
    )) {
      _showMessage('已达到书源导入上限（最多 $_sourceImportLimit 个）。');
      return false;
    }
    return true;
  }

  int _remainingSourceImportSlots() {
    return _accessService.remainingSourceImportSlots(
      sourceImportLimit: _sourceImportLimit,
      currentSourceCount: _lastRawSources.length,
    );
  }

  Widget _buildSourcePage(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final backdrop = resolveAdvancedThemeBackdrop(
          Theme.of(context).colorScheme,
          ref.watch(activeAdvancedThemeProvider).valueOrNull,
        );
        final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

        Widget themedBody(Widget child) {
          return DecoratedBox(
            decoration: buildAdvancedThemeBackdropDecoration(backdrop),
            child: child,
          );
        }

        if (_isFeatureAccessLoading) {
          return Scaffold(
            resizeToAvoidBottomInset: false,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: const Text('书源'),
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
            body: themedBody(const Center(child: CircularProgressIndicator())),
          );
        }

        // 只有在明确被禁用时才显示提示（基本上不会发生）
        if (!_canAccessSourcePage) {
          return Scaffold(
            resizeToAvoidBottomInset: false,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: const Text('书源'),
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
            body: themedBody(
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        '书源功能暂不可用',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '当前设备上的书源入口暂未开放，请稍后再试。',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

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
              _ensureDerivedSourceViewState(rawSources);
              final visibleSources = _cachedVisibleSources;
              _lastVisibleSources = visibleSources;
              final clusterSummaries = _cachedClusterSummaries;
              final filteredVisibleSources = _cachedFilteredVisibleSources;
              final availableGroups = _cachedAvailableGroups;

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
                  _updateSourcePageState(() {
                    _selectedGroupKey = null;
                  });
                });
              }

              return Scaffold(
                resizeToAvoidBottomInset: false,
                extendBodyBehindAppBar: true,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  shadowColor: Colors.transparent,
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
                        _updateSourcePageState(() {
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
                        _updateSourcePageState(() {
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
                              value: _SourcePageState._duplicateGroupKey,
                              child: Text('重复源'),
                            ),
                          );
                        }
                        if (_hasUngrouped(rawSources)) {
                          items.add(
                            const PopupMenuItem<String?>(
                              value: _SourcePageState._ungroupedGroupKey,
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
                body: themedBody(
                  SafeArea(
                    top: false,
                    child: _buildBody(
                      context,
                      topInset: topInset,
                      snapshot: snapshot,
                      rawSources: rawSources,
                      visibleSources: filteredVisibleSources,
                      clusterSummaries: clusterSummaries,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required double topInset,
    required AsyncSnapshot<List<ScriptSource>> snapshot,
    required List<ScriptSource> rawSources,
    required List<ScriptSource> visibleSources,
    required Map<String, _SourceWebsiteClusterSummary> clusterSummaries,
  }) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
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
            topInset + 12,
            horizontal,
            12 + bottomSafe + keyboardInset,
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
            _updateSourcePageState(() {
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
                        _updateSourcePageState(() {
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
    return const AppEmptyStateCard(
      icon: Icons.auto_stories_outlined,
      title: '还没有书源',
      description: '可以新建脚本，或直接导入现成书源。',
    );
  }

  Widget _buildNoResultCard(BuildContext context) {
    return const AppEmptyStateCard(
      icon: Icons.search_off_rounded,
      title: '没有匹配结果',
      description: '改关键词、切换分组，或清空筛选后再试。',
      compact: true,
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
                itemBuilder: (context) {
                  return <PopupMenuEntry<_SourceItemMenuAction>>[
                    if (_supportsSourceLogin(source))
                      const PopupMenuItem(
                        value: _SourceItemMenuAction.login,
                        child: Text('登录'),
                      ),
                    const PopupMenuItem(
                      value: _SourceItemMenuAction.debug,
                      child: Text('调试'),
                    ),
                    const PopupMenuItem(
                      value: _SourceItemMenuAction.check,
                      child: Text('检测'),
                    ),
                    const PopupMenuItem(
                      value: _SourceItemMenuAction.export,
                      child: Text('导出'),
                    ),
                    const PopupMenuItem(
                      value: _SourceItemMenuAction.delete,
                      child: Text('删除'),
                    ),
                  ];
                },
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
        unawaited(_guardedOpenScriptSourceEditorPage());
        break;
      case _SourcePageMenuAction.importLocal:
        unawaited(_guardedImportLocalScriptSources());
        break;
      case _SourcePageMenuAction.importNetwork:
        unawaited(_guardedImportNetworkScriptSource());
        break;
      case _SourcePageMenuAction.importPaste:
        unawaited(_guardedOpenPasteImportPage());
        break;
      case _SourcePageMenuAction.batchCheck:
        unawaited(_runBatchCheck());
        break;
    }
  }

  Future<void> _guardedOpenScriptSourceEditorPage() async {
    if (!await _ensureCanAddSource()) {
      return;
    }
    await _openScriptSourceEditorPage();
  }

  Future<void> _guardedOpenPasteImportPage() async {
    if (!await _ensureCanAddSource()) {
      return;
    }
    await _openPasteImportPage();
  }

  Future<void> _guardedImportLocalScriptSources() async {
    if (!await _ensureCanAddSource()) {
      return;
    }
    await _importLocalScriptSources();
  }

  Future<void> _guardedImportNetworkScriptSource() async {
    if (!await _ensureCanAddSource()) {
      return;
    }
    await _importNetworkScriptSource();
  }

  void _handleSourceItemMenuAction(
    ScriptSource source,
    _SourceItemMenuAction action,
  ) {
    switch (action) {
      case _SourceItemMenuAction.login:
        unawaited(_openLoginPage(source));
        break;
      case _SourceItemMenuAction.debug:
        unawaited(_openDebugPage(source));
        break;
      case _SourceItemMenuAction.check:
        unawaited(_runSingleCheck(source));
        break;
      case _SourceItemMenuAction.export:
        unawaited(_exportScriptSource(source));
        break;
      case _SourceItemMenuAction.delete:
        unawaited(_deleteScriptSource(source));
        break;
    }
  }

  bool _supportsSourceLogin(ScriptSource source) {
    final code = source.sourceCode;
    return code.contains('loginUi:') ||
        code.contains('loginUrl:') ||
        code.contains('async login(');
  }

  Future<void> _openLoginPage(ScriptSource source) async {
    final resolution = await _sourceLoginEntryResolver.resolve(source.id);
    if (!mounted) {
      return;
    }
    switch (resolution.mode) {
      case SourceLoginEntryMode.form:
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (sheetContext) {
            final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.82,
                minChildSize: 0.55,
                maxChildSize: 1.0,
                snap: true,
                snapSizes: const <double>[0.82, 1.0],
                builder: (context, scrollController) {
                  return SourceLoginPage(
                    sourceId: source.id,
                    embedded: true,
                    parentScrollController: scrollController,
                  );
                },
              ),
            );
          },
        );
        return;
      case SourceLoginEntryMode.web:
        if (widget.enableRouterNavigation) {
          await context.push(
            '/source/web-login?id=${Uri.encodeQueryComponent(source.id)}',
          );
        } else {
          await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => SourceWebLoginPage(sourceId: source.id),
            ),
          );
        }
        return;
      case SourceLoginEntryMode.unsupported:
        _showMessage(resolution.message ?? '当前书源未声明可用的登录入口。');
        return;
    }
  }

  List<ScriptSource> _resolveVisibleSources(List<ScriptSource> sources) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered =
        sources.where((source) {
          if (_selectedGroupKey != null) {
            final sourceGroupKey = _groupKeyOf(source);
            if (_selectedGroupKey != _SourcePageState._duplicateGroupKey &&
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
    return sources.any(
      (source) => _groupKeyOf(source) == _SourcePageState._ungroupedGroupKey,
    );
  }

  bool _hasDuplicateSources(List<ScriptSource> sources) {
    return _buildClusterSummaries(
      sources,
    ).values.any((summary) => summary.sourceCount >= 2);
  }

  bool _isCurrentGroupSelectionAvailable({
    required String? selectedGroupKey,
    required List<String> availableGroups,
    required List<ScriptSource> sources,
  }) {
    if (selectedGroupKey == null) {
      return true;
    }
    if (selectedGroupKey == _SourcePageState._ungroupedGroupKey) {
      return _hasUngrouped(sources);
    }
    if (selectedGroupKey == _SourcePageState._duplicateGroupKey) {
      return _hasDuplicateSources(sources);
    }
    return availableGroups.contains(selectedGroupKey);
  }

  String _groupKeyOf(ScriptSource source) {
    final group = source.group?.trim() ?? '';
    return group.isEmpty ? _SourcePageState._ungroupedGroupKey : group;
  }

  String _groupLabel(String? groupKey) {
    if (groupKey == null) {
      return '全部';
    }
    if (groupKey == _SourcePageState._duplicateGroupKey) {
      return '重复源';
    }
    if (groupKey == _SourcePageState._ungroupedGroupKey) {
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
    if (_selectedGroupKey != _SourcePageState._duplicateGroupKey) {
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
    _updateSourcePageState(() {
      _searchQuery = '';
      _selectedGroupKey = null;
    });
  }

  void _clearSelectedSources() {
    if (_selectedBatchSourceIds.isEmpty) {
      return;
    }
    _updateSourcePageState(() {
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

  void _ensureDerivedSourceViewState(List<ScriptSource> rawSources) {
    final query = _searchQuery.trim().toLowerCase();
    var healthFingerprint = 0;
    for (final source in rawSources) {
      healthFingerprint = Object.hash(
        healthFingerprint,
        source.id,
        _sourceHealthService
            .snapshotFor(source.id, enabled: source.enabled)
            .level,
      );
    }
    final fingerprint = Object.hash(
      identityHashCode(rawSources),
      query,
      _selectedGroupKey,
      _sortOption,
      healthFingerprint,
    );
    if (_derivedSourceViewFingerprint == fingerprint) {
      return;
    }

    final visibleSources = _resolveVisibleSources(rawSources);
    final clusterSummaries = _buildClusterSummaries(
      List<ScriptSource>.of(visibleSources),
    );
    final filteredVisibleSources = _applyClusterFilter(
      visibleSources,
      clusterSummaries,
    );
    final availableGroups = _collectGroupKeys(rawSources);

    _cachedVisibleSources = List<ScriptSource>.unmodifiable(visibleSources);
    _cachedClusterSummaries =
        Map<String, _SourceWebsiteClusterSummary>.unmodifiable(
          clusterSummaries,
        );
    _cachedFilteredVisibleSources = List<ScriptSource>.unmodifiable(
      filteredVisibleSources,
    );
    _cachedAvailableGroups = List<String>.unmodifiable(availableGroups);
    _derivedSourceViewFingerprint = fingerprint;
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
              sourceId: source.id,
              title: '${source.name} 调试',
              initialKeyword: source.checkKeyword,
            ),
      ),
    );
  }

  Future<void> _exportScriptSource(ScriptSource source) async {
    try {
      final fileName = '${_normalizedSourceFileName(source.name)}.js';
      if (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux) {
        final location = await getSaveLocation(
          acceptedTypeGroups: const <XTypeGroup>[
            ExternalImportCatalog.scriptSourceTypeGroup,
          ],
          suggestedName: fileName,
          confirmButtonText: '导出书源',
        );
        if (location == null) {
          return;
        }
        final file = File(location.path);
        await file.writeAsString(source.sourceCode, flush: true);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsString(source.sourceCode, flush: true);
        try {
          final sharePositionOrigin = _resolveSharePositionOrigin();
          await Share.shareXFiles(
            [XFile(file.path)],
            text: '分享书源：${source.name}',
            subject: source.name,
            sharePositionOrigin: sharePositionOrigin,
          );
        } on MissingPluginException {
          await Clipboard.setData(ClipboardData(text: source.sourceCode));
          if (!mounted) {
            return;
          }
          _showMessage('当前安装包暂不支持系统分享，已复制书源代码，请完整重启 App 后重试。');
          return;
        }
      }
      if (!mounted) {
        return;
      }
      _showMessage('已导出书源：${source.name}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('导出书源失败：$error');
    }
  }

  String _normalizedSourceFileName(String raw) {
    final normalized = raw.trim().replaceAll(RegExp(r'[\\\\/:*?\"<>|]+'), '_');
    return normalized.isEmpty ? 'script_source' : normalized;
  }

  Rect? _resolveSharePositionOrigin() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    final size = renderObject.size;
    if (size.isEmpty) {
      return null;
    }
    final origin = renderObject.localToGlobal(Offset.zero);
    return origin & size;
  }

  Future<void> _importLocalScriptSources() async {
    final files = await openFiles(
      acceptedTypeGroups: const <XTypeGroup>[
        ExternalImportCatalog.scriptSourceTypeGroup,
      ],
      confirmButtonText: '选择书源脚本',
    );
    if (!mounted || files.isEmpty) {
      return;
    }

    final summary = await _importService.importLocalFiles(
      files: files,
      remainingSlots: _remainingSourceImportSlots(),
      saver: (sourceCode) {
        return _sourceRuntimeFacade.saveScriptSource(sourceCode: sourceCode);
      },
      errorFormatter: _toFriendlyImportError,
    );

    if (!mounted) {
      return;
    }

    if (summary.hasSuccess) {
      if (summary.truncatedByLimit) {
        _showMessage('已导入 ${summary.successCount} 个书源，已达到当前导入上限。');
        return;
      }
      if (summary.failureCount > 0) {
        _showMessage(
          '已导入 ${summary.successCount} 个书源，失败 ${summary.failureCount} 个。',
        );
      } else {
        _showMessage('已导入 ${summary.successCount} 个书源。');
      }
      return;
    }

    _showMessage(summary.lastError ?? '导入失败，请重试。');
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
      await _importService.importNetworkSource(
        sourceCode: contents,
        saver: (sourceCode) {
          return _sourceRuntimeFacade.saveScriptSource(sourceCode: sourceCode);
        },
      );
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
    var draftUrl = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        void submit() {
          final url = draftUrl.trim();
          final uri = Uri.tryParse(url);
          if (uri == null ||
              !uri.hasScheme ||
              (uri.scheme != 'http' && uri.scheme != 'https')) {
            return;
          }
          Navigator.of(context).pop(url);
        }

        return AlertDialog(
          title: const Text('网络导入书源'),
          content: TextFormField(
            autofocus: appEnableAutoFocusForTextInput,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '书源 URL',
              hintText: 'https://example.com/source.js',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              draftUrl = value;
            },
            onFieldSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(onPressed: submit, child: const Text('导入')),
          ],
        );
      },
    );
    return result;
  }

  Future<void> _consumePendingExternalImportPayloads() async {
    if (_isConsumingExternalImportPayloads || !mounted) {
      return;
    }

    _isConsumingExternalImportPayloads = true;
    try {
      await _pageFlowCoordinator.consumePendingScriptSourcePayloads(
        _importFromExternalPayload,
      );
    } finally {
      _isConsumingExternalImportPayloads = false;
    }
  }

  Future<void> _importFromExternalPayload(
    IncomingExternalImportPayload payload,
  ) async {
    final cached = await _pageFlowCoordinator.cacheExternalFileFromUri(payload);
    if (cached == null) {
      ExternalImportDiagnostics.logCacheFailed(payload);
      _showMessage(
        ExternalImportDiagnostics.readFailedMessage(
          payload.type,
          payload.label,
        ),
      );
      return;
    }

    final tempFile = File(cached.path);
    try {
      if (!ExternalImportCatalog.supportsFileLabel(
        ExternalImportPayloadType.scriptSource,
        cached.label,
      )) {
        ExternalImportDiagnostics.logImportUnsupported(
          ExternalImportPayloadType.scriptSource,
          cached.label,
        );
        _showMessage(
          ExternalImportCatalog.unsupportedFileMessage(
            ExternalImportPayloadType.scriptSource,
            cached.label,
          ),
        );
        return;
      }

      await _importService.importCachedExternalFile(
        file: tempFile,
        saver: (sourceCode) {
          return _sourceRuntimeFacade.saveScriptSource(sourceCode: sourceCode);
        },
      );
      if (!mounted) {
        return;
      }
      ExternalImportDiagnostics.logImportSucceeded(
        ExternalImportPayloadType.scriptSource,
        cached.label,
      );
      _showMessage('已导入 ${cached.label}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ExternalImportDiagnostics.logImportFailed(
        ExternalImportPayloadType.scriptSource,
        cached.label,
        error,
      );
      _showMessage(
        ExternalImportDiagnostics.importFailedMessage(
          ExternalImportPayloadType.scriptSource,
          _toFriendlyImportError(error),
          label: cached.label,
        ),
      );
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
    _updateSourcePageState(() {
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
        _updateSourcePageState(() {
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

    _updateSourcePageState(() {
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
        _updateSourcePageState(() {
          _deletingScriptSourceIds.remove(source.id);
        });
      }
    }
  }
}
