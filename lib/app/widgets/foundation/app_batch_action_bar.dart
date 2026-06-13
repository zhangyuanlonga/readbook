import 'package:flutter/material.dart';

import '../../layout/app_adaptive.dart';
import '../../theme/app_component_theme_tokens.dart';
import '../adaptive_bottom_sheet.dart';
import 'app_button.dart';

enum AppBatchActionTone { neutral, destructive }

class AppBatchActionConfirmation {
  const AppBatchActionConfirmation({
    required this.title,
    required this.message,
    this.confirmLabel = '确认',
    this.cancelLabel = '取消',
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
}

class AppBatchAction {
  const AppBatchAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tone = AppBatchActionTone.neutral,
    this.enabled = true,
    this.confirmation,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final AppBatchActionTone tone;
  final bool enabled;
  final AppBatchActionConfirmation? confirmation;
}

class AppBatchActionBar extends StatelessWidget {
  const AppBatchActionBar({
    super.key,
    required this.selectedCount,
    required this.actions,
    this.totalCount,
    this.enabled = true,
    this.onSelectAll,
    this.onClearSelection,
    this.selectedLabelBuilder,
    this.selectAllLabel = '全选',
    this.clearLabel = '取消选择',
    this.showWhenEmpty = false,
  }) : assert(selectedCount >= 0),
       assert(totalCount == null || totalCount >= 0);

  final int selectedCount;
  final int? totalCount;
  final List<AppBatchAction> actions;
  final bool enabled;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClearSelection;
  final String Function(int selectedCount, int? totalCount)?
  selectedLabelBuilder;
  final String selectAllLabel;
  final String clearLabel;
  final bool showWhenEmpty;

  @override
  Widget build(BuildContext context) {
    if (selectedCount == 0 && !showWhenEmpty) {
      return const SizedBox.shrink();
    }

    final metrics = AppAdaptiveMetrics.of(context);
    final tokens = appComponentThemeTokensOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    final selectedLabel =
        selectedLabelBuilder?.call(selectedCount, totalCount) ??
        _defaultSelectedLabel();
    final summary = _BatchSelectionSummary(
      selectedLabel: selectedLabel,
      selectedCount: selectedCount,
    );
    final actionWrap = _buildActionWrap(context);

    final content =
        metrics.isCompactWindow
            ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                summary,
                SizedBox(height: metrics.contentGap),
                actionWrap,
              ],
            )
            : Row(
              children: [
                Expanded(child: summary),
                SizedBox(width: metrics.contentGap),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: actionWrap,
                  ),
                ),
              ],
            );

    return Semantics(
      container: true,
      liveRegion: selectedCount > 0,
      label: selectedLabel,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(metrics.isCompactDensity ? 12 : 14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(tokens.card.radius),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.58),
              width: tokens.card.borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _buildActionWrap(BuildContext context) {
    final actionButtons = <Widget>[
      if (onSelectAll != null)
        AppButton(
          label: selectAllLabel,
          icon: const Icon(Icons.select_all_rounded),
          variant: AppButtonVariant.secondary,
          onPressed: enabled ? onSelectAll : null,
        ),
      if (onClearSelection != null)
        AppButton(
          label: clearLabel,
          icon: const Icon(Icons.close_rounded),
          variant: AppButtonVariant.text,
          onPressed: enabled ? onClearSelection : null,
        ),
      ...actions.map((action) {
        return AppButton(
          label: action.label,
          icon: Icon(action.icon),
          variant:
              action.tone == AppBatchActionTone.destructive
                  ? AppButtonVariant.danger
                  : AppButtonVariant.tonal,
          onPressed:
              enabled && action.enabled && action.onPressed != null
                  ? () {
                    _handleAction(context, action);
                  }
                  : null,
        );
      }),
    ];

    return Wrap(spacing: 8, runSpacing: 8, children: actionButtons);
  }

  String _defaultSelectedLabel() {
    final total = totalCount;
    if (total == null || total <= 0) {
      return '已选择 $selectedCount 项';
    }
    return '已选择 $selectedCount / $total 项';
  }

  Future<void> _handleAction(
    BuildContext context,
    AppBatchAction action,
  ) async {
    final confirmation = action.confirmation;
    if (confirmation != null) {
      final confirmed = await showAppBatchActionConfirmation(
        context: context,
        title: confirmation.title,
        message: confirmation.message,
        confirmLabel: confirmation.confirmLabel,
        cancelLabel: confirmation.cancelLabel,
        destructive: action.tone == AppBatchActionTone.destructive,
      );
      if (!context.mounted || confirmed != true) {
        return;
      }
    }
    action.onPressed?.call();
  }
}

Future<bool?> showAppBatchActionConfirmation({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = '确认',
  String cancelLabel = '取消',
  bool destructive = true,
}) {
  return showAdaptiveActionSurface<bool>(
    context: context,
    builder:
        (context) => _AppBatchActionConfirmationSurface(
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
          destructive: destructive,
        ),
  );
}

class _BatchSelectionSummary extends StatelessWidget {
  const _BatchSelectionSummary({
    required this.selectedLabel,
    required this.selectedCount,
  });

  final String selectedLabel;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          selectedCount > 0
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color:
              selectedCount > 0
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            selectedLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _AppBatchActionConfirmationSurface extends StatelessWidget {
  const _AppBatchActionConfirmationSurface({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: metrics.contentGap),
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        SizedBox(height: metrics.sectionGap),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(
              label: cancelLabel,
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: confirmLabel,
              icon:
                  destructive
                      ? const Icon(Icons.delete_outline_rounded)
                      : const Icon(Icons.check_rounded),
              variant:
                  destructive
                      ? AppButtonVariant.danger
                      : AppButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ],
    );
  }
}
