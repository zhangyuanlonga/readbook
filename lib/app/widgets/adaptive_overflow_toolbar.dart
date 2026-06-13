import 'package:flutter/material.dart';

import '../layout/app_adaptive.dart';
import 'foundation/foundation.dart';

class AdaptiveOverflowToolbarItem {
  const AdaptiveOverflowToolbarItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.priority = 0,
    this.tooltip,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final int priority;
  final String? tooltip;
  final bool enabled;
}

class AdaptiveOverflowToolbar extends StatelessWidget {
  const AdaptiveOverflowToolbar({
    super.key,
    required this.items,
    this.spacing,
    this.itemWidth = 44,
    this.moreTooltip = '更多',
  });

  final List<AdaptiveOverflowToolbarItem> items;
  final double? spacing;
  final double itemWidth;
  final String moreTooltip;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final resolvedSpacing = spacing ?? metrics.contentGap;
    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleItems = _visibleItemsFor(
          constraints.maxWidth,
          resolvedSpacing,
        );
        final hiddenItems = items
            .where((item) => !visibleItems.contains(item))
            .toList(growable: false);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < visibleItems.length; index++) ...[
              if (index > 0) SizedBox(width: resolvedSpacing),
              _ToolbarIconButton(item: visibleItems[index]),
            ],
            if (hiddenItems.isNotEmpty) ...[
              if (visibleItems.isNotEmpty) SizedBox(width: resolvedSpacing),
              _ToolbarMoreButton(items: hiddenItems, tooltip: moreTooltip),
            ],
          ],
        );
      },
    );
  }

  List<AdaptiveOverflowToolbarItem> _visibleItemsFor(
    double availableWidth,
    double spacing,
  ) {
    if (items.isEmpty || availableWidth <= 0) {
      return const <AdaptiveOverflowToolbarItem>[];
    }

    final sorted = [...items]..sort((a, b) {
      final priority = b.priority.compareTo(a.priority);
      if (priority != 0) {
        return priority;
      }
      return items.indexOf(a).compareTo(items.indexOf(b));
    });
    final maxSlots = ((availableWidth + spacing) / (itemWidth + spacing))
        .floor()
        .clamp(0, items.length);
    if (maxSlots >= items.length) {
      return items;
    }
    if (maxSlots <= 0) {
      return const <AdaptiveOverflowToolbarItem>[];
    }

    final visibleSlotCount = (maxSlots - 1).clamp(0, items.length);
    final visibleSet = sorted.take(visibleSlotCount).toSet();
    return items.where(visibleSet.contains).toList(growable: false);
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({required this.item});

  final AdaptiveOverflowToolbarItem item;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: item.tooltip ?? item.label,
      onPressed: item.enabled ? item.onPressed : null,
      icon: Icon(item.icon),
    );
    return SizedBox(width: 44, height: 44, child: button);
  }
}

class _ToolbarMoreButton extends StatelessWidget {
  const _ToolbarMoreButton({required this.items, required this.tooltip});

  final List<AdaptiveOverflowToolbarItem> items;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return AppMenuButton<AdaptiveOverflowToolbarItem>(
      tooltip: tooltip,
      icon: Icons.more_horiz_rounded,
      onSelected: (item) {
        if (item.enabled) {
          item.onPressed?.call();
        }
      },
      actions: items
          .map(
            (item) => AppMenuAction<AdaptiveOverflowToolbarItem>(
              value: item,
              label: item.label,
              icon: item.icon,
              enabled: item.enabled,
            ),
          )
          .toList(growable: false),
    );
  }
}
