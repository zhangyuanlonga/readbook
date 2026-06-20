import 'package:flutter/material.dart';

import 'app_button.dart';
import 'app_surface.dart';

class AppProgressIndicator extends StatelessWidget {
  const AppProgressIndicator({
    super.key,
    this.value,
    this.size = 22,
    this.strokeWidth = 2.6,
    this.minHeight,
    this.color,
    this.backgroundColor,
    this.linear = false,
    this.semanticLabel,
  });

  final double? value;
  final double size;
  final double strokeWidth;
  final double? minHeight;
  final Color? color;
  final Color? backgroundColor;
  final bool linear;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final normalizedValue = value?.clamp(0.0, 1.0).toDouble();
    final progress =
        linear
            ? LinearProgressIndicator(
              value: normalizedValue,
              minHeight: minHeight,
              color: color,
              backgroundColor: backgroundColor,
            )
            : SizedBox.square(
              dimension: size,
              child: CircularProgressIndicator(
                value: normalizedValue,
                strokeWidth: strokeWidth,
                color: color,
                backgroundColor: backgroundColor,
              ),
            );
    if (semanticLabel == null) {
      return progress;
    }
    return Semantics(
      label: semanticLabel,
      value:
          normalizedValue == null
              ? null
              : '${(normalizedValue * 100).round()}%',
      child: progress,
    );
  }
}

class AppInlineProgress extends StatelessWidget {
  const AppInlineProgress({
    super.key,
    required this.label,
    this.value,
    this.message,
    this.trailing,
    this.compact = false,
  });

  final String label;
  final double? value;
  final String? message;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        AppProgressIndicator(
          value: value,
          size: compact ? 18 : 22,
          semanticLabel: label,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 2),
                Text(
                  message!,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

class AppBlockingProgressCard extends StatelessWidget {
  const AppBlockingProgressCard({
    super.key,
    required this.title,
    this.message,
    this.value,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String? message;
  final double? value;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppSurface(
      tone: AppSurfaceTone.muted,
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppProgressIndicator(
            value: value,
            size: compact ? 24 : 30,
            semanticLabel: title,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          if (value != null) ...[
            const SizedBox(height: 12),
            AppProgressIndicator(
              value: value,
              linear: true,
              semanticLabel: title,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            AppButton(
              label: actionLabel!,
              variant: AppButtonVariant.tonal,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

class AppTaskProgressRow extends StatelessWidget {
  const AppTaskProgressRow({
    super.key,
    required this.title,
    this.message,
    this.value,
    this.onCancel,
  });

  final String title;
  final String? message;
  final double? value;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return AppInlineProgress(
      label: title,
      message: message,
      value: value,
      trailing:
          onCancel == null
              ? null
              : IconButton(
                tooltip: '取消',
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded),
              ),
    );
  }
}
