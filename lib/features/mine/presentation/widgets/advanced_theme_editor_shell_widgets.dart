import 'package:flutter/material.dart';

class AdvancedThemeSectionLabel extends StatelessWidget {
  const AdvancedThemeSectionLabel({
    super.key,
    required this.title,
    this.tooltipMessage,
  });

  final String title;
  final String? tooltipMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: _AdvancedThemeSectionTitle(title: title)),
          if (tooltipMessage != null && tooltipMessage!.trim().isNotEmpty) ...[
            const SizedBox(width: 4),
            AdvancedThemeInfoTooltipIcon(message: tooltipMessage!),
          ],
        ],
      ),
    );
  }
}

class AdvancedThemeExpandableSectionHeader extends StatelessWidget {
  const AdvancedThemeExpandableSectionHeader({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    this.tooltipMessage,
  });

  final String title;
  final String? tooltipMessage;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: _AdvancedThemeSectionTitle(title: title)),
                  if (tooltipMessage != null &&
                      tooltipMessage!.trim().isNotEmpty) ...[
                    const SizedBox(width: 4),
                    AdvancedThemeInfoTooltipIcon(message: tooltipMessage!),
                  ],
                ],
              ),
            ),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class AdvancedThemePanel extends StatelessWidget {
  const AdvancedThemePanel({
    super.key,
    required this.child,
    this.backgroundColor,
    this.padding = const EdgeInsets.fromLTRB(10, 8, 10, 8),
  });

  final Widget child;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: child,
    );
  }
}

class AdvancedThemeListSectionBody extends StatelessWidget {
  const AdvancedThemeListSectionBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: child,
    );
  }
}

class AdvancedThemeInfoTooltipIcon extends StatefulWidget {
  const AdvancedThemeInfoTooltipIcon({super.key, required this.message});

  final String message;

  @override
  State<AdvancedThemeInfoTooltipIcon> createState() =>
      _AdvancedThemeInfoTooltipIconState();
}

class _AdvancedThemeInfoTooltipIconState
    extends State<AdvancedThemeInfoTooltipIcon> {
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

  void _showTooltip() {
    _tooltipKey.currentState?.ensureTooltipVisible();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _showTooltip(),
      child: Tooltip(
        key: _tooltipKey,
        message: widget.message,
        triggerMode: TooltipTriggerMode.tap,
        waitDuration: Duration.zero,
        showDuration: const Duration(seconds: 3),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showTooltip,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              Icons.help_outline_rounded,
              size: 14,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdvancedThemeSectionTitle extends StatelessWidget {
  const _AdvancedThemeSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
