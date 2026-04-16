import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/navigation/app_navigation_style_provider.dart';
import '../../../app/shell_navigation_provider.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../app/theme/app_theme_provider.dart';
import '../../../app/theme/app_theme_seed_provider.dart';
import '../../../app/widgets/text_cover_placeholder.dart';

enum AppearanceSection {
  appearance,
  tabBar,
  cover,
  background,
}

enum AppFontFamily {
  system('系统默认'),
  serif('衬线体'),
  monospace('等宽体');

  const AppFontFamily(this.label);
  final String label;
}

final appFontFamilyProvider = StateProvider<AppFontFamily>((ref) {
  return AppFontFamily.system;
});

final appFontScaleProvider = StateProvider<double>((ref) {
  return 1.0;
});

final appFontWeightProvider = StateProvider<double>((ref) {
  return 400.0;
});

class AppearancePage extends ConsumerStatefulWidget {
  const AppearancePage({super.key, this.section = AppearanceSection.appearance});

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

  List<String> _backgroundPaths = [];
  bool _isLoadingBackgrounds = true;

  @override
  void initState() {
    super.initState();
    _loadBackgrounds();
  }

  Future<void> _loadBackgrounds() async {
    final dir = await getApplicationDocumentsDirectory();
    final bgDir = Directory('${dir.path}/backgrounds');
    final paths = <String>[];
    if (await bgDir.exists()) {
      final files = bgDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.jpeg') || f.path.endsWith('.png'))
          .map((f) => f.path)
          .toList();
      paths.addAll(files);
    }
    if (!mounted) return;
    setState(() {
      _backgroundPaths = paths;
      _isLoadingBackgrounds = false;
    });
  }

  Future<void> _uploadBackground() async {
    final types = [
      XTypeGroup(
        label: 'Images',
        extensions: const ['jpg', 'jpeg', 'png'],
      ),
    ];
    final file = await openFile(acceptedTypeGroups: types);
    if (file == null || !mounted) return;

    final dir = await getApplicationDocumentsDirectory();
    final bgDir = Directory('${dir.path}/backgrounds');
    if (!await bgDir.exists()) {
      await bgDir.create(recursive: true);
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name.split('/').last}';
    final destPath = '${bgDir.path}/$fileName';
    final destFile = File(destPath);
    await destFile.writeAsBytes(await file.readAsBytes());

    if (!mounted) return;
    setState(() {
      _backgroundPaths.add(destPath);
    });
  }

  Future<void> _deleteBackground(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    if (!mounted) return;
    setState(() {
      _backgroundPaths.remove(path);
    });
  }

