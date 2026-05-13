import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/platform/app_platform_capabilities.dart';
import '../../../app/widgets/app_empty_state_card.dart';
import '../../../app/widgets/import_export_task_overlay.dart';
import '../../../core/logging/diagnostic_log_export_service.dart';
import '../../../core/logging/source_log_store.dart';

class ErrorCenterPage extends ConsumerStatefulWidget {
  const ErrorCenterPage({super.key});

  @override
  ConsumerState<ErrorCenterPage> createState() => _ErrorCenterPageState();
}

class _ErrorCenterPageState extends ConsumerState<ErrorCenterPage> {
  final SourceLogStore _store = SourceLogStore.instance;
  final DiagnosticLogExportService _exportService =
      DiagnosticLogExportService();
  bool _includeInfoLogs = false;
  bool _isExporting = false;
  ImportExportTaskStatus? _taskStatus;
  int _selectedEntryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final horizontal = metrics.pagePadding;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final capabilities = ref.watch(appPlatformCapabilitiesProvider);

    return ImportExportTaskOverlay(
      status: _taskStatus,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('诊断日志'),
          actions: [
            IconButton(
              onPressed: _isExporting ? null : _shareLogs,
              tooltip: '导出日志',
              icon:
                  _isExporting
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.ios_share_outlined),
            ),
            IconButton(
              onPressed: _copyLogs,
              tooltip: '复制日志',
              icon: const Icon(Icons.copy_all_outlined),
            ),
            IconButton(
              onPressed: _clearLogs,
              tooltip: '清空日志',
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, _) {
            final maxWidth = AppLayout.pageContentMaxWidth(
              context,
              maxWidth: AppLayout.errorCenterContentMaxWidth,
            );

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: StreamBuilder<List<AppLogEntry>>(
                  stream: _store.watch(),
                  initialData: _store.entries,
                  builder: (context, snapshot) {
                    final allEntries = snapshot.data ?? const <AppLogEntry>[];
                    final viewportHeight = MediaQuery.sizeOf(context).height;
                    final useWideLogLayout =
                        metrics.isMediumUpWindow && viewportHeight >= 560;
                    final entries = allEntries
                        .where(
                          (entry) =>
                              _includeInfoLogs ||
                              entry.level != AppLogLevel.info,
                        )
                        .toList(growable: false);

                    if (_selectedEntryIndex >= entries.length) {
                      _selectedEntryIndex =
                          entries.isEmpty ? 0 : entries.length - 1;
                    }

                    return AppFadeSlideTransition(
                      child:
                          useWideLogLayout
                              ? _buildDesktopLogViewer(
                                context,
                                allEntries: allEntries,
                                entries: entries,
                                supportsManagedFileStorage:
                                    capabilities.supportsManagedFileStorage,
                                horizontal: horizontal,
                                bottomSafe: bottomSafe,
                              )
                              : _buildMobileLogList(
                                context,
                                allEntries: allEntries,
                                entries: entries,
                                supportsManagedFileStorage:
                                    capabilities.supportsManagedFileStorage,
                                horizontal: horizontal,
                                bottomSafe: bottomSafe,
                              ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDiagnosticCapabilityNotice() {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(metrics.cardRadius),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colorScheme.secondary),
          SizedBox(width: metrics.contentGap),
          Expanded(
            child: Text(
              '当前平台不暴露可管理文件路径，诊断日志会优先复制为文本；支持系统分享的平台会继续生成可分享文件。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLogList(
    BuildContext context, {
    required List<AppLogEntry> allEntries,
    required List<AppLogEntry> entries,
    required bool supportsManagedFileStorage,
    required double horizontal,
    required double bottomSafe,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            metrics.sectionGap,
            horizontal,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                _buildLogSummaryCard(
                  context,
                  allEntries: allEntries,
                  entries: entries,
                ),
                SizedBox(height: metrics.contentGap),
                if (!supportsManagedFileStorage) ...[
                  _buildDiagnosticCapabilityNotice(),
                  SizedBox(height: metrics.contentGap),
                ],
                if (entries.isEmpty)
                  const AppEmptyStateCard(
                    icon: Icons.event_note_outlined,
                    title: '暂无错误日志',
                    description: '当前没有可展示的错误日志记录。',
                    compact: true,
                  ),
              ],
            ),
          ),
        ),
        if (entries.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              0,
              horizontal,
              metrics.sectionGap + bottomSafe,
            ),
            sliver: SliverList.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) => _buildLogCard(entries[index]),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.only(bottom: metrics.sectionGap + bottomSafe),
          ),
      ],
    );
  }

