import 'package:flutter/material.dart';

import '../app_empty_state_card.dart';
import '../app_status_state_card.dart';
import 'app_button.dart';
import 'app_progress.dart';

enum AppViewStateKind {
  loading,
  refreshing,
  empty,
  filteredEmpty,
  error,
  locked,
  offline,
  progress,
  content,
}

class AppStateAction {
  const AppStateAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.tonal,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final AppButtonVariant variant;
}

class AppStateView extends StatelessWidget {
  const AppStateView({
    super.key,
    required this.kind,
    this.child,
    this.title,
    this.description,
    this.icon,
    this.progress,
    this.primaryAction,
    this.secondaryAction,
    this.footer,
    this.loadingSkeleton,
    this.compact = false,
  });

  final AppViewStateKind kind;
  final Widget? child;
  final String? title;
  final String? description;
  final IconData? icon;
  final double? progress;
  final AppStateAction? primaryAction;
  final AppStateAction? secondaryAction;
  final Widget? footer;
  final Widget? loadingSkeleton;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      AppViewStateKind.content => child ?? const SizedBox.shrink(),
      AppViewStateKind.refreshing => _buildRefreshing(context),
      AppViewStateKind.loading => loadingSkeleton ?? _buildProgressCard(),
      AppViewStateKind.progress => _buildProgressCard(),
      AppViewStateKind.empty ||
      AppViewStateKind.filteredEmpty => _buildEmpty(context),
      AppViewStateKind.error ||
      AppViewStateKind.locked ||
      AppViewStateKind.offline => _buildStatus(context),
    };
  }

  Widget _buildRefreshing(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppInlineProgress(
          label: title ?? '正在刷新',
          message: description,
          value: progress,
          compact: compact,
        ),
        if (child != null) ...[const SizedBox(height: 12), child!],
      ],
    );
  }

  Widget _buildProgressCard() {
    return AppBlockingProgressCard(
      title: title ?? '正在加载',
      message: description,
      value: progress,
      actionLabel: primaryAction?.label,
      onAction: primaryAction?.onPressed,
      compact: compact,
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return AppEmptyStateCard(
      icon:
          icon ??
          (kind == AppViewStateKind.filteredEmpty
              ? Icons.filter_alt_off_outlined
              : Icons.inbox_outlined),
      title: title ?? '暂无内容',
      description: description ?? '稍后再来看看。',
      actionLabel: primaryAction?.label,
      onAction: primaryAction?.onPressed,
      compact: compact,
      footer: _buildFooterActions(context),
    );
  }

  Widget _buildStatus(BuildContext context) {
    return AppStatusStateCard(
      icon: icon ?? _statusIcon,
      title: title ?? _statusTitle,
      message: description ?? _statusDescription,
      tone: _statusTone,
      actionLabel: primaryAction?.label,
      onAction: primaryAction?.onPressed,
      compact: compact,
      footer: _buildFooterActions(context),
    );
  }

  Widget? _buildFooterActions(BuildContext context) {
    final widgets = <Widget>[
      if (secondaryAction != null)
        AppButton(
          label: secondaryAction!.label,
          icon: secondaryAction!.icon,
          variant: secondaryAction!.variant,
          onPressed: secondaryAction!.onPressed,
        ),
      if (footer != null) footer!,
    ];
    if (widgets.isEmpty) {
      return null;
    }
    return Wrap(spacing: 8, runSpacing: 8, children: widgets);
  }

  IconData get _statusIcon {
    return switch (kind) {
      AppViewStateKind.error => Icons.error_outline_rounded,
      AppViewStateKind.locked => Icons.lock_outline_rounded,
      AppViewStateKind.offline => Icons.wifi_off_rounded,
      _ => Icons.info_outline_rounded,
    };
  }

  String get _statusTitle {
    return switch (kind) {
      AppViewStateKind.error => '加载失败',
      AppViewStateKind.locked => '暂不可用',
      AppViewStateKind.offline => '网络不可用',
      _ => '需要处理',
    };
  }

  String get _statusDescription {
    return switch (kind) {
      AppViewStateKind.error => '请稍后重试。',
      AppViewStateKind.locked => '当前账号暂时无法使用此能力。',
      AppViewStateKind.offline => '检查网络连接后再试。',
      _ => '请稍后重试。',
    };
  }

  AppStatusStateTone get _statusTone {
    return switch (kind) {
      AppViewStateKind.error => AppStatusStateTone.error,
      AppViewStateKind.locked => AppStatusStateTone.warning,
      AppViewStateKind.offline => AppStatusStateTone.warning,
      _ => AppStatusStateTone.neutral,
    };
  }
}
