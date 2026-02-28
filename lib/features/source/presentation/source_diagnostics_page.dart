import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/source_repository_impl.dart';
import '../../../domain/entities/source_definition.dart';
import '../../../domain/repositories/source_repository.dart';
import 'source_filter_sheet.dart';
import '../application/source_diagnostics_service.dart';

class SourceDiagnosticsPage extends StatefulWidget {
  const SourceDiagnosticsPage({super.key});

  @override
  State<SourceDiagnosticsPage> createState() => _SourceDiagnosticsPageState();
}

enum _ExportPayloadKind { fullReport, groupedFailures }

class _SourceDiagnosticsPageState extends State<SourceDiagnosticsPage> {
  final SourceRepository _sourceRepository = SourceRepositoryImpl(
    AppDatabase.instance,
  );
  final TextEditingController _keywordController = TextEditingController(
    text: '凡人修仙传',
  );

  late final SourceDiagnosticsService _diagnosticsService;

  SourceDiagnosticMode _mode = SourceDiagnosticMode.fullChainQuick;
  bool _enableStagedPipeline = true;
  double _concurrency = 2;

  bool _isRunning = false;
  bool _isExporting = false;
  bool _isPurgingInvalidSources = false;
  bool _isLoadingSourceCount = false;
  SourceBatchDiagnosticToken? _activeToken;
  SourceBatchDiagnosticProgress? _progress;
  String? _pipelineStageLabel;
  List<SourceDiagnosticReport> _reports = const [];
  SourceBatchDiagnosticProgress? _pendingProgress;
  final List<SourceDiagnosticReport> _pendingReports =
      <SourceDiagnosticReport>[];
  Timer? _progressFlushTimer;
  int _availableSourceCount = 0;
  Set<String> _selectedSourceIds = <String>{};

  static const Duration _kSourceCountLoadTimeout = Duration(seconds: 8);
  static const Duration _kProgressFlushInterval = Duration(milliseconds: 220);
  static const int _kProgressFlushBatchSize = 20;
  static final RegExp _kHardInvalidStatusPattern = RegExp(
    r'(?:(?:状态码)|(?:status\s*code)|(?:statuscode))\s*[:：=]?\s*(404|410)\b',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _diagnosticsService = SourceDiagnosticsService(
      sourceRepository: _sourceRepository,
    );
    unawaited(_refreshSourceCount());
  }

