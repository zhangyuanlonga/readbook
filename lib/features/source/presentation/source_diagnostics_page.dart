import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/layout/app_spacing.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/source_repository_impl.dart';
import '../../../domain/entities/source_definition.dart';
import '../../../domain/repositories/source_repository.dart';
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
  double _concurrency = 2;

  bool _isRunning = false;
  bool _isExporting = false;
  bool _isLoadingSourceFilters = false;
  SourceBatchDiagnosticToken? _activeToken;
  SourceBatchDiagnosticProgress? _progress;
  List<SourceDiagnosticReport> _reports = const [];
  List<SourceDefinition> _filterableSources = const [];
  Set<String> _selectedSourceIds = <String>{};

  @override
  void initState() {
    super.initState();
    _diagnosticsService = SourceDiagnosticsService(
      sourceRepository: _sourceRepository,
    );
    unawaited(_refreshSourceFilters());
  }

  @override
  void dispose() {
    _activeToken?.cancel();
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
            tooltip: '导出报告',
            onPressed: _isExporting ? null : _handleExportTap,
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
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          12,
          horizontal,
          16 + bottomSafe,
        ),
        children: [
          _buildConfigCard(),
          const SizedBox(height: 12),
          _buildProgressCard(),
          const SizedBox(height: 12),
          _buildResultList(),
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
    final allCount = _filterableSources.length;
    final selectedCount = _selectedSourceIds.length;

    final summaryText =
        allCount == 0
            ? '当前没有可用启用书源'
            : selectedCount == 0
            ? '书源: 全部启用 ($allCount)'
            : '书源: 指定 $selectedCount / $allCount';

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
          if (_isLoadingSourceFilters)
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
                  (_isRunning || allCount == 0)
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

  Future<void> _refreshSourceFilters() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingSourceFilters = true;
    });

    try {
      final enabled = await _diagnosticsService.loadEnabledSources();
      enabled.sort((a, b) => a.name.compareTo(b.name));

      if (!mounted) {
        return;
      }

      setState(() {
        _filterableSources = List.unmodifiable(enabled);
        _selectedSourceIds =
            _selectedSourceIds
                .where((id) => enabled.any((item) => item.id == id))
                .toSet();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSourceFilters = false;
        });
      }
    }
  }

  Future<void> _showSourceFilterSheet() async {
    if (_filterableSources.isEmpty) {
      _showMessage('当前没有可用启用书源。');
      return;
    }

    final initialSelected = <String>{..._selectedSourceIds};
    final keywordController = TextEditingController();

    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        var draftSelected = <String>{...initialSelected};

        return StatefulBuilder(
          builder: (context, setModalState) {
            final keyword = keywordController.text.trim().toLowerCase();
            final visibleSources = _filterableSources
                .where((source) {
                  if (keyword.isEmpty) {
                    return true;
                  }
                  return source.name.toLowerCase().contains(keyword) ||
                      source.baseUrl.toLowerCase().contains(keyword) ||
                      (source.group ?? '').toLowerCase().contains(keyword);
                })
                .toList(growable: false);

            return FractionallySizedBox(
              heightFactor: 0.85,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '指定书源',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: keywordController,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '搜索书源名称、域名或分组',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              draftSelected = <String>{};
                            });
                          },
                          child: const Text('全部启用'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              draftSelected =
                                  _filterableSources
                                      .map((item) => item.id)
                                      .toSet();
                            });
                          },
                          child: const Text('全选'),
                        ),
                        const Spacer(),
                        Text(
                          draftSelected.isEmpty
                              ? '当前：全部'
                              : '当前：${draftSelected.length} 个',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child:
                          visibleSources.isEmpty
                              ? Center(
                                child: Text(
                                  '未匹配到书源',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              )
                              : ListView.builder(
                                itemCount: visibleSources.length,
                                itemBuilder: (context, index) {
                                  final source = visibleSources[index];
                                  final selected = draftSelected.contains(
                                    source.id,
                                  );
                                  return CheckboxListTile(
                                    value: selected,
                                    dense: true,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    title: Text(
                                      source.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      source.baseUrl,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onChanged: (value) {
                                      setModalState(() {
                                        if (value ?? false) {
                                          draftSelected.add(source.id);
                                        } else {
                                          draftSelected.remove(source.id);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed:
                              () => Navigator.of(context).pop(draftSelected),
                          child: const Text('应用筛选'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    keywordController.dispose();

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

  Widget _buildResultList() {
    if (_reports.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text('暂无诊断结果。', style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }

    return Column(
      children: _reports
          .map((report) => _buildReportCard(report))
          .toList(growable: false),
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
      unawaited(_refreshSourceFilters());
      return;
    }

    final token = SourceBatchDiagnosticToken();

    setState(() {
      _isRunning = true;
      _activeToken = token;
      _reports = const [];
      _progress = SourceBatchDiagnosticProgress(
        total: targetSources.length,
        processed: 0,
        successCount: 0,
        failedCount: 0,
      );
    });

    try {
      final result = await _diagnosticsService.diagnoseBatch(
        sources: targetSources,
        keyword: keyword,
        mode: _mode,
        concurrency: _concurrency.toInt(),
        cancellationToken: token,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _progress = progress;
            if (progress.latestReport != null) {
              _reports = [..._reports, progress.latestReport!];
            }
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _reports = result;
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
      if (mounted) {
        setState(() {
          _isRunning = false;
          _activeToken = null;
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
                subtitle: const Text('包含每个书源的完整诊断结果与原始源数据'),
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
        return AlertDialog(
          title: Text('诊断详情 - ${report.sourceName}'),
          content: SizedBox(
            width: 420,
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
          XTypeGroup(label: 'JSON', extensions: ['json']),
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
