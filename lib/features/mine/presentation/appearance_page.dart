import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/navigation/app_navigation_style_provider.dart';
import '../../../app/shell_navigation_provider.dart';
import '../../../app/theme/app_icon_provider.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../app/theme/app_theme_provider.dart';
import '../../../app/theme/app_theme_seed_provider.dart';
import '../../../app/widgets/cupertino_dock_navigation_bar.dart';
import '../../../app/widgets/text_cover_placeholder.dart';
import '../../../core/device/app_icon_service.dart';

enum AppearanceSection {
  overview,
  themeMode,
  appIcon,
  themeColor,
  bottomBar,
  coverGallery,
  backgroundGallery,
}

class AppearancePage extends ConsumerStatefulWidget {
  const AppearancePage({super.key, this.section = AppearanceSection.overview});

  final AppearanceSection section;

  @override
  ConsumerState<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends ConsumerState<AppearancePage> {
  static const List<Map<String, String>> _coverGallerySamples = [
    {'title': '凡人修仙传', 'author': '忘语'},
    {'title': '斗破苍穹', 'author': '天蚕土豆'},
    {'title': '三体', 'author': '刘慈欣'},
    {'title': '庆余年', 'author': '猫腻'},
    {'title': '雪中悍刀行', 'author': '烽火戏诸侯'},
    {'title': '活着', 'author': '余华'},
  ];

  static const List<String> _backgroundGalleryPaths = [
    'assets/reader/backgrounds/20260224-212555-700782.jpeg',
    'assets/reader/backgrounds/20260224-212555-b91cd8.jpeg',
    'assets/reader/backgrounds/20260224-212555-01b93d.jpeg',
    'assets/reader/backgrounds/Image_1768236174407.jpg',
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

  static const List<_NavigationStyleOption> _navigationStyleOptions = [
    _NavigationStyleOption(
      preference: AppNavigationStylePreference.followSystem,
      label: '跟随系统',
      icon: Icons.settings_suggest_outlined,
    ),
    _NavigationStyleOption(
      preference: AppNavigationStylePreference.standard,
      label: '标准',
      icon: Icons.splitscreen_outlined,
    ),
    _NavigationStyleOption(
      preference: AppNavigationStylePreference.cupertinoDock,
      label: '苹果风格',
      icon: Icons.dock_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final selectedThemeMode = ref.watch(appThemeModeProvider);
    final selectedAppIconVariant = ref.watch(appIconVariantProvider);
    final selectedSeedColor = ref.watch(appSeedColorProvider);
    final selectedNavigationStyle = ref.watch(
      appNavigationStylePreferenceProvider,
    );
    final showNavigationLabels = ref.watch(
      appNavigationLabelVisibilityProvider,
    );
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
        appBar: AppBar(title: Text(_pageTitle(widget.section))),
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
                  children: _buildSectionContent(
                    context,
                    navigationState,
                    selectedThemeMode: selectedThemeMode,
                    selectedAppIconVariant: selectedAppIconVariant,
                    selectedSeedColor: selectedSeedColor,
                    selectedNavigationStyle: selectedNavigationStyle,
                    showNavigationLabels: showNavigationLabels,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _pageTitle(AppearanceSection section) {
    return switch (section) {
      AppearanceSection.overview => '外观',
      AppearanceSection.themeMode => '主题模式',
      AppearanceSection.appIcon => '应用图标',
      AppearanceSection.themeColor => '主题颜色',
      AppearanceSection.bottomBar => '底栏配置',
      AppearanceSection.coverGallery => '封面图集',
      AppearanceSection.backgroundGallery => '背景图集',
    };
  }

  List<Widget> _buildSectionContent(
    BuildContext context,
    AppShellNavigationState navigationState, {
    required ThemeMode selectedThemeMode,
    required AppIconVariant selectedAppIconVariant,
    required Color selectedSeedColor,
    required AppNavigationStylePreference selectedNavigationStyle,
    required bool showNavigationLabels,
  }) {
    final sections = <Widget>[];

    if (widget.section == AppearanceSection.overview) {
      sections.add(
        _buildPreviewCard(
          context,
          navigationState,
          selectedThemeMode: selectedThemeMode,
          selectedSeedColor: selectedSeedColor,
          selectedNavigationStyle: selectedNavigationStyle,
          showNavigationLabels: showNavigationLabels,
        ),
      );
      sections.add(const SizedBox(height: 12));
    }

    if (widget.section == AppearanceSection.overview ||
        widget.section == AppearanceSection.themeMode) {
      sections.add(
        _buildThemeModeSection(context, selectedThemeMode: selectedThemeMode),
      );
      if (ref.watch(appIconServiceProvider).isSupported) {
        sections.add(const SizedBox(height: 12));
        sections.add(
          _buildAppIconSection(
            context,
            selectedVariant: selectedAppIconVariant,
          ),
        );
      }
    }

    if (widget.section == AppearanceSection.appIcon) {
      sections.add(
        _buildAppIconSection(context, selectedVariant: selectedAppIconVariant),
      );
    }

    if (widget.section == AppearanceSection.overview ||
        widget.section == AppearanceSection.themeColor) {
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: 12));
      }
      sections.add(
        _buildThemeColorSection(context, selectedSeedColor: selectedSeedColor),
      );
    }

    if (widget.section == AppearanceSection.overview ||
        widget.section == AppearanceSection.bottomBar) {
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: 12));
      }
      sections.add(
        _buildSectionCard(
          context,
          icon: Icons.collections_bookmark_outlined,
          title: '底栏图集',
          subtitle: '管理底栏图标图集与默认图集。',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.dock_outlined),
            title: const Text('打开图集管理'),
            subtitle: const Text('当前先支持默认图集与启用切换。'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/bottom-nav-icon-galleries'),
          ),
        ),
      );
      sections.add(const SizedBox(height: 12));
      sections.add(
        _buildNavigationStyleSection(
          context,
          selectedNavigationStyle: selectedNavigationStyle,
          showNavigationLabels: showNavigationLabels,
        ),
      );
      sections.add(const SizedBox(height: 12));
      sections.add(
        _buildSectionCard(
          context,
          icon: Icons.space_dashboard_outlined,
          title: '底部菜单',
          subtitle: '控制底部主导航展示项，至少保留一个内容入口。',
          child: const _AppearanceNavigationVisibilityPanel(),
        ),
      );
    }

    if (widget.section == AppearanceSection.coverGallery) {
      sections.add(_buildCoverGallerySection(context));
    }

    if (widget.section == AppearanceSection.backgroundGallery) {
      sections.add(_buildBackgroundGallerySection(context));
    }

    return sections;
  }

  Widget _buildThemeModeSection(
    BuildContext context, {
    required ThemeMode selectedThemeMode,
  }) {
    return _buildSectionCard(
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
              (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

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
                              .read(appThemeModeProvider.notifier)
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
    );
  }

  Widget _buildAppIconSection(
    BuildContext context, {
    required AppIconVariant selectedVariant,
  }) {
    return _buildSectionCard(
      context,
      icon: Icons.apps_outage_outlined,
      title: '应用图标',
      subtitle: '切换浅色或深色桌面图标，默认浅色。仅 Android 和 iOS 支持。',
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 10.0;
          final columns = AppLayout.optionGridColumnsForWidth(
            constraints.maxWidth,
          ).clamp(1, 2);
          final itemWidth =
              (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: AppIconVariant.values
                .map(
                  (variant) => SizedBox(
                    width: itemWidth,
                    child: _buildAppIconTile(
                      context,
                      variant: variant,
                      selected: selectedVariant == variant,
                      onTap: () async {
                        if (selectedVariant == variant) {
                          return;
                        }
                        final didApply = await ref
                            .read(appIconVariantProvider.notifier)
                            .setVariant(variant);
                        if (!didApply && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('切换应用图标失败，请稍后重试。')),
                          );
                        }
                      },
                    ),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }

  Widget _buildThemeColorSection(
    BuildContext context, {
    required Color selectedSeedColor,
  }) {
    return _buildSectionCard(
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
              (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

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
                              .read(appSeedColorProvider.notifier)
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
    );
  }

  Widget _buildAppIconTile(
    BuildContext context, {
    required AppIconVariant variant,
    required bool selected,
    required Future<void> Function() onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        unawaited(onTap());
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color:
              selected
                  ? colorScheme.secondaryContainer.withValues(alpha: 0.82)
                  : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                selected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.58),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 84,
                height: 84,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Image.asset(
                  variant.previewAssetPath,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    variant.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 18,
                  color: selected ? colorScheme.primary : colorScheme.outline,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              variant.subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverGallerySection(BuildContext context) {
    return _buildSectionCard(
      context,
      icon: Icons.photo_library_outlined,
      title: '封面图集',
      subtitle: '预览当前应用使用的文字封面风格。',
      child: LayoutBuilder(
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
            children: _coverGallerySamples
                .map(
                  (sample) => SizedBox(
                    width: itemWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextCoverPlaceholder(
                          title: sample['title'],
                          author: sample['author'],
                          width: itemWidth,
                          height: itemWidth * 1.42,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          sample['title'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }

  Widget _buildBackgroundGallerySection(BuildContext context) {
    return _buildSectionCard(
      context,
      icon: Icons.wallpaper_outlined,
      title: '背景图集',
      subtitle: '预览阅读器内置背景图。',
      child: LayoutBuilder(
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
            children: _backgroundGalleryPaths
                .map(
                  (path) => SizedBox(
                    width: itemWidth,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 1.45,
                        child: Image.asset(path, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }

  Widget _buildNavigationStyleSection(
    BuildContext context, {
    required AppNavigationStylePreference selectedNavigationStyle,
    required bool showNavigationLabels,
  }) {
    return _buildSectionCard(
      context,
      icon: Icons.dock_outlined,
      title: '导航样式',
      subtitle: '在 Android 和 iOS 手机上切换主导航风格，平板保持侧边栏。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              final columns = AppLayout.optionGridColumnsForWidth(
                constraints.maxWidth,
              );
              final itemWidth =
                  (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _navigationStyleOptions
                    .map(
                      (option) => SizedBox(
                        width: itemWidth,
                        child: _buildNavigationStyleTile(
                          context,
                          option: option,
                          selectedNavigationStyle: selectedNavigationStyle,
                          onTap: () {
                            if (selectedNavigationStyle == option.preference) {
                              return;
                            }
                            unawaited(
                              ref
                                  .read(
                                    appNavigationStylePreferenceProvider
                                        .notifier,
                                  )
                                  .setPreference(option.preference),
                            );
                          },
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildNavigationLabelVisibilityTile(
            context,
            showLabels: showNavigationLabels,
            onChanged: (value) {
              unawaited(
                ref
                    .read(appNavigationLabelVisibilityProvider.notifier)
                    .setVisible(value),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(
    BuildContext context,
    AppShellNavigationState navigationState, {
    required ThemeMode selectedThemeMode,
    required Color selectedSeedColor,
    required AppNavigationStylePreference selectedNavigationStyle,
    required bool showNavigationLabels,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedMode = _themeModeOptions.firstWhere(
      (option) => option.mode == selectedThemeMode,
    );
    final visibleDestinations = visibleAppShellDestinations(navigationState);
    final previewTint = appThemeDisplayColor(
      selectedSeedColor,
      brightness: colorScheme.brightness,
    );
    final effectiveNavigationStyle = resolveAppNavigationStyle(
      selectedNavigationStyle,
      isWeb: kIsWeb,
      platform: theme.platform,
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
                  label: '底部菜单 ${navigationState.visibleTabCount}/4',
                ),
                _buildPreviewMetaChip(
                  context,
                  icon: Icons.dock_outlined,
                  label: appNavigationStylePreferenceLabel(
                    selectedNavigationStyle,
                  ),
                ),
                _buildPreviewMetaChip(
                  context,
                  icon: Icons.text_fields_outlined,
                  label: appNavigationLabelVisibilityLabel(
                    showNavigationLabels,
                  ),
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
                  _buildBottomNavigationPreview(
                    context,
                    visibleDestinations,
                    previewTint: previewTint,
                    navigationStyle: effectiveNavigationStyle,
                    showNavigationLabels: showNavigationLabels,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationPreview(
    BuildContext context,
    List<AppShellDestination> visibleDestinations, {
    required Color previewTint,
    required AppNavigationStyle navigationStyle,
    required bool showNavigationLabels,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    if (navigationStyle == AppNavigationStyle.cupertinoDock) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ColoredBox(
          color: colorScheme.surface.withValues(alpha: 0.12),
          child: IgnorePointer(
            child: CupertinoDockNavigationBar(
              destinations: visibleDestinations,
              selectedIndex: 0,
              activeIconGallery: null,
              showLabels: showNavigationLabels,
              onDestinationSelected: (_) {},
              onSearchPressed: () {},
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        for (var index = 0; index < visibleDestinations.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
                          : colorScheme.outlineVariant.withValues(alpha: 0.44),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    index == 0
                        ? visibleDestinations[index].selectedIcon
                        : visibleDestinations[index].icon,
                    size: 18,
                    color:
                        index == 0 ? previewTint : colorScheme.onSurfaceVariant,
                  ),
                  if (showNavigationLabels) ...[
                    const SizedBox(height: 6),
                    Text(
                      visibleDestinations[index].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
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

  Widget _buildNavigationStyleTile(
    BuildContext context, {
    required _NavigationStyleOption option,
    required AppNavigationStylePreference selectedNavigationStyle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = option.preference == selectedNavigationStyle;

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

  Widget _buildNavigationLabelVisibilityTile(
    BuildContext context, {
    required bool showLabels,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.58),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '显示导航文字',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '苹果风格下控制左侧主导航是否显示文字。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(value: showLabels, onChanged: onChanged),
        ],
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
          '当前展示 ${navigationState.visibleTabCount}/4 项，“我的”固定保留。',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: [
              _buildNavigationRow(
                context,
                tab: AppShellTab.bookshelf,
                enabled: navigationState.showBookshelf,
                locked: false,
                isSaving: _isSaving && _savingTab == AppShellTab.bookshelf,
              ),
              _buildNavigationDivider(context),
              _buildNavigationRow(
                context,
                tab: AppShellTab.discover,
                enabled: navigationState.showDiscover,
                locked: false,
                isSaving: _isSaving && _savingTab == AppShellTab.discover,
              ),
              _buildNavigationDivider(context),
              _buildNavigationRow(
                context,
                tab: AppShellTab.stats,
                enabled: navigationState.showStats,
                locked: false,
                isSaving: _isSaving && _savingTab == AppShellTab.stats,
              ),
              _buildNavigationDivider(context),
              _buildNavigationRow(
                context,
                tab: AppShellTab.mine,
                enabled: true,
                locked: true,
                isSaving: false,
              ),
            ],
          ),
        ),
        if (_errorText case final message?) ...[
          const SizedBox(height: 10),
          _buildNavigationErrorBanner(context, message: message),
        ],
      ],
    );
  }

  Widget _buildNavigationDivider(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      indent: 52,
      endIndent: 14,
      color: colorScheme.outlineVariant.withValues(alpha: 0.42),
    );
  }

  Widget _buildNavigationRow(
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
        borderRadius: BorderRadius.circular(16),
        onTap: locked || _isSaving ? null : () => _toggle(tab, !enabled),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color:
                      active
                          ? colorScheme.primaryContainer.withValues(alpha: 0.92)
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      locked
                          ? '入口固定保留'
                          : enabled
                          ? '已显示在底部导航'
                          : '当前已隐藏',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
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

class _NavigationStyleOption {
  const _NavigationStyleOption({
    required this.preference,
    required this.label,
    required this.icon,
  });

  final AppNavigationStylePreference preference;
  final String label;
  final IconData icon;
}
