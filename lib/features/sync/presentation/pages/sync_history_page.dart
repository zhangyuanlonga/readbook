import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_adaptive.dart';
import '../../../../app/layout/app_layout.dart';
import '../../domain/sync_conflict.dart';
import '../../domain/sync_job.dart';
import '../../domain/sync_scope.dart';
import '../../providers.dart';

class SyncHistoryPage extends ConsumerWidget {
  const SyncHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(syncJobsProvider);
    final conflictsAsync = ref.watch(syncConflictsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('同步历史')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppLayout.pageContentMaxWidth(context, maxWidth: 760),
          ),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppAdaptiveMetrics.of(context).pagePadding,
              AppAdaptiveMetrics.of(context).contentGap,
              AppAdaptiveMetrics.of(context).pagePadding,
              AppAdaptiveMetrics.of(context).sectionGap +
                  MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              _Section(
                title: '最近任务',
                child: jobsAsync.when(
                  data: (jobs) {
                    if (jobs.isEmpty) {
                      return const Text('当前没有同步任务。');
                    }
                    return Column(
                      children: [
                        for (final job in jobs.take(20)) _JobTile(job: job),
                      ],
                    );
                  },
                  error: (error, _) => Text('加载任务失败：$error'),
                  loading: () => const _LoadingLine('正在加载任务…'),
                ),
              ),
              SizedBox(height: AppAdaptiveMetrics.of(context).contentGap),
              _Section(
                title: '最近冲突',
                child: conflictsAsync.when(
                  data: (conflicts) {
                    if (conflicts.isEmpty) {
                      return const Text('当前没有冲突记录。');
                    }
                    return Column(
                      children: [
                        for (final conflict in conflicts.take(20))
                          _ConflictTile(conflict: conflict),
                      ],
                    );
                  },
                  error: (error, _) => Text('加载冲突失败：$error'),
                  loading: () => const _LoadingLine('正在加载冲突…'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(metrics.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: metrics.contentGap),
            child,
          ],
        ),
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job});

  final SyncJob job;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(job.profileId),
      subtitle: Text('${job.status.name} · ${job.startedAt.toLocal()}'),
      onTap: () => _showJobDetail(context),
      trailing:
          job.status == SyncJobStatus.success
              ? const Icon(Icons.check_circle_outline)
              : job.status == SyncJobStatus.failed
              ? const Icon(Icons.error_outline)
              : const Icon(Icons.sync),
    );
  }

  void _showJobDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final metrics = AppAdaptiveMetrics.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.pagePadding,
              metrics.sectionGap,
              metrics.pagePadding,
              metrics.sectionGap,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '任务详情',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: metrics.contentGap),
                _JobDetailLine(label: '配置', value: job.profileId),
                _JobDetailLine(label: '状态', value: job.status.name),
                _JobDetailLine(label: '触发方式', value: job.triggerKind.name),
                _JobDetailLine(
                  label: '开始时间',
                  value: job.startedAt.toLocal().toString(),
                ),
                if (job.endedAt != null)
                  _JobDetailLine(
                    label: '结束时间',
                    value: job.endedAt!.toLocal().toString(),
                  ),
                if ((job.summaryJson ?? '').trim().isNotEmpty)
                  _JobDetailLine(label: '摘要', value: job.summaryJson!),
                if ((job.errorMessage ?? '').trim().isNotEmpty)
                  _JobDetailLine(label: '错误', value: job.errorMessage!),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _JobDetailLine extends StatelessWidget {
  const _JobDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}

class _ConflictTile extends StatelessWidget {
  const _ConflictTile({required this.conflict});

  final SyncConflict conflict;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(conflict.scope.productLabel),
      subtitle: Text(
        '${conflict.recordKey}\n${conflict.resolution.name} · ${conflict.createdAt.toLocal()}',
      ),
      trailing: const Icon(Icons.compare_arrows_outlined),
    );
  }
}

class _LoadingLine extends StatelessWidget {
  const _LoadingLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
