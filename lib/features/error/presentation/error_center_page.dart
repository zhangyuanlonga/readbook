import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../core/logging/source_log_store.dart';

class ErrorCenterPage extends StatefulWidget {
  const ErrorCenterPage({super.key});

  @override
  State<ErrorCenterPage> createState() => _ErrorCenterPageState();
}

class _ErrorCenterPageState extends State<ErrorCenterPage> {
  final SourceLogStore _store = SourceLogStore.instance;
  bool _includeInfoLogs = false;

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('错误中心'),
        actions: [
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
                  final entries = allEntries
                      .where(
                        (entry) =>
                            _includeInfoLogs || entry.level != AppLogLevel.info,
                      )
                      .toList(growable: false);

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      16,
                      horizontal,
                      16 + bottomSafe,
                    ),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '已记录 ${allEntries.length} 条日志（当前展示 ${entries.length} 条）',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 10),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('包含 INFO 日志'),
                                value: _includeInfoLogs,
                                onChanged: (value) {
                                  setState(() {
                                    _includeInfoLogs = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              const Text('日志包含时间、阶段、书享源、请求地址，可用于问题排查。'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (entries.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('暂无错误日志。'),
                          ),
                        )
                      else
                        ...entries.map(_buildLogCard),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogCard(AppLogEntry entry) {
    final details = entry.details;
    final levelColor = _levelColor(context, entry.level);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
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

  void _clearLogs() {
    _store.clear();
    _showMessage('日志已清空。');
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
