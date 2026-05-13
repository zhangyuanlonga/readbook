import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../application/mine_page_preferences_service.dart';
import '../../providers.dart';

class AppearanceOtherSettingsCard extends ConsumerStatefulWidget {
  const AppearanceOtherSettingsCard({super.key});

  @override
  ConsumerState<AppearanceOtherSettingsCard> createState() =>
      _AppearanceOtherSettingsCardState();
}

class _AppearanceOtherSettingsCardState
    extends ConsumerState<AppearanceOtherSettingsCard> {
  final GlobalKey<PopupMenuButtonState<MinePageStartupDestination>>
  _startupMenuKey =
      GlobalKey<PopupMenuButtonState<MinePageStartupDestination>>();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final startupDestination = ref.watch(minePageStartupDestinationProvider);
    final visibilityState = ref.watch(minePageVisibilityProvider);
    final visibleCount =
        configurableMinePageItemDefinitions
            .where((definition) => visibilityState.isVisible(definition.id))
            .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.widgets_outlined,
                  size: 16,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '其他',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '补充我的页面显示项和应用启动入口配置。',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildActionTile(
            context,
            icon: Icons.view_list_outlined,
            title: '我的页面显示内容',
            subtitle: '自定义我的页面中显示的功能项',
            trailingText: '$visibleCount 项显示中',
            onTap: _openMinePageDisplaySheet,
          ),
          Divider(
            height: 17,
            color: colorScheme.outlineVariant.withValues(alpha: 0.32),
          ),
          _buildActionTile(
            context,
            icon: Icons.rocket_launch_outlined,
            title: '启动项',
            subtitle: '选择应用启动时的默认页面',
            onTap: _openStartupDestinationMenu,
            trailing: PopupMenuButton<MinePageStartupDestination>(
              key: _startupMenuKey,
              tooltip: '选择启动项',
              onSelected: _setStartupDestination,
              itemBuilder: (context) {
                return [
                  for (final destination in MinePageStartupDestination.values)
                    PopupMenuItem<MinePageStartupDestination>(
                      value: destination,
                      child: Row(
                        children: [
                          Expanded(child: Text(destination.label)),
                          if (startupDestination == destination)
                            Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                ];
              },
              child: _buildStartupSelector(context, startupDestination),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? trailingText,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (trailing != null)
                trailing
              else ...[
                if (trailingText != null)
                  Text(
                    trailingText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (trailingText != null) const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMinePageDisplaySheet() async {
    await showAdaptiveActionSurface<void>(
      context: context,
      maxWidth: 680,
      maxHeightFactor: 0.84,
      padding: EdgeInsets.zero,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.74,
          child: Consumer(
            builder: (context, ref, _) {
              final visibilityState = ref.watch(minePageVisibilityProvider);
              final grouped = <String, List<MinePageItemDefinition>>{};
              for (final definition in displayableMinePageItemDefinitions) {
                grouped
                    .putIfAbsent(definition.sectionTitle, () => [])
                    .add(definition);
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  Text(
                    '我的页面显示内容',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '高级会员和顶部用户卡片暂不支持隐藏，其余项目可单独控制显示状态。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final entry in grouped.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _buildGroupCard(
                      context,
                      children: [
                        for (var index = 0; index < entry.value.length; index++)
                          _buildVisibilityTile(
                            context,
                            definition: entry.value[index],
                            visible: visibilityState.isVisible(
                              entry.value[index].id,
                            ),
                            onChanged:
                                entry.value[index].configurable
                                    ? (value) => _setMinePageItemVisible(
                                      entry.value[index].id,
                                      value,
                                    )
                                    : null,
                            showDivider: index != entry.value.length - 1,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openStartupDestinationMenu() async {
    _startupMenuKey.currentState?.showButtonMenu();
  }

  Widget _buildStartupSelector(
    BuildContext context,
    MinePageStartupDestination destination,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              destination.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 20,
              color: colorScheme.onSecondaryContainer,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setStartupDestination(
    MinePageStartupDestination destination,
  ) async {
    try {
      await ref
          .read(minePageStartupDestinationProvider.notifier)
          .setDestination(destination);
    } catch (_) {
      _showMessage('启动项保存失败，请稍后重试。');
    }
  }

  Widget _buildGroupCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.58),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildVisibilityTile(
    BuildContext context, {
    required MinePageItemDefinition definition,
    required bool visible,
    required ValueChanged<bool>? onChanged,
    required bool showDivider,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((definition.subtitle ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        definition.subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(value: visible, onChanged: onChanged),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 12,
            endIndent: 12,
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
      ],
    );
  }

  Future<void> _setMinePageItemVisible(
    MinePageItemId itemId,
    bool visible,
  ) async {
    try {
      await ref
          .read(minePageVisibilityProvider.notifier)
          .setVisible(itemId, visible);
    } catch (_) {
      _showMessage('显示项保存失败，请稍后重试。');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
