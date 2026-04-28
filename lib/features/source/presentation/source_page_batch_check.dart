part of 'source_page.dart';

extension on _SourcePageState {
  Future<void> _runSingleCheck(ScriptSource source) async {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: _SingleCheckFlowSheet(
              sourceName: source.name,
              helperText:
                  '默认建议先执行 searchOnly。留空时优先使用该书源的 checkKeyword，未配置则回退到系统默认关键词。',
              initialKeyword:
                  source.checkKeyword ?? SourceCheckService.defaultCheckKeyword,
              levelLabelBuilder: _checkLevelLabel,
              statusLabelBuilder: _checkStatusLabel,
              stepLabelBuilder: _checkStepLabel,
              onRun: (keyword, level) {
                return _sourceCheckService.checkSource(
                  sourceId: source.id,
                  keyword: keyword,
                  level: level,
                );
              },
              onCompleted: () {
                if (mounted) {
                  _updateSourcePageState(() {});
                }
              },
            ),
          ),
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
                    <SourceCheckResult>[...progress.value.results, result],
                  ),
                );
                if (mounted) {
                  _updateSourcePageState(() {});
                }
              },
            );
            progress.value = progress.value.copyWith(
              finished: true,
              currentSourceName: null,
              results: List<SourceCheckResult>.unmodifiable(results),
            );
            if (mounted) {
              _updateSourcePageState(() {});
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
                    .where(
                      (result) => result.status == SourceCheckStatus.healthy,
                    )
                    .length;
            final warningCount =
                results
                    .where(
                      (result) => result.status == SourceCheckStatus.warning,
                    )
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
    _updateSourcePageState(() {
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

}
