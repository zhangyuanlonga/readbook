import 'package:flutter/material.dart';

import '../../../../app/widgets/app_empty_state_card.dart';

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
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: colorScheme.primary,
          ),
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