  Future<void> _confirmDeleteBackground(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除背景'),
        content: const Text('确定要删除这个背景图吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteBackground(path);
    }
  }

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
      AppearanceSection.appearance => '外观',
      AppearanceSection.tabBar => '底栏',
      AppearanceSection.cover => '封面',
      AppearanceSection.background => '背景',
    };
  }

  List<Widget> _buildSectionContent(
    BuildContext context,
    AppShellNavigationState navigationState, {
    required ThemeMode selectedThemeMode,
    required Color selectedSeedColor,
    required AppNavigationStylePreference selectedNavigationStyle,
    required bool showNavigationLabels,
  }) {
    final sections = <Widget>[];

    if (widget.section == AppearanceSection.appearance) {
      sections.add(
        _buildThemeModeSection(context, selectedThemeMode: selectedThemeMode),
      );
      sections.add(const SizedBox(height: 10));
      sections.add(
        _buildThemeColorSection(context, selectedSeedColor: selectedSeedColor),
      );
      sections.add(const SizedBox(height: 10));
      sections.add(
        _buildNavigationStyleSection(
          context,
          selectedNavigationStyle: selectedNavigationStyle,
          showNavigationLabels: showNavigationLabels,
        ),
      );
      sections.add(const SizedBox(height: 10));
      sections.add(
        _buildSectionCard(
          context,
          icon: Icons.space_dashboard_outlined,
          title: '底部菜单',
          subtitle: '控制底部主导航展示项，至少保留一个内容入口。',
          child: const _AppearanceNavigationVisibilityPanel(),
        ),
      );
      sections.add(const SizedBox(height: 10));
      sections.add(
        _buildFontSection(context),
      );
    }

    if (widget.section == AppearanceSection.tabBar) {
      sections.add(
        _buildSectionCard(
          context,
          icon: Icons.collections_bookmark_outlined,
          title: '底栏图集',
          subtitle: '管理底栏图标图集与默认图集。',
          child: _buildNavIconGalleryEntry(context),
        ),
      );
    }

    if (widget.section == AppearanceSection.cover) {
      sections.add(_buildCoverGallerySection(context));
    }

    if (widget.section == AppearanceSection.background) {
      sections.add(_buildBackgroundGallerySection(context));
    }

    return sections;
  }

  Widget _buildNavIconGalleryEntry(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.push('/bottom-nav-icon-galleries'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.dock_outlined,
              size: 17,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '打开图集管理',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeModeSection(
    BuildContext context, {
    required ThemeMode selectedThemeMode,
  }) {
    return _buildSectionCard(
      context,
      icon: Icons.light_mode_outlined,
      title: '模式',
      subtitle: '日间、夜间或跟随系统。',
      child: Row(
        children: _themeModeOptions.map((option) {
          final selected = option.mode == selectedThemeMode;
          final colorScheme = Theme.of(context).colorScheme;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: option == _themeModeOptions.last ? 0 : 6,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  if (selected) return;
                  unawaited(
                    ref
                        .read(appThemeModeProvider.notifier)
                        .setThemeMode(option.mode),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color:
                        selected
                            ? colorScheme.secondaryContainer
                            : colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          selected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant.withValues(
                                  alpha: 0.5,
                                ),
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        option.icon,
                        size: 16,
                        color:
                            selected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color:
                              selected
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildThemeColorSection(
    BuildContext context, {
    required Color selectedSeedColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return _buildSectionCard(
      context,
      icon: Icons.palette_outlined,
      title: '颜色',
      subtitle: '应用主色与强调色。',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: appThemeSeedOptions.map((option) {
          final selected =
              option.color.toARGB32() == selectedSeedColor.toARGB32();
          return GestureDetector(
            onTap: () {
              if (selected) return;
              unawaited(
                ref
                    .read(appSeedColorProvider.notifier)
                    .setSeedColor(option.color),
              );
            },
            child: Tooltip(
              message: option.label,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: option.color,
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(
                          color: colorScheme.primary,
                          width: 2.5,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        )
                      : Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                          width: 0.5,
                        ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: option.color.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: ThemeData.estimateBrightnessForColor(
                                  option.color,
                                ) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black.withValues(alpha: 0.7),
                      )
                    : null,
              ),
            ),
          );
        }).toList(growable: false),
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

  Widget _buildFontSection(BuildContext context) {
    final fontFamily = ref.watch(appFontFamilyProvider);
    final fontScale = ref.watch(appFontScaleProvider);
    final fontWeight = ref.watch(appFontWeightProvider);

    return _buildSectionCard(
      context,
      icon: Icons.text_fields_outlined,
      title: '字体',
      subtitle: '全局字体、字体缩放与字重调整。',
      child: Column(
        children: [
          _buildFontFamilyTile(context, fontFamily),
          const SizedBox(height: 8),
          _buildFontScaleTile(context, fontScale),
          const SizedBox(height: 8),
          _buildFontWeightTile(context, fontWeight),
        ],
      ),
    );
  }

  Widget _buildFontFamilyTile(BuildContext context, AppFontFamily selected) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showFontFamilyBottomSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.font_download_outlined, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '全局字体',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              selected.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildFontScaleTile(BuildContext context, double scale) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showFontScaleBottomSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.zoom_in_outlined, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '字体缩放',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${(scale * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildFontWeightTile(BuildContext context, double weight) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showFontWeightBottomSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.format_bold, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '字重调整',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              weight.toInt().toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<void> _showFontFamilyBottomSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        final selected = ref.read(appFontFamilyProvider);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '选择字体',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              for (final font in AppFontFamily.values)
                ListTile(
                  leading: Icon(
                    font == selected ? Icons.check_circle : Icons.circle_outlined,
                    color: font == selected ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text(font.label),
                  onTap: () {
                    ref.read(appFontFamilyProvider.notifier).state = font;
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showFontScaleBottomSheet(BuildContext context) async {
    final scales = [0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5];
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        final selected = ref.read(appFontScaleProvider);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '字体缩放',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              for (final scale in scales)
                ListTile(
                  leading: Icon(
                    scale == selected ? Icons.check_circle : Icons.circle_outlined,
                    color: scale == selected ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text('${(scale * 100).toInt()}%'),
                  onTap: () {
                    ref.read(appFontScaleProvider.notifier).state = scale;
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showFontWeightBottomSheet(BuildContext context) async {
    final weights = [300.0, 400.0, 500.0, 600.0, 700.0];
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        final selected = ref.read(appFontWeightProvider);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '字重调整',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              for (final weight in weights)
                ListTile(
                  leading: Icon(
                    weight == selected ? Icons.check_circle : Icons.circle_outlined,
                    color: weight == selected ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text(
                    weight.toInt().toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.values.firstWhere(
                        (w) => w.value == weight.toInt(),
                        orElse: () => FontWeight.normal,
                      ),
                    ),
                  ),
                  onTap: () {
                    ref.read(appFontWeightProvider.notifier).state = weight;
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackgroundGallerySection(BuildContext context) {
    return _buildSectionCard(
      context,
      icon: Icons.wallpaper_outlined,
      title: '背景',
      subtitle: '点击 + 上传背景图，长按可删除。',
      child: _isLoadingBackgrounds
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _backgroundPaths.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return GestureDetector(
                    onTap: _uploadBackground,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 28,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                    ),
                  );
                }
                final path = _backgroundPaths[index - 1];
                return GestureDetector(
                  onLongPress: () => _confirmDeleteBackground(path),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(path), fit: BoxFit.cover),
                  ),
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
      subtitle: '手机切换主导航风格，平板保持侧边栏。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: _navigationStyleOptions.map((option) {
              final selected = option.preference == selectedNavigationStyle;
              final colorScheme = Theme.of(context).colorScheme;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: option == _navigationStyleOptions.last ? 0 : 6,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (selected) return;
                      unawaited(
                        ref
                            .read(
                              appNavigationStylePreferenceProvider.notifier,
                            )
                            .setPreference(option.preference),
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? colorScheme.secondaryContainer
                            : colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                          width: selected ? 1.4 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            option.icon,
                            size: 16,
                            color: selected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            option.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 8),
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
                  icon,
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
                      title,
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
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
          child,
        ],
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

  @override
  Widget build(BuildContext context) {
    final navigationState = ref.watch(appShellNavigationProvider);

    return Row(
      children: [
        _buildThemeModeStyleTab(
          context,
          tab: AppShellTab.bookshelf,
          label: '书架',
          icon: Icons.auto_stories_outlined,
          active: navigationState.showBookshelf,
          locked: false,
        ),
        const SizedBox(width: 6),
        _buildThemeModeStyleTab(
          context,
          tab: AppShellTab.discover,
          label: '发现',
          icon: Icons.explore_outlined,
          active: navigationState.showDiscover,
          locked: false,
        ),
        const SizedBox(width: 6),
        _buildThemeModeStyleTab(
          context,
          tab: AppShellTab.stats,
          label: '统计',
          icon: Icons.bar_chart_outlined,
          active: navigationState.showStats,
          locked: false,
        ),
        const SizedBox(width: 6),
        _buildThemeModeStyleTab(
          context,
          tab: AppShellTab.mine,
          label: '我的',
          icon: Icons.person_outline,
          active: true,
          locked: true,
        ),
      ],
    );
  }

  Widget _buildThemeModeStyleTab(
    BuildContext context, {
    required AppShellTab tab,
    required String label,
    required IconData icon,
    required bool active,
    required bool locked,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(
          right: tab == AppShellTab.mine ? 0 : 6,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: locked || _isSaving ? null : () => _toggle(tab, !active),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
            decoration: BoxDecoration(
              color:
                  active
                      ? colorScheme.secondaryContainer
                      : colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    active
                        ? colorScheme.primary
                        : colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: active ? 1.4 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color:
                      active
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        active
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onSurfaceVariant,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
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
    });

    try {
      await ref
          .read(appShellNavigationProvider.notifier)
          .setTabVisible(tab, enabled);
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
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
