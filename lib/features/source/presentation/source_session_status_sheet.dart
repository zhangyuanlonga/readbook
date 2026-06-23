import 'package:flutter/material.dart';

import '../../../app/widgets/foundation/foundation.dart';
import '../application/source_runtime_session_service.dart';

enum SourceSessionStatusAction { login, clear }

class SourceSessionStatusSheet extends StatelessWidget {
  const SourceSessionStatusSheet({
    super.key,
    required this.sourceName,
    required this.snapshot,
    this.showActions = true,
  });

  final String sourceName;
  final SourceRuntimeSessionSnapshot snapshot;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = sourceName.trim().isEmpty ? '书源登录状态' : '$sourceName 登录状态';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _StatusRow(label: 'Cookie', active: snapshot.hasCookie),
            _StatusRow(label: 'Header', active: snapshot.hasHeaders),
            _StatusRow(label: 'loginInfo', active: snapshot.hasLoginInfo),
            _StatusRow(
              label: 'sourceVariable',
              active: snapshot.hasSourceVariable,
            ),
            const SizedBox(height: 12),
            _InfoText(label: 'Cookie 范围', value: snapshot.cookieScope),
            _InfoText(label: '会话策略', value: snapshot.sessionPolicy),
            _InfoText(label: 'TTL', value: _ttlText(snapshot.ttlSeconds)),
            _InfoText(label: '更新时间', value: _updatedAtText(snapshot.updatedAt)),
            if (snapshot.headerNames.isNotEmpty)
              _InfoText(
                label: 'Header 名称',
                value: snapshot.headerNames.join(', '),
              ),
            if (showActions) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      variant: AppButtonVariant.secondary,
                      onPressed:
                          () => Navigator.of(
                            context,
                          ).pop(SourceSessionStatusAction.clear),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: '清除',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      onPressed:
                          () => Navigator.of(
                            context,
                          ).pop(SourceSessionStatusAction.login),
                      icon: const Icon(Icons.login_rounded),
                      label: '重新登录',
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 18),
              AppButton(
                expanded: true,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check_rounded),
                label: '完成',
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _ttlText(int seconds) {
    if (seconds <= 0) return '-';
    if (seconds < 60) return '$seconds 秒';
    if (seconds < 3600) return '${(seconds / 60).round()} 分钟';
    return '${(seconds / 3600).toStringAsFixed(1)} 小时';
  }

  String _updatedAtText(int? value) {
    if (value == null || value <= 0) return '-';
    final milliseconds = value > 9999999999 ? value : value * 1000;
    final time = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = active ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            active ? '已保存' : '无',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '$label：${value.trim().isEmpty ? '-' : value}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
