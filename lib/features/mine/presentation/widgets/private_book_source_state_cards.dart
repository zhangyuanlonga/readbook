import 'package:flutter/material.dart';

import '../../../../app/widgets/app_empty_state_card.dart';
import '../../../../app/widgets/foundation/app_progress.dart';

class PrivateBookSourceEmptySourcesCard extends StatelessWidget {
  const PrivateBookSourceEmptySourcesCard({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return AppEmptyStateCard(
      icon: Icons.library_books_outlined,
      title: '还没有私人书源',
      description: '可以导入自己的 Legado JSON 书源，并按私人分组维护。',
      actionLabel: '新增书源',
      onAction: onCreate,
    );
  }
}

class PrivateBookSourceLoginRequiredCard extends StatelessWidget {
  const PrivateBookSourceLoginRequiredCard({super.key, required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return AppEmptyStateCard(
      icon: Icons.lock_outline_rounded,
      title: '请登录后查看',
      description: '私人书源、分组和额度会跟随账号同步，登录后即可管理。',
      actionLabel: '去登录',
      onAction: onLogin,
    );
  }
}

class PrivateBookSourceFilterEmptyCard extends StatelessWidget {
  const PrivateBookSourceFilterEmptyCard({
    super.key,
    required this.keyword,
    required this.onClear,
  });

  final String keyword;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AppEmptyStateCard(
      icon: Icons.manage_search_outlined,
      title: '没有匹配的书源',
      description: keyword.trim().isEmpty ? '当前分组暂无书源。' : keyword.trim(),
      actionLabel: '清空搜索',
      onAction: onClear,
      compact: true,
    );
  }
}

class PrivateBookSourceLoadingCard extends StatelessWidget {
  const PrivateBookSourceLoadingCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            const AppProgressIndicator(
              size: 20,
              strokeWidth: 2,
              semanticLabel: '加载私人书源',
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class PrivateBookSourceErrorCard extends StatelessWidget {
  const PrivateBookSourceErrorCard({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyStateCard(
      icon: Icons.error_outline_rounded,
      title: title,
      description: message,
      actionLabel: '重试',
      onAction: onRetry,
      compact: true,
      centered: false,
    );
  }
}
