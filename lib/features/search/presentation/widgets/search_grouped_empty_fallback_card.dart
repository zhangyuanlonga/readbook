import 'package:flutter/material.dart';

import '../../../../app/widgets/app_status_state_card.dart';

class SearchGroupedEmptyFallbackCard extends StatelessWidget {
  const SearchGroupedEmptyFallbackCard({
    super.key,
    required this.canDisablePrecise,
    required this.canSwitchAllSources,
    required this.onDisablePreciseMatch,
    required this.onSwitchAllSources,
  });

  final bool canDisablePrecise;
  final bool canSwitchAllSources;
  final VoidCallback onDisablePreciseMatch;
  final VoidCallback onSwitchAllSources;

  @override
  Widget build(BuildContext context) {
    final emptyTip =
        canDisablePrecise
            ? '当前分组无结果，可尝试关闭精准匹配或切换全部书源。'
            : canSwitchAllSources
            ? '当前筛选书源无结果，可切换全部书源后重试。'
            : '暂无可展示结果，请检查书源配置或更换关键词。';

    return AppStatusStateCard(
      icon: Icons.search_off_rounded,
      title: '暂无匹配结果',
      message: emptyTip,
      tone: AppStatusStateTone.neutral,
      compact: true,
      footer:
          canDisablePrecise || canSwitchAllSources
              ? Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canDisablePrecise)
                    FilledButton.tonalIcon(
                      onPressed: onDisablePreciseMatch,
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                      label: const Text('关闭精准匹配'),
                    ),
                  if (canSwitchAllSources)
                    OutlinedButton.icon(
                      onPressed: onSwitchAllSources,
                      icon: const Icon(Icons.travel_explore_rounded, size: 18),
                      label: const Text('切换全部书源'),
                    ),
                ],
              )
              : null,
    );
  }
}
