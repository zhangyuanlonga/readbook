import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';

import '../../../app/theme/app_theme_provider.dart';
import '../../../app/theme/app_theme_seed_provider.dart';

class MinePage extends ConsumerStatefulWidget {
  const MinePage({super.key});

  @override
  ConsumerState<MinePage> createState() => _MinePageState();
}

class _MinePageState extends ConsumerState<MinePage> {
  String? _highlightedTileId;

  static final Uri _sourceFeedbackUri = Uri.parse(
    'https://qun.qq.com/universal-share/share?ac=1&authKey=Tabvg05EAafVbER7E8%2BzAQ18yErg2a%2B5PoqQH41t6dbPjcZIfDSnNX%2F4KCAXhzVh&busi_data=eyJncm91cENvZGUiOiIxMDgyODI3MjI0IiwidG9rZW4iOiIzam5tVFQ0cUs1T3VlMytzVk9iOXB1Zk40Q1RaUXJiQytzd2JlZUx3NDhXQTJscy9ZZGE5WW1hQXhPdGFwMHU1IiwidWluIjoiNzgyMDQ1MDExIn0%3D&data=PHNA5IOU4A3ujR5i9rmpWqWn4Qc-L9MNr8ByREa7IfvpXTo1utwnHVIfjkB7Rlk4x3yE9dfMR5_ZjOfsQ9wYcA&svctype=4&tempid=h5_group_info',
  );
  static const List<_SeedColorOption> _seedColorOptions = [
    _SeedColorOption('番茄橙', Color(0xFFE7573B)),
    _SeedColorOption('青绿', Color(0xFF2E7D32)),
    _SeedColorOption('海蓝', Color(0xFF1565C0)),
    _SeedColorOption('经典紫', Color(0xFF6750A4)),
    _SeedColorOption('纯白', Color(0xFFFFFFFF)),
  ];
  static const List<_ThemeModeOption> _themeModeOptions = [
    _ThemeModeOption(
      mode: ThemeMode.light,
      label: '日间',
      icon: Icons.light_mode_outlined,
    ),
    _ThemeModeOption(
      mode: ThemeMode.dark,
      label: '夜间',
      icon: Icons.dark_mode_outlined,
    ),
    _ThemeModeOption(
      mode: ThemeMode.system,
      label: '跟随系统',
      icon: Icons.settings_suggest_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final themeMode = ref.watch(appThemeModeProvider);
    final seedColor = ref.watch(appSeedColorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth >= AppLayout.railBreakpointWidth
                  ? 700.0
                  : constraints.maxWidth;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  12,
                  horizontal,
                  12 + bottomSafe,
                ),
                children: [
                  _buildPageEntrance(
                    index: 0,
                    child: _buildProfileCard(
                      context,
                      subtitle: '后续会持续补充系统设置、规则工具与同步能力。',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPageEntrance(
                    index: 1,
                    child: _buildActionSection(
                      context,
                      title: '设置',
                      actions: [
                        _MineActionItem(
                          icon: Icons.card_membership_outlined,
                          label: '会员',
                          onTap: () => _showMessage('会员功能开发中。'),
                        ),
                        _MineActionItem(
                          icon: Icons.settings_outlined,
                          label: '主题设置',
                          badgeText: _themeModeLabel(themeMode),
                          colorDot: seedColor,
                          onTap:
                              () => _showThemeSettingsSheet(
                                context: context,
                                ref: ref,
                              ),
                        ),
                        _MineActionItem(
                          icon: Icons.menu_book_outlined,
                          label: '阅读设置',
                          onTap: () => context.push('/reader-settings'),
                        ),
                        _MineActionItem(
                          icon: Icons.tune_rounded,
                          label: '系统设置',
                          onTap: () => context.push('/system-settings'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPageEntrance(
                    index: 2,
                    child: _buildActionSection(
                      context,
                      title: '常用服务',
                      actions: _resolveCommonServiceActions(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPageEntrance(
                    index: 3,
                    child: _buildActionSection(
                      context,
                      title: '其他',
                      actions: [
                        _MineActionItem(
                          icon: Icons.quiz_outlined,
                          label: '常见问题',
                          onTap: () => _showMessage('常见问题整理中。'),
                        ),
                        _MineActionItem(
                          icon: Icons.feedback_outlined,
                          label: '反馈',
                          onTap: _openSourceFeedback,
                        ),
                        _MineActionItem(
                          icon: Icons.share_outlined,
                          label: '分享',
                          onTap: () => _showMessage('分享能力开发中。'),
                        ),
                        _MineActionItem(
                          icon: Icons.info_outline,
                          label: '关于',
                          onTap: () => context.push('/about'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, {required String subtitle}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.auto_stories_rounded,
                color: colorScheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AppRead',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection(
    BuildContext context, {
    required String title,
    required List<_MineActionItem> actions,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = _resolveGridColumns(
                  width: constraints.maxWidth,
                  itemCount: actions.length,
                );
                final denseGrid = columns >= 4;
                final crossSpacing = denseGrid ? 8.0 : 10.0;
                final mainSpacing = denseGrid ? 8.0 : 10.0;
                final mainAxisExtent = switch (columns) {
                  >= 4 => 88.0,
                  3 => 98.0,
                  _ => 106.0,
                };

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: actions.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: crossSpacing,
                    mainAxisSpacing: mainSpacing,
                    mainAxisExtent: mainAxisExtent,
                  ),
                  itemBuilder: (context, index) {
                    final item = actions[index];
                    final tileId = 'mine_${title}_$index';
                    return _buildGridEntrance(
                      section: title,
                      index: index,
                      child: _buildActionTile(
                        context,
                        item: item,
                        denseGrid: denseGrid,
                        tileId: tileId,
                        highlighted: _highlightedTileId == tileId,
                        borderColor: colorScheme.outlineVariant.withValues(
                          alpha: denseGrid ? 0.24 : 0.34,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  int _resolveGridColumns({required double width, required int itemCount}) {
    if (itemCount <= 1) {
      return 1;
    }

    if (itemCount == 4) {
      // Keep 4 columns on common phone widths; only downgrade on extra narrow widths.
      if (width < 250) {
        return 2;
      }
      return 4;
    }
    if (itemCount == 3 && width < AppLayout.compactContentWidth) {
      return 3;
    }

    final base = switch (width) {
      < 340 => 3,
      < 600 => 4,
      < 840 => 5,
      _ => 6,
    };
    return base.clamp(1, itemCount);
  }

  Widget _buildActionTile(
    BuildContext context, {
    required _MineActionItem item,
    required bool denseGrid,
    required String tileId,
    required bool highlighted,
    required Color borderColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconSize = denseGrid ? 30.0 : 34.0;
    final iconGlyphSize = denseGrid ? 17.0 : 19.0;
    final badgePadding =
        denseGrid
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 7, vertical: 3);
    final labelTextStyle =
        denseGrid
            ? theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.1,
            )
            : theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.15,
            );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onHighlightChanged: (value) {
          if (value) {
            if (_highlightedTileId == tileId) {
              return;
            }
            setState(() {
              _highlightedTileId = tileId;
            });
            return;
          }
          if (_highlightedTileId != tileId) {
            return;
          }
          setState(() {
            _highlightedTileId = null;
          });
        },
        onTap: item.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          scale: highlighted ? 0.965 : 1,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
              color: colorScheme.surfaceContainerLow.withValues(
                alpha: denseGrid ? 0.62 : 0.76,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Stack(
                children: [
                  if (item.badgeText != null && item.badgeText!.isNotEmpty)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: badgePadding,
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.badgeText!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: iconSize,
                              height: iconSize,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(
                                  alpha: denseGrid ? 0.34 : 0.42,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.icon,
                                size: iconGlyphSize,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (item.colorDot != null)
                              Positioned(
                                right: -1,
                                bottom: -1,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: item.colorDot,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colorScheme.surface,
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: denseGrid ? 6 : 8),
                        Text(
                          item.label,
                          maxLines: denseGrid ? 1 : 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: labelTextStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageEntrance({required int index, required Widget child}) {
    final delay = (index * 0.08).clamp(0.0, 0.42);
    final begin = delay;
    final end = (begin + 0.46).clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('mine_page_entry_$index'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, value, child) {
        final translateY = (1 - value) * 14;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildGridEntrance({
    required String section,
    required int index,
    required Widget child,
  }) {
    final delay = (index * 0.07).clamp(0.0, 0.42);
    final begin = delay;
    final end = (begin + 0.5).clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('mine_grid_${section}_$index'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, value, child) {
        final translateY = (1 - value) * 10;
        final scale = 0.985 + (0.015 * value);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
    );
  }

  List<_MineActionItem> _resolveCommonServiceActions(BuildContext context) {
    return <_MineActionItem>[
      _MineActionItem(
        icon: Icons.menu_book_rounded,
        label: '书源',
        onTap: () => context.go('/source'),
      ),
      _MineActionItem(
        icon: Icons.rule_outlined,
        label: '规则配置',
        onTap: () => context.push('/rule-config'),
      ),
      _MineActionItem(
        icon: Icons.cloud_outlined,
        label: '缓存管理',
        onTap: () => context.push('/cache'),
      ),
    ];
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => '日间',
      ThemeMode.dark => '夜间',
      ThemeMode.system => '跟随系统',
    };
  }

  Future<void> _showThemeSettingsSheet({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final initialThemeMode = ref.read(appThemeModeProvider);
    final initialSeedColor = ref.read(appSeedColorProvider);

    final selected = await showModalBottomSheet<_ThemeSettingsResult>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        ThemeMode selectedThemeMode = initialThemeMode;
        Color selectedSeedColor = initialSeedColor;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final colorScheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            final maxHeight = MediaQuery.sizeOf(context).height * 0.5;

            return SafeArea(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(bottom: bottomInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '主题设置',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '统一管理主题模式和主题颜色。',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    10,
                                    12,
                                    12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant
                                          .withValues(alpha: 0.48),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '主题模式',
                                        style: textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          const spacing = 8.0;
                                          final columns =
                                              constraints.maxWidth >= 560
                                                  ? 3
                                                  : constraints.maxWidth >= 360
                                                  ? 2
                                                  : 1;
                                          final itemWidth =
                                              (constraints.maxWidth -
                                                  ((columns - 1) * spacing)) /
                                              columns;

                                          return Wrap(
                                            spacing: spacing,
                                            runSpacing: spacing,
                                            children: _themeModeOptions
                                                .map(
                                                  (option) => SizedBox(
                                                    width: itemWidth,
                                                    child: _buildThemeModeTile(
                                                      context,
                                                      option: option,
                                                      selectedMode:
                                                          selectedThemeMode,
                                                      onTap:
                                                          () => setSheetState(
                                                            () {
                                                              selectedThemeMode =
                                                                  option.mode;
                                                            },
                                                          ),
                                                    ),
                                                  ),
                                                )
                                                .toList(growable: false),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    10,
                                    12,
                                    12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant
                                          .withValues(alpha: 0.48),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '主题颜色',
                                        style: textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          const spacing = 8.0;
                                          final columns =
                                              constraints.maxWidth >= 560
                                                  ? 3
                                                  : constraints.maxWidth >= 360
                                                  ? 2
                                                  : 1;
                                          final itemWidth =
                                              (constraints.maxWidth -
                                                  ((columns - 1) * spacing)) /
                                              columns;

                                          return Wrap(
                                            spacing: spacing,
                                            runSpacing: spacing,
                                            children: _seedColorOptions
                                                .map(
                                                  (option) => SizedBox(
                                                    width: itemWidth,
                                                    child: _buildThemeColorTile(
                                                      context,
                                                      option: option,
                                                      selectedColor:
                                                          selectedSeedColor,
                                                      onTap:
                                                          () => setSheetState(
                                                            () {
                                                              selectedSeedColor =
                                                                  option.color;
                                                            },
                                                          ),
                                                    ),
                                                  ),
                                                )
                                                .toList(growable: false),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('取消'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed:
                                    () => Navigator.of(context).pop(
                                      _ThemeSettingsResult(
                                        themeMode: selectedThemeMode,
                                        seedColor: selectedSeedColor,
                                      ),
                                    ),
                                child: const Text('保存'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selected == null) {
      return;
    }

    if (selected.themeMode != initialThemeMode) {
      await ref
          .read(appThemeModeProvider.notifier)
          .setThemeMode(selected.themeMode);
    }
    if (selected.seedColor.toARGB32() != initialSeedColor.toARGB32()) {
      await ref
          .read(appSeedColorProvider.notifier)
          .setSeedColor(selected.seedColor);
    }
  }

  Widget _buildThemeModeTile(
    BuildContext context, {
    required _ThemeModeOption option,
    required ThemeMode selectedMode,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = option.mode == selectedMode;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color:
              selected
                  ? colorScheme.secondaryContainer.withValues(alpha: 0.8)
                  : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                selected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.58),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              option.icon,
              size: 18,
              color:
                  selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                option.label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 18,
              color: selected ? colorScheme.primary : colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeColorTile(
    BuildContext context, {
    required _SeedColorOption option,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = option.color.toARGB32() == selectedColor.toARGB32();

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color:
              selected
                  ? colorScheme.secondaryContainer.withValues(alpha: 0.82)
                  : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                selected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.58),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: option.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.outlineVariant,
                  width: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                option.label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 18, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Future<void> _openSourceFeedback() async {
    final launched = await launchUrl(
      _sourceFeedbackUri,
      mode: LaunchMode.externalApplication,
    );
    if (launched || !mounted) {
      return;
    }
    _showMessage('跳转失败，请稍后重试。');
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

class _SeedColorOption {
  const _SeedColorOption(this.label, this.color);

  final String label;
  final Color color;
}

class _ThemeModeOption {
  const _ThemeModeOption({
    required this.mode,
    required this.label,
    required this.icon,
  });

  final ThemeMode mode;
  final String label;
  final IconData icon;
}

class _ThemeSettingsResult {
  const _ThemeSettingsResult({
    required this.themeMode,
    required this.seedColor,
  });

  final ThemeMode themeMode;
  final Color seedColor;
}

class _MineActionItem {
  const _MineActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeText,
    this.colorDot,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? colorDot;
}