  Widget _buildDesktopLogViewer(
    BuildContext context, {
    required List<AppLogEntry> allEntries,
    required List<AppLogEntry> entries,
    required bool supportsManagedFileStorage,
    required double horizontal,
    required double bottomSafe,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    final selected =
        entries.isEmpty
            ? null
            : entries[_selectedEntryIndex.clamp(0, entries.length - 1)];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        metrics.sectionGap,
        horizontal,
        metrics.sectionGap + bottomSafe,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 340,
            child: Column(
              children: [
                _buildLogSummaryCard(
                  context,
                  allEntries: allEntries,
                  entries: entries,
                  compact: true,
                ),
                if (!supportsManagedFileStorage) ...[
                  SizedBox(height: metrics.contentGap),
                  _buildDiagnosticCapabilityNotice(),
                ],
                SizedBox(height: metrics.contentGap),
                Expanded(
                  child:
                      entries.isEmpty
                          ? const AppEmptyStateCard(
                            icon: Icons.event_note_outlined,
                            title: '暂无错误日志',
                            description: '当前没有可展示的错误日志记录。',
                            compact: true,
                          )
                          : Card(
                            clipBehavior: Clip.antiAlias,
                            child: ListView.separated(
                              itemCount: entries.length,
                              separatorBuilder:
                                  (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                return _buildLogListTile(
                                  context,
                                  entry: entry,
                                  selected: index == _selectedEntryIndex,
                                  onTap:
                                      () => setState(() {
                                        _selectedEntryIndex = index;
                                      }),
                                );
                              },
                            ),
                          ),
                ),
              ],
            ),
          ),
          SizedBox(width: metrics.contentGap),
          Expanded(
            child:
                selected == null
                    ? const AppEmptyStateCard(
                      icon: Icons.article_outlined,
                      title: '选择一条日志',
                      description: '左侧列表会展示可诊断的日志记录。',
                      compact: true,
                    )
                    : _buildLogDetailPanel(context, selected),
          ),
        ],
      ),
    );
  }

  Widget _buildLogSummaryCard(
    BuildContext context, {
    required List<AppLogEntry> allEntries,
    required List<AppLogEntry> entries,
    bool compact = false,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(metrics.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '已记录 ${allEntries.length} 条日志（当前展示 ${entries.length} 条）',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: compact ? 6 : 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: compact,
              title: const Text('包含 INFO 日志'),
              value: _includeInfoLogs,
              onChanged: (value) {
                setState(() {
                  _includeInfoLogs = value;
                  _selectedEntryIndex = 0;
                });
              },
            ),
            if (!compact) ...[
              const SizedBox(height: 8),
              const Text('日志会保存在本地，可导出为文本并通过微信、QQ、邮件发送给开发者。'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogListTile(
    BuildContext context, {
    required AppLogEntry entry,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final levelColor = _levelColor(context, entry.level);
    return ListTile(
      selected: selected,
      selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.35),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Icon(Icons.circle, size: 10, color: levelColor),
      title: Text(entry.message, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${entry.level.name.toUpperCase()} · ${entry.timestamp.toLocal()}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }

  Widget _buildLogDetailPanel(BuildContext context, AppLogEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;
    final levelColor = _levelColor(context, entry.level);
    final details = entry.details.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListView(
        padding: EdgeInsets.all(AppAdaptiveMetrics.of(context).cardPadding),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  entry.level.name.toUpperCase(),
                  style: TextStyle(
                    color: levelColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.timestamp.toLocal().toString(),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SelectableText(
            entry.message,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          if (details.isEmpty)
            Text('无附加上下文', style: Theme.of(context).textTheme.bodySmall)
          else
            for (final item in details)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SelectableText('${item.key}: ${item.value}'),
              ),
        ],
      ),
    );
  }

  Widget _buildLogCard(AppLogEntry entry) {
    final details = entry.details;
    final levelColor = _levelColor(context, entry.level);

    return Card(
      margin: EdgeInsets.only(
        bottom: AppAdaptiveMetrics.of(context).contentGap,
      ),
      child: Padding(
        padding: EdgeInsets.all(AppAdaptiveMetrics.of(context).cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    entry.level.name.toUpperCase(),
                    style: TextStyle(
                      color: levelColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.timestamp.toLocal().toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(entry.message, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (details.isEmpty)
              Text('无附加上下文', style: Theme.of(context).textTheme.bodySmall)
            else
              ...details.entries.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: SelectableText('${item.key}: ${item.value}'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _levelColor(BuildContext context, AppLogLevel level) {
    return switch (level) {
      AppLogLevel.info => Theme.of(context).colorScheme.primary,
      AppLogLevel.warn => Theme.of(context).colorScheme.tertiary,
      AppLogLevel.error => Theme.of(context).colorScheme.error,
    };
  }

  Future<void> _copyLogs() async {
    final text = _store.exportText(includeInfo: _includeInfoLogs);
    if (text.trim().isEmpty) {
      _showMessage('暂无可复制日志。');
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    _showMessage('日志已复制到剪贴板。');
  }

  Future<void> _shareLogs() async {
    if (_isExporting) {
      return;
    }
    setState(() {
      _isExporting = true;
      _taskStatus = const ImportExportTaskStatus(
        title: '正在导出日志',
        message: '正在整理诊断日志并生成可分享文件…',
      );
    });

    try {
      final exportResult = await _exportService.export(
        includeInfo: _includeInfoLogs,
      );
      if (exportResult == null) {
        _showMessage('暂无可导出日志。');
        return;
      }

      final exportFile = exportResult.file;
      if (exportFile == null) {
        await Clipboard.setData(ClipboardData(text: exportResult.text));
        _showMessage('当前平台暂不支持生成诊断文件，已复制完整日志文本。');
        return;
      }

      try {
        final result = await Share.shareXFiles(
          [XFile(exportFile.path)],
          text: '请把这份诊断日志发给开发者。安装标识：${exportResult.identity.installId}',
          subject: '诊断日志 ${exportResult.identity.appVersion}',
          sharePositionOrigin: _resolveSharePositionOrigin(),
        );
        if (result.status == ShareResultStatus.dismissed && mounted) {
          _showMessage('已生成日志文件，分享已取消。');
        }
      } on MissingPluginException {
        await Clipboard.setData(ClipboardData(text: exportResult.text));
        _showMessage('当前安装包暂不支持系统分享，已复制完整日志文本。');
      }
    } catch (error) {
      _showMessage('导出日志失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _taskStatus = null;
        });
      }
    }
  }

  void _clearLogs() {
    _store.clear();
    _showMessage('日志已清空。');
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
    return renderObject.localToGlobal(Offset.zero) & size;
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
