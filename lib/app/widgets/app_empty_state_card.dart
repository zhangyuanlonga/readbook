import 'package:flutter/material.dart';

const double _kEmptyStateHorizontalPadding = 18;
const double _kEmptyStateVerticalPadding = 24;
const double _kEmptyStateCompactVerticalPadding = 20;
const double _kEmptyStateIconSize = 34;
const double _kEmptyStateCompactIconSize = 30;
const double _kEmptyStateRadius = 18;
const double _kEmptyStateTitleGap = 10;
const double _kEmptyStateCompactTitleGap = 8;
const double _kEmptyStateSectionGap = 12;
const double _kEmptyStateDescriptionGap = 6;

class AppEmptyStateCard extends StatelessWidget {
  const AppEmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.trailing,
    this.footer,
    this.centered = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;
  final Widget? trailing;
  final Widget? footer;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconSize =
        compact ? _kEmptyStateCompactIconSize : _kEmptyStateIconSize;
    final verticalPadding =
        compact
            ? _kEmptyStateCompactVerticalPadding
            : _kEmptyStateVerticalPadding;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        _kEmptyStateHorizontalPadding,
        verticalPadding,
        _kEmptyStateHorizontalPadding,
        verticalPadding,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(_kEmptyStateRadius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing == null) ...[
            Icon(icon, size: iconSize, color: colorScheme.primary),
            SizedBox(
              height:
                  compact ? _kEmptyStateCompactTitleGap : _kEmptyStateTitleGap,
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: iconSize, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                trailing!,
              ],
            ),
          ],
          const SizedBox(height: _kEmptyStateDescriptionGap),
          Text(
            description,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: _kEmptyStateSectionGap),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(actionLabel!),
              style: TextButton.styleFrom(
                visualDensity: const VisualDensity(
                  horizontal: -1,
                  vertical: -1,
                ),
              ),
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: _kEmptyStateSectionGap),
            footer!,
          ],
        ],
      ),
    );
  }
}