  @override
  void dispose() {
    _activeToken?.cancel();
    _stopProgressFlushTimer();
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('批量诊断'),
        actions: [
          IconButton(
            tooltip: '清理失效源（404/410）',
            onPressed:
                (_isRunning || _isExporting || _isPurgingInvalidSources)
                    ? null
                    : () => unawaited(_purgeHardInvalidSources()),
            icon:
                _isPurgingInvalidSources
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.delete_sweep_outlined),
          ),
          IconButton(
            tooltip: '导出报告',
            onPressed:
                (_isExporting || _isPurgingInvalidSources)
                    ? null
                    : _handleExportTap,
            icon:
                _isExporting
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 0),
            sliver: SliverToBoxAdapter(child: _buildConfigCard()),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 0),
            sliver: SliverToBoxAdapter(child: _buildProgressCard()),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              12,
              horizontal,
              16 + bottomSafe,
            ),
            sliver: _buildResultSliver(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '诊断配置',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            SegmentedButton<SourceDiagnosticMode>(
              segments: const [
                ButtonSegment(
                  value: SourceDiagnosticMode.probe,
                  label: Text('探活'),
                  icon: Icon(Icons.network_check_rounded),
                ),
                ButtonSegment(
                  value: SourceDiagnosticMode.searchOnly,
                  label: Text('搜索'),
                  icon: Icon(Icons.manage_search_rounded),
                ),
                ButtonSegment(
                  value: SourceDiagnosticMode.fullChainQuick,
                  label: Text('全链路'),
                  icon: Icon(Icons.fact_check_outlined),
                ),
              ],
              selected: <SourceDiagnosticMode>{_mode},
              showSelectedIcon: false,
              onSelectionChanged:
                  _isRunning
                      ? null
                      : (selection) {
                        if (selection.isEmpty) {
                          return;
                        }
                        setState(() {
                          _mode = selection.first;
                        });
                      },
            ),
            if (_mode == SourceDiagnosticMode.fullChainQuick) ...[
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('三阶段流水线（推荐）'),
                subtitle: const Text('自动按 探活→搜索→全链路 执行，逐层筛掉失败源'),
                value: _enableStagedPipeline,
                onChanged:
                    _isRunning
                        ? null
                        : (value) {
                          setState(() {
                            _enableStagedPipeline = value;
                          });
                        },
              ),
            ],
            const SizedBox(height: 10),
            _buildSourceFilterRow(),
            const SizedBox(height: 10),
            TextField(
              controller: _keywordController,
              enabled: !_isRunning,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '测试关键词',
                hintText: '例如：凡人修仙传',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '并发：${_concurrency.toInt()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Slider(
                    value: _concurrency,
                    min: 1,
                    max: 6,
                    divisions: 5,
                    label: _concurrency.toInt().toString(),
                    onChanged:
                        _isRunning
                            ? null
                            : (value) {
                              setState(() {
                                _concurrency = value;
                              });
                            },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isRunning ? _cancelDiagnostics : _runDiagnostics,
                icon: Icon(
                  _isRunning
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline,
                ),
                label: Text(_isRunning ? '取消批量诊断' : '开始批量诊断'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceFilterRow() {
    final selectedCount = _selectedSourceIds.length;

    final summaryText =
        _isLoadingSourceCount && _availableSourceCount == 0
            ? '书源: 统计中...'
            : _availableSourceCount == 0
            ? '当前没有可用启用书源'
            : selectedCount == 0
            ? '书源: 全部启用 ($_availableSourceCount)'
            : '书源: 指定 $selectedCount / $_availableSourceCount';

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
          if (_isLoadingSourceCount)
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
                    _isRunning
                        ? null
                        : () {
                          setState(() {
                            _selectedSourceIds = <String>{};
                            _reports = const [];
                            _progress = null;
                          });
                        },
                icon: const Icon(Icons.clear_rounded, size: 18),
              ),
            TextButton.icon(
              onPressed:
                  (_isRunning || _availableSourceCount == 0)
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

  Future<void> _refreshSourceCount() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingSourceCount = true;
    });

    try {
      final count = await AppDatabase.instance
          .countSourceListItems(enabledOnly: true)
          .timeout(_kSourceCountLoadTimeout);

      if (!mounted) {
        return;
      }

      setState(() {
        _availableSourceCount = count;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _availableSourceCount = 0;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSourceCount = false;
        });
      }
    }
  }

  Future<void> _showSourceFilterSheet() async {
    final selected = await showSourceFilterSheet(
      context: context,
      config: SourceFilterSheetConfig(
        initialSelectedIds: _selectedSourceIds,
        enabledOnly: true,
        allSelectionLabel: '全部启用',
        allSummaryLabel: '全部启用',
      ),
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _selectedSourceIds = selected;
      _reports = const [];
      _progress = null;
    });
  }

  Widget _buildProgressCard() {
    final progress = _progress;
    if (progress == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text('尚未开始诊断。', style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }

    final ratio =
        progress.total == 0 ? 0.0 : progress.processed / progress.total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isRunning ? '诊断进行中' : '诊断已完成',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '进度 ${progress.processed}/${progress.total} | 成功 ${progress.successCount} | 失败 ${progress.failedCount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_pipelineStageLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                '阶段: $_pipelineStageLabel',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (progress.currentSourceName != null) ...[
              const SizedBox(height: 4),
              Text(
                '当前: ${progress.currentSourceName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            LinearProgressIndicator(value: ratio),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSliver() {
    if (_reports.isEmpty) {
      return SliverToBoxAdapter(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              '暂无诊断结果。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        return _buildReportCard(_reports[index]);
      }, childCount: _reports.length),
    );
  }

  Widget _buildReportCard(SourceDiagnosticReport report) {
    final failed = report.failedStages;
    final statusText = report.isSuccess ? '通过' : '失败 ${failed.length} 阶段';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _showReportDetail(report),
        leading: Icon(
          report.isSuccess
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
          color:
              report.isSuccess
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
        ),
        title: Text(
          report.sourceName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_modeLabel(report.mode)} | $statusText',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  void _startProgressFlushTimer() {
    _stopProgressFlushTimer();
    _progressFlushTimer = Timer.periodic(_kProgressFlushInterval, (_) {
      _flushPendingProgress();
    });
  }

  void _stopProgressFlushTimer() {
    _progressFlushTimer?.cancel();
    _progressFlushTimer = null;
  }

  void _enqueueProgress(SourceBatchDiagnosticProgress progress) {
    _pendingProgress = progress;
    final latest = progress.latestReport;
    if (latest != null) {
      _pendingReports.add(latest);
    }
    if (_pendingReports.length >= _kProgressFlushBatchSize) {
      _flushPendingProgress(force: true);
    }
  }

  void _flushPendingProgress({bool force = false}) {
    if (!mounted) {
      _pendingReports.clear();
      _pendingProgress = null;
      return;
    }
    if (_pendingProgress == null && _pendingReports.isEmpty) {
      return;
    }

    final shouldSkip =
        !force &&
        _pendingReports.isEmpty &&
        _pendingProgress != null &&
        _progress != null &&
        _pendingProgress!.processed == _progress!.processed;
    if (shouldSkip) {
      return;
    }

    setState(() {
      if (_pendingProgress != null) {
        _progress = _pendingProgress;
        _pendingProgress = null;
      }
      if (_pendingReports.isNotEmpty) {
        _reports.addAll(_pendingReports);
        _pendingReports.clear();
      }
    });
  }

  Future<List<SourceDiagnosticReport>> _runBatchStep({
    required String stageLabel,
    required List<SourceDefinition> sources,
    required String keyword,
    required SourceDiagnosticMode mode,
    required SourceBatchDiagnosticToken token,
    required bool streamStepReports,
  }) async {
    if (!mounted || !_isRunning) {
      return const <SourceDiagnosticReport>[];
    }

    setState(() {
      _pipelineStageLabel = stageLabel;
      _progress = SourceBatchDiagnosticProgress(
        total: sources.length,
        processed: 0,
        successCount: 0,
        failedCount: 0,
      );
    });

    if (sources.isEmpty) {
      return const <SourceDiagnosticReport>[];
    }

    final reports = await _diagnosticsService.diagnoseBatch(
      sources: sources,
      keyword: keyword,
      mode: mode,
      rawPolicy: SourceDiagnosticRawPolicy.failedOnly,
      concurrency: _concurrency.toInt(),
      cancellationToken: token,
      onProgress: (progress) {
        if (!mounted || !_isRunning) {
          return;
        }
        if (streamStepReports) {
          _enqueueProgress(progress);
          return;
        }
        _enqueueProgress(
          SourceBatchDiagnosticProgress(
            total: progress.total,
            processed: progress.processed,
            successCount: progress.successCount,
            failedCount: progress.failedCount,
            currentSourceId: progress.currentSourceId,
            currentSourceName: progress.currentSourceName,
          ),
        );
      },
    );
    _flushPendingProgress(force: true);
    return reports;
  }

  List<SourceDefinition> _filterSucceededSources({
    required List<SourceDefinition> sourceScope,
    required List<SourceDiagnosticReport> reports,
  }) {
    final succeededIds =
        reports
            .where((item) => item.isSuccess)
            .map((item) => item.sourceId)
            .toSet();
    if (succeededIds.isEmpty) {
      return const <SourceDefinition>[];
    }
    return sourceScope
        .where((item) => succeededIds.contains(item.id))
        .toList(growable: false);
  }

  List<SourceDiagnosticReport> _orderedReportsBySource({
    required List<SourceDefinition> sourceOrder,
    required List<SourceDiagnosticReport> reports,
  }) {
    final byId = <String, SourceDiagnosticReport>{};
    for (final report in reports) {
      byId[report.sourceId] = report;
    }
    return sourceOrder
        .map((item) => byId[item.id])
        .whereType<SourceDiagnosticReport>()
        .toList(growable: false);
  }

  Future<void> _runDiagnostics() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      _showMessage('请输入测试关键词。');
      return;
    }

    final selectedSourceIds = _selectedSourceIds.toList(growable: false);
    final targetSources = await _diagnosticsService.loadEnabledSources(
      sourceIds: selectedSourceIds.isEmpty ? null : selectedSourceIds,
    );

    if (targetSources.isEmpty) {
      final text =
          selectedSourceIds.isEmpty
              ? '没有可用于批量诊断的启用书源。'
              : '已选书源中没有可用于批量诊断的启用书源。';
      _showMessage(text);
      unawaited(_refreshSourceCount());
      return;
    }

    final token = SourceBatchDiagnosticToken();
    _pendingReports.clear();
    _pendingProgress = null;

    setState(() {
      _isRunning = true;
      _activeToken = token;
      _reports = <SourceDiagnosticReport>[];
      _pipelineStageLabel = null;
      _progress = SourceBatchDiagnosticProgress(
        total: targetSources.length,
        processed: 0,
        successCount: 0,
        failedCount: 0,
      );
    });
    _startProgressFlushTimer();

    try {
      List<SourceDiagnosticReport> result;
      final usePipeline =
          _enableStagedPipeline && _mode == SourceDiagnosticMode.fullChainQuick;
      if (usePipeline) {
        final mergedBySource = <String, SourceDiagnosticReport>{};

        final probeReports = await _runBatchStep(
          stageLabel: '探活（1/3）',
          sources: targetSources,
          keyword: keyword,
          mode: SourceDiagnosticMode.probe,
          token: token,
          streamStepReports: false,
        );
        for (final report in probeReports) {
          mergedBySource[report.sourceId] = report;
        }

        if (!token.isCancelled) {
          final probePassedSources = _filterSucceededSources(
            sourceScope: targetSources,
            reports: probeReports,
          );
          final searchReports = await _runBatchStep(
            stageLabel: '搜索（2/3）',
            sources: probePassedSources,
            keyword: keyword,
            mode: SourceDiagnosticMode.searchOnly,
            token: token,
            streamStepReports: false,
          );
          for (final report in searchReports) {
            mergedBySource[report.sourceId] = report;
          }

          if (!token.isCancelled) {
            final searchPassedSources = _filterSucceededSources(
              sourceScope: probePassedSources,
              reports: searchReports,
            );
            final fullReports = await _runBatchStep(
              stageLabel: '全链路（3/3）',
              sources: searchPassedSources,
              keyword: keyword,
              mode: SourceDiagnosticMode.fullChainQuick,
              token: token,
              streamStepReports: true,
            );
            for (final report in fullReports) {
              mergedBySource[report.sourceId] = report;
            }
          }
        }

        result = _orderedReportsBySource(
          sourceOrder: targetSources,
          reports: mergedBySource.values.toList(growable: false),
        );
      } else {
        result = await _runBatchStep(
          stageLabel: _modeLabel(_mode),
          sources: targetSources,
          keyword: keyword,
          mode: _mode,
          token: token,
          streamStepReports: true,
        );
      }

      _flushPendingProgress(force: true);

      if (!mounted) {
        return;
      }

      setState(() {
        _reports = List<SourceDiagnosticReport>.of(result);
      });

      if (token.isCancelled) {
        _showMessage('已取消批量诊断。');
      } else {
        final failed = result.where((item) => !item.isSuccess).length;
        _showMessage('诊断完成：共 ${result.length} 个书源，失败 $failed 个。');
      }
    } on AppException catch (error) {
      _showMessage(error.briefMessage);
    } catch (error) {
      _showMessage('批量诊断失败：$error');
    } finally {
      _stopProgressFlushTimer();
      _pendingReports.clear();
      _pendingProgress = null;
      if (mounted) {
        setState(() {
          _isRunning = false;
          _activeToken = null;
          _pipelineStageLabel = null;
        });
      }
    }
  }

  void _cancelDiagnostics() {
    if (!_isRunning) {
      return;
    }

    _activeToken?.cancel();
    _showMessage('正在取消诊断，已完成结果可先导出。');
  }

  Future<void> _purgeHardInvalidSources() async {
    if (_isPurgingInvalidSources) {
      return;
    }

    final reportsSnapshot = List<SourceDiagnosticReport>.from(_reports);
    if (reportsSnapshot.isEmpty) {
      _showMessage('暂无诊断结果，无法清理失效书源。');
      return;
    }

    final candidates = _collectHardInvalidSourceCandidates(reportsSnapshot);
    if (candidates.isEmpty) {
      _showMessage('当前结果中没有可清理的失效书源（HTTP 404/410）。');
      return;
    }

    final previewNames = candidates
        .take(5)
        .map((item) => item.sourceName.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final previewText =
        previewNames.isEmpty
            ? ''
            : '\n示例：${previewNames.join('、')}${candidates.length > previewNames.length ? ' 等' : ''}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('清理失效书源'),
          content: Text(
            '仅清理本次诊断中命中 HTTP 404/410 的书源。\n\n'
            '预计清理 ${candidates.length} 个书源。$previewText\n\n'
            '该操作不可恢复，建议先导出报告。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认清理'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isPurgingInvalidSources = true;
    });

    try {
      final ids = candidates
          .map((item) => item.sourceId)
          .where((id) => id.trim().isNotEmpty)
          .toSet()
          .toList(growable: false);
      if (ids.isEmpty) {
        _showMessage('无有效书源可清理。');
        return;
      }

      await _sourceRepository.deleteByIds(ids);

      if (!mounted) {
        return;
      }

      final idSet = ids.toSet();
      setState(() {
        _reports = reportsSnapshot
            .where((report) => !idSet.contains(report.sourceId))
            .toList(growable: false);
        _selectedSourceIds =
            _selectedSourceIds.where((id) => !idSet.contains(id)).toSet();
        _progress = null;
      });

      await _refreshSourceCount();
      _showMessage('已清理失效书源 ${ids.length} 个（HTTP 404/410）。');
    } catch (error) {
      _showMessage('清理失效书源失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isPurgingInvalidSources = false;
        });
      }
    }
  }

  List<_HardInvalidSourceCandidate> _collectHardInvalidSourceCandidates(
    List<SourceDiagnosticReport> reports,
  ) {
    final byId = <String, _HardInvalidSourceCandidate>{};

    for (final report in reports) {
      final isHardInvalid = report.failedStages.any(_isHardInvalidStageFailure);
      if (!isHardInvalid) {
        continue;
      }

      final sourceId = report.sourceId.trim();
      if (sourceId.isEmpty) {
        continue;
      }

      byId[sourceId] = _HardInvalidSourceCandidate(
        sourceId: sourceId,
        sourceName: report.sourceName,
      );
    }

    return byId.values.toList(growable: false);
  }

  bool _isHardInvalidStageFailure(SourceDiagnosticStageResult stage) {
    if (stage.success || stage.code != ErrorCode.network) {
      return false;
    }

    final message = stage.message?.trim() ?? '';
    if (message.isEmpty) {
      return false;
    }

    return _kHardInvalidStatusPattern.hasMatch(message);
  }

  Future<void> _handleExportTap() async {
    if (_reports.isEmpty) {
      _showMessage('暂无报告可导出。');
      return;
    }

    final kind = await _showExportKindSheet();
    if (kind == null) {
      return;
    }

    switch (kind) {
      case _ExportPayloadKind.fullReport:
        unawaited(_exportReports());
        break;
      case _ExportPayloadKind.groupedFailures:
        unawaited(_exportGroupedFailures());
        break;
    }
  }

  Future<_ExportPayloadKind?> _showExportKindSheet() {
    return showModalBottomSheet<_ExportPayloadKind>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('导出完整报告'),
                subtitle: const Text('包含每个书源的诊断结果；原始源数据默认仅失败源保留'),
                onTap: () {
                  Navigator.of(context).pop(_ExportPayloadKind.fullReport);
                },
              ),
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('按失败类型聚合导出'),
                subtitle: const Text('按 阶段 + 错误码 + 错误信息 聚合，便于批量修源'),
                onTap: () {
                  Navigator.of(context).pop(_ExportPayloadKind.groupedFailures);
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showReportDetail(SourceDiagnosticReport report) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        final maxWidth = AppLayout.dialogMaxWidth(context, maxWidth: 560);

        return AlertDialog(
          title: Text('诊断详情 - ${report.sourceName}'),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('模式：${_modeLabel(report.mode)}'),
                  const SizedBox(height: 4),
                  Text('关键词：${report.keyword}'),
                  if (report.sampleBookTitle != null) ...[
                    const SizedBox(height: 4),
                    Text('样本书籍：${report.sampleBookTitle}'),
                  ],
                  const SizedBox(height: 8),
                  ...report.stages.map((stage) {
                    final title = _stageLabel(stage.stage);
                    final status = stage.success ? '成功' : '失败';
                    final code = stage.code?.name ?? '-';
                    final message = stage.message ?? '-';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color:
                              stage.success
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer
                                  : Theme.of(
                                    context,
                                  ).colorScheme.errorContainer,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$title - $status (${stage.durationMs}ms)'),
                            const SizedBox(height: 2),
                            Text('错误码: $code'),
                            const SizedBox(height: 2),
                            Text('信息: $message'),
                            if (stage.requestUrl != null &&
                                stage.requestUrl!.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              SelectableText('URL: ${stage.requestUrl}'),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
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

  Future<void> _exportReports() {
    return _exportPayload(kind: _ExportPayloadKind.fullReport);
  }

  Future<void> _exportGroupedFailures() {
    return _exportPayload(kind: _ExportPayloadKind.groupedFailures);
  }

  Future<void> _exportPayload({required _ExportPayloadKind kind}) async {
    if (_isExporting) {
      return;
    }

    final reportsSnapshot = List<SourceDiagnosticReport>.from(_reports);
    if (reportsSnapshot.isEmpty) {
      _showMessage('暂无报告可导出。');
      return;
    }

    if (kind == _ExportPayloadKind.groupedFailures) {
      final hasFailed = reportsSnapshot.any((item) => !item.isSuccess);
      if (!hasFailed) {
        _showMessage('当前没有失败书源，无需导出失败聚合。');
        return;
      }
    }

    setState(() {
      _isExporting = true;
    });

    final suggestedName = switch (kind) {
      _ExportPayloadKind.fullReport =>
        'source_diagnostics_${_timestampToken()}.json',
      _ExportPayloadKind.groupedFailures =>
        'source_diagnostics_failure_groups_${_timestampToken()}.json',
    };

    try {
      final outputPath = await _resolveExportTargetPath(suggestedName);
      if (outputPath == null || outputPath.trim().isEmpty) {
        _showMessage('已取消导出。');
        return;
      }

      final payload = switch (kind) {
        _ExportPayloadKind.fullReport => _buildFullExportPayload(
          reportsSnapshot,
        ),
        _ExportPayloadKind.groupedFailures => _buildGroupedFailurePayload(
          reportsSnapshot,
        ),
      };

      final file = File(outputPath.trim());
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      final content = const JsonEncoder.withIndent('  ').convert(payload);
      await file.writeAsString(content, flush: true);

      switch (kind) {
        case _ExportPayloadKind.fullReport:
          _showMessage('导出成功：${file.path}（共 ${reportsSnapshot.length} 条）');
          break;
        case _ExportPayloadKind.groupedFailures:
          final groups = payload['groups'];
          final count = groups is List ? groups.length : 0;
          _showMessage('导出成功：${file.path}（失败类型 $count 组）');
          break;
      }
    } catch (error) {
      _showMessage('导出失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Map<String, dynamic> _buildFullExportPayload(
    List<SourceDiagnosticReport> reportsSnapshot,
  ) {
    return {
      'schema': 'flutter_appread.source_diagnostics.v1',
      'exportedAt': DateTime.now().toIso8601String(),
      'mode': _mode.name,
      'keyword': _keywordController.text.trim(),
      'summary': {
        'total': reportsSnapshot.length,
        'success': reportsSnapshot.where((item) => item.isSuccess).length,
        'failed': reportsSnapshot.where((item) => !item.isSuccess).length,
      },
      'reports': reportsSnapshot
          .map((item) => item.toJson())
          .toList(growable: false),
    };
  }

  Map<String, dynamic> _buildGroupedFailurePayload(
    List<SourceDiagnosticReport> reportsSnapshot,
  ) {
    final groups = <String, _FailureGroupAccumulator>{};
    var failedSourceCount = 0;
    var failedStageCount = 0;

    for (final report in reportsSnapshot) {
      final failedStages = report.failedStages;
      if (failedStages.isEmpty) {
        continue;
      }

      failedSourceCount += 1;

      for (final stage in failedStages) {
        failedStageCount += 1;

        final code = stage.code?.name ?? ErrorCode.unknown.name;
        final message = _normalizeFailureMessage(stage.message);
        final key = '${stage.stage.name}|$code|$message';
        final group = groups.putIfAbsent(
          key,
          () => _FailureGroupAccumulator(
            stage: stage.stage,
            code: code,
            message: message,
          ),
        );

        group.items.add({
          'sourceId': report.sourceId,
          'sourceName': report.sourceName,
          'mode': report.mode.name,
          'keyword': report.keyword,
          'startedAt': report.startedAt.toIso8601String(),
          'finishedAt': report.finishedAt.toIso8601String(),
          'durationMs': stage.durationMs,
          'requestUrl': stage.requestUrl,
          'sample': {
            'bookTitle': report.sampleBookTitle,
            'detailUrl': report.sampleDetailUrl,
            'chapterTitle': report.sampleChapterTitle,
            'chapterUrl': report.sampleChapterUrl,
          },
          'sourceRaw': report.sourceRaw,
        });
      }
    }

    final sortedGroups = groups.values.toList(growable: false)..sort((a, b) {
      final count = b.count.compareTo(a.count);
      if (count != 0) {
        return count;
      }
      final stage = a.stage.name.compareTo(b.stage.name);
      if (stage != 0) {
        return stage;
      }
      return a.code.compareTo(b.code);
    });

    return {
      'schema': 'flutter_appread.source_diagnostics.failure_groups.v1',
      'exportedAt': DateTime.now().toIso8601String(),
      'mode': _mode.name,
      'keyword': _keywordController.text.trim(),
      'groupBy': ['stage', 'code', 'message'],
      'summary': {
        'total': reportsSnapshot.length,
        'failedSourceCount': failedSourceCount,
        'failedStageCount': failedStageCount,
        'failureTypeCount': sortedGroups.length,
      },
      'groups': sortedGroups
          .map((item) => item.toJson())
          .toList(growable: false),
    };
  }

  String _normalizeFailureMessage(String? rawMessage) {
    final text = rawMessage?.trim() ?? '';
    if (text.isEmpty) {
      return '未提供错误信息';
    }

    return text;
  }

  Future<String?> _resolveExportTargetPath(String suggestedName) async {
    try {
      final saveLocation = await getSaveLocation(
        suggestedName: suggestedName,
        confirmButtonText: '保存报告',
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

  String _modeLabel(SourceDiagnosticMode mode) {
    return switch (mode) {
      SourceDiagnosticMode.probe => '探活',
      SourceDiagnosticMode.searchOnly => '搜索',
      SourceDiagnosticMode.fullChainQuick => '全链路',
    };
  }

  String _stageLabel(SourceDiagnosticStage stage) {
    return switch (stage) {
      SourceDiagnosticStage.search => '搜索',
      SourceDiagnosticStage.detail => '详情',
      SourceDiagnosticStage.toc => '目录',
      SourceDiagnosticStage.content => '正文',
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

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _HardInvalidSourceCandidate {
  const _HardInvalidSourceCandidate({
    required this.sourceId,
    required this.sourceName,
  });

  final String sourceId;
  final String sourceName;
}

class _FailureGroupAccumulator {
  _FailureGroupAccumulator({
    required this.stage,
    required this.code,
    required this.message,
  });

  final SourceDiagnosticStage stage;
  final String code;
  final String message;
  final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];

  int get count => items.length;

  Map<String, dynamic> toJson() {
    return {
      'failureType': {'stage': stage.name, 'code': code, 'message': message},
      'count': count,
      'sources': List<Map<String, dynamic>>.unmodifiable(items),
    };
  }
}
