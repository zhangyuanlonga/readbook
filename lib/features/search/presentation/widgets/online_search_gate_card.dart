import 'package:flutter/material.dart';

import '../../../../app/widgets/app_empty_state_card.dart';
import '../../../../app/widgets/foundation/app_progress.dart';

class OnlineSearchGateCard extends StatelessWidget {
  const OnlineSearchGateCard({
    super.key,
    required this.isChecking,
    required this.message,
    required this.onRetry,
  });

  final bool isChecking;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (isChecking) {
      return Center(
        child: AppProgressIndicator(
          size: 28,
          strokeWidth: 2.4,
          color: colorScheme.primary,
          semanticLabel: '检查在线搜索状态',
        ),
      );
    }

    return Center(
      child: AppEmptyStateCard(
        icon: Icons.search_off_rounded,
        title: '在线搜索暂不可用',
        description: message ?? '请检查登录状态或稍后重试。',
        actionLabel: '重试',
        onAction: onRetry,
      ),
    );
  }
}
