import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_spacing.dart';
import '../application/reader_error_center_service.dart';

class ReaderErrorCenterPage extends StatefulWidget {
  const ReaderErrorCenterPage({super.key});

  @override
  State<ReaderErrorCenterPage> createState() => _ReaderErrorCenterPageState();
}

class _ReaderErrorCenterPageState extends State<ReaderErrorCenterPage> {
  final ReaderErrorCenterService _service = ReaderErrorCenterService.instance;

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('阅读异常中心'),
        actions: [
          IconButton(
            tooltip: '清空',
            onPressed: _service.records.isEmpty ? null : _service.clear,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: StreamBuilder<List<ReaderFailureRecord>>(
        stream: _service.watch(),
        initialData: _service.records,
        builder: (context, snapshot) {
          final records = snapshot.data ?? const <ReaderFailureRecord>[];

          if (records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  '最近没有阅读失败记录。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              12,
              horizontal,
              16 + bottomSafe,
            ),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = records[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.bookTitle?.trim().isNotEmpty == true
                            ? item.bookTitle!.trim()
                            : item.bookId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.chapterLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.shortMessage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            _formatTime(item.occurredAt),
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _retry(item),
                            icon: const Icon(Icons.replay_rounded, size: 18),
                            label: const Text('一键重试'),
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
      ),
    );
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$min';
  }

  void _retry(ReaderFailureRecord item) {
    final chapterUrl = item.chapterUrl?.trim() ?? '';
    final sourceId = item.sourceId?.trim() ?? '';
    final detailUrl = item.detailUrl?.trim() ?? '';

    if (chapterUrl.isEmpty || sourceId.isEmpty || detailUrl.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('缺少重试参数，无法自动重试。')));
      return;
    }

    _service.remove(item.id);
    context.pushNamed(
      'reader',
      pathParameters: {'bookId': item.bookId, 'chapterId': item.chapterId},
      queryParameters: {
        'chapterUrl': chapterUrl,
        'chapterTitle': item.chapterTitle,
        'sourceId': sourceId,
        'detailUrl': detailUrl,
      },
    );
  }
}
