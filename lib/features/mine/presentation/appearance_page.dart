import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/shell_navigation_provider.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../app/theme/app_theme_provider.dart';
import '../../../app/theme/app_theme_seed_provider.dart';

class AppearancePage extends ConsumerStatefulWidget {
  const AppearancePage({super.key});

  @override
  ConsumerState<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends ConsumerState<AppearancePage> {
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
    final selectedThemeMode = ref.watch(appThemeModeProvider);
    final selectedSeedColor = ref.watch(appSeedColorProvider);
    final navigationState = ref.watch(appShellNavigationProvider);

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/mine');
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('外观')),
        body: LayoutBuilder(
          builder: (context, _) {
            final maxWidth = AppLayout.pageContentMaxWidth(
              context,
              maxWidth: AppLayout.settingsContentMaxWidth,
            );

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 12),
                  children: [
                    _buildPreviewCard(
                      context,
                      navigationState,
                      selectedThemeMode: selectedThemeMode,
                      selectedSeedColor: selectedSeedColor,
                    ),
                    const SizedBox(height: 12),
                    _buildSectionCard(
                      context,
                      icon: Icons.light_mode_outlined,
                      title: '主题模式',
                      subtitle: '切换日间、夜间或跟随系统。',
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const spacing = 8.0;
                          final columns = AppLayout.optionGridColumnsForWidth(
                            constraints.maxWidth,
                          );
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
                                      selectedThemeMode: selectedThemeMode,
                                      onTap: () {
                                        if (selectedThemeMode == option.mode) {
                                          return;
                                        }
                                        unawaited(
                                          ref
                                              .read(
                                                appThemeModeProvider.notifier,
                                              )
                                              .setThemeMode(option.mode),
                                        );
                                      },
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSectionCard(
                      context,
                      icon: Icons.palette_outlined,
                      title: '主题颜色',
                      subtitle: '控制应用主色与强调色。',
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const spacing = 8.0;
                          final columns = AppLayout.optionGridColumnsForWidth(
                            constraints.maxWidth,
                          );
                          final itemWidth =
                              (constraints.maxWidth -
                                  ((columns - 1) * spacing)) /
                              columns;

                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: appThemeSeedOptions
                                .map(
                                  (option) => SizedBox(
                                    width: itemWidth,
                                    child: _buildThemeColorTile(
                                      context,
                                      option: option,
                                      selectedSeedColor: selectedSeedColor,
                                      onTap: () {
                                        if (selectedSeedColor.toARGB32() ==
                                            option.color.toARGB32()) {
                                          return;
                                        }
                                        unawaited(
                                          ref
                                              .read(
                                                appSeedColorProvider.notifier,
                                              )
                                              .setSeedColor(option.color),
                                        );
                                      },
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSectionCard(
                      context,
                      icon: Icons.space_dashboard_outlined,
                      title: '底部菜单',
                      subtitle: '控制底部主导航展示项，至少保留一个内容入口。',
                      child: const _AppearanceNavigationVisibilityPanel(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreviewCard(
    BuildContext context,
    AppShellNavigationState navigationState, {
    required ThemeMode selectedThemeMode,
    required Color selectedSeedColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedMode = _themeModeOptions.firstWhere(
      (option) => option.mode == selectedThemeMode,
    );
    final visibleDestinations = visibleAppShellDestinations(navigationState);
    final previewTint = appThemeDisplayColor(
      selectedSeedColor,
      brightness: colorScheme.brightness,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            previewTint.withValues(alpha: 0.18),
            colorScheme.surfaceContainerLow,
            colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: previewTint.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: previewTint.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.palette_outlined,
                    color: previewTint,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前外观',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '主题与底部导航会在这里同步生效。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPreviewMetaChip(
                  context,
                  icon: selectedMode.icon,
                  label: selectedMode.label,
                ),
                _buildPreviewMetaChip(
                  context,
                  icon: Icons.color_lens_outlined,
                  label: appThemeSeedLabel(selectedSeedColor),
                  accentColor: previewTint,
                ),
                _buildPreviewMetaChip(
                  context,
                  icon: Icons.space_dashboard_outlined,
                  label: '底部菜单 ${navigationState.visibleTabCount}/3',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.46),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '底部导航预览',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (
                        var index = 0;
                        index < visibleDestinations.length;
                        index++
                      ) ...[
                        if (index > 0) const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  index == 0
                                      ? previewTint.withValues(alpha: 0.14)
                                      : colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    index == 0
                                        ? previewTint.withValues(alpha: 0.28)
                                        : colorScheme.outlineVariant.withValues(
                                          alpha: 0.44,
                                        ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  visibleDestinations[index].icon,
                                  size: 18,
                                  color:
                                      index == 0
                                          ? previewTint
                                          : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  visibleDestinations[index].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewMetaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? accentColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveAccent = accentColor ?? colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.44),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: effectiveAccent),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.46),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildThemeModeTile(
    BuildContext context, {
    required _ThemeModeOption option,
    required ThemeMode selectedThemeMode,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = option.mode == selectedThemeMode;

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
    required AppThemeSeedOption option,
    required Color selectedSeedColor,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = option.color.toARGB32() == selectedSeedColor.toARGB32();

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
}

class _AppearanceNavigationVisibilityPanel extends ConsumerStatefulWidget {
  const _AppearanceNavigationVisibilityPanel();

  @override
  ConsumerState<_AppearanceNavigationVisibilityPanel> createState() =>
      _AppearanceNavigationVisibilityPanelState();
}

class _AppearanceNavigationVisibilityPanelState
    extends ConsumerState<_AppearanceNavigationVisibilityPanel> {
  bool _isSaving = false;
  AppShellTab? _savingTab;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    final navigationState = ref.watch(appShellNavigationProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '当前展示 ${navigationState.visibleTabCount}/3 项，“我的”固定保留。',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            final columns = AppLayout.optionGridColumnsForWidth(
              constraints.maxWidth,
            );
            final itemWidth =
                (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: _buildNavigationCard(
                    context,
                    tab: AppShellTab.bookshelf,
                    enabled: navigationState.showBookshelf,
                    locked: false,
                    isSaving: _isSaving && _savingTab == AppShellTab.bookshelf,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildNavigationCard(
                    context,
                    tab: AppShellTab.discover,
                    enabled: navigationState.showDiscover,
                    locked: false,
                    isSaving: _isSaving && _savingTab == AppShellTab.discover,
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildNavigationCard(
                    context,
                    tab: AppShellTab.mine,
                    enabled: true,
                    locked: true,
                    isSaving: false,
                  ),
                ),
              ],
            );
          },
        ),
        if (_errorText case final message?) ...[
          const SizedBox(height: 10),
          _buildNavigationErrorBanner(context, message: message),
        ],
      ],
    );
  }

  Widget _buildNavigationCard(
    BuildContext context, {
    required AppShellTab tab,
    required bool enabled,
    required bool locked,
    required bool isSaving,
  }) {
    final destination = _destinationFor(tab);
    final colorScheme = Theme.of(context).colorScheme;
    final active = locked || enabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: locked || _isSaving ? null : () => _toggle(tab, !enabled),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color:
                active
                    ? colorScheme.secondaryContainer.withValues(alpha: 0.34)
                    : colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  active
                      ? colorScheme.secondary.withValues(alpha: 0.3)
                      : colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color:
                          active
                              ? colorScheme.primaryContainer.withValues(
                                alpha: 0.92,
                              )
                              : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      destination.icon,
                      size: 18,
                      color:
                          active
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (locked)
                    _buildStatusPill(context, label: '固定')
                  else if (isSaving)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  else
                    Switch.adaptive(
                      value: enabled,
                      onChanged: (value) => _toggle(tab, value),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                destination.label,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                locked
                    ? '入口固定保留。'
                    : enabled
                    ? '已显示在底部导航。'
                    : '当前已隐藏。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(AppShellTab tab, bool enabled) async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
      _savingTab = tab;
      _errorText = null;
    });

    try {
      await ref
          .read(appShellNavigationProvider.notifier)
          .setTabVisible(tab, enabled);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '保存底部菜单配置失败，请稍后重试。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _savingTab = null;
        });
      }
    }
  }
}

AppShellDestination _destinationFor(AppShellTab tab) {
  return appShellDestinations.firstWhere(
    (destination) => destination.tab == tab,
  );
}

Widget _buildStatusPill(BuildContext context, {required String label}) {
  final colorScheme = Theme.of(context).colorScheme;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: colorScheme.primaryContainer.withValues(alpha: 0.84),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: colorScheme.onPrimaryContainer,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

Widget _buildNavigationErrorBanner(
  BuildContext context, {
  required String message,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: BoxDecoration(
      color: colorScheme.errorContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colorScheme.error.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline_rounded, size: 16, color: colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              color: colorScheme.onErrorContainer,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
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
