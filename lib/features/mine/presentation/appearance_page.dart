import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/navigation/app_navigation_style_provider.dart';
import '../../../app/shell_navigation_provider.dart';
import '../../../app/theme/app_interface_typography_provider.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../app/theme/app_theme_provider.dart';
import '../../../app/theme/app_theme_seed_provider.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../../core/media/image_selection_service.dart';
import '../application/cover_gallery_provider.dart';
import '../application/advanced_theme_provider.dart';
import '../../reader/application/reader_font_registry_service.dart';

enum AppearanceSection { appearance, tabBar, cover, background }

class AppearancePage extends ConsumerStatefulWidget {
  const AppearancePage({
    super.key,
    this.section = AppearanceSection.appearance,
  });

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
  final ReaderFontRegistryService _fontRegistryService =
      ReaderFontRegistryService();
  final ImageSelectionService _imageSelectionService = ImageSelectionService();
  List<ReaderCustomFontEntry> _availableCustomFonts = const [];

  @override
  void initState() {
    super.initState();
    _loadBackgrounds();
    unawaited(_loadAvailableFonts());
  }

  Future<void> _loadBackgrounds() async {
    final dir = await getApplicationDocumentsDirectory();
    final bgDir = Directory('${dir.path}/backgrounds');
    final paths = <String>[];
    if (await bgDir.exists()) {
      final files =
          bgDir
              .listSync()
              .whereType<File>()
              .where(
                (f) =>
                    f.path.endsWith('.jpg') ||
                    f.path.endsWith('.jpeg') ||
                    f.path.endsWith('.png') ||
                    f.path.endsWith('.webp') ||
                    f.path.endsWith('.gif'),
              )
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

  Future<void> _loadAvailableFonts() async {
    final fonts = await _fontRegistryService.listRegisteredFonts();
    if (!mounted) {
      return;
    }
    setState(() {
      _availableCustomFonts = fonts;
    });
  }

  Future<void> _uploadBackground() async {
    try {
      final source = await _selectBackgroundImageSource();
      if (source == null || !mounted) {
        return;
      }

      final pickedImages = await _imageSelectionService.pickImages(
        confirmButtonText: '选择背景',
        allowedExtensions: const {'jpg', 'jpeg', 'png', 'webp', 'gif'},
        source: source,
      );
      if (pickedImages.isEmpty || !mounted) {
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final bgDir = Directory('${dir.path}/backgrounds');
      if (!await bgDir.exists()) {
        await bgDir.create(recursive: true);
      }

      final savedPaths = <String>[];
      for (final picked in pickedImages) {
        final extension = _imageExtensionForName(picked.name);
        final fileName =
            '${DateTime.now().microsecondsSinceEpoch}_${savedPaths.length}_bg.$extension';
        final destPath = '${bgDir.path}/$fileName';
        final destFile = File(destPath);
        await destFile.writeAsBytes(picked.bytes, flush: true);
        savedPaths.add(destPath);
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _backgroundPaths = <String>[..._backgroundPaths, ...savedPaths];
      });
      _showMessage('已添加 ${savedPaths.length} 张背景');
    } on ImageSelectionException catch (error) {
      _showMessage(error.message);
    } on PlatformException catch (error) {
      _showMessage('选择背景失败：${error.message ?? error.code}');
    } catch (error) {
      _showMessage('添加背景失败：$error');
    }
  }

  Future<ImageSelectionSource?> _selectBackgroundImageSource() async {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return ImageSelectionSource.files;
    }

    return showModalBottomSheet<ImageSelectionSource>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('相册'),
                  subtitle: const Text('从系统照片库选择一张图片'),
                  onTap:
                      () => Navigator.of(
                        context,
                      ).pop(ImageSelectionSource.gallery),
                ),
                ListTile(
                  leading: Icon(
                    Icons.folder_open_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('文件'),
                  subtitle: const Text('从文件 App 或本地目录选择图片'),
                  onTap:
                      () =>
                          Navigator.of(context).pop(ImageSelectionSource.files),
                ),
              ],
            ),
          ),
        );
      },
    );
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
      builder:
          (context) => AlertDialog(
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

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    final activeAdvancedTheme =
        ref.watch(activeAdvancedThemeProvider).valueOrNull;
    final backdrop = resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      activeAdvancedTheme,
    );
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/mine');
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(_pageTitle(widget.section)),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        body: LayoutBuilder(
          builder: (context, _) {
            final maxWidth = AppLayout.pageContentMaxWidth(
              context,
              maxWidth: AppLayout.settingsContentMaxWidth,
            );

            return DecoratedBox(
              decoration: buildAdvancedThemeBackdropDecoration(backdrop),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      topInset + 12,
                      horizontal,
                      12,
                    ),
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
      sections.add(_buildAdvancedThemeSummarySection(context));
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
      sections.add(_buildFontSection(context));
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
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
        children: _themeModeOptions
            .map((option) {
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
            })
            .toList(growable: false),
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
        children: appThemeSeedOptions
            .map((option) {
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
                      border:
                          selected
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
                      boxShadow:
                          selected
                              ? [
                                BoxShadow(
                                  color: option.color.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                              : null,
                    ),
                    child:
                        selected
                            ? Icon(
                              Icons.check_rounded,
                              size: 16,
                              color:
                                  ThemeData.estimateBrightnessForColor(
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
            })
            .toList(growable: false),
      ),
    );
  }

  Widget _buildAdvancedThemeSummarySection(BuildContext context) {
    final activeAdvancedTheme = ref.watch(activeAdvancedThemeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return _buildSectionCard(
      context,
      icon: Icons.auto_awesome_outlined,
      title: '高级主题',
      subtitle: '查看当前状态并前往主题列表管理。',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push('/appearance/advanced-themes'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.palette_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  activeAdvancedTheme.when(
                    data: (theme) => theme == null ? '未启用' : '当前：${theme.name}',
                    loading: () => '读取中',
                    error: (_, _) => '未启用',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
      ),
    );
  }

  Widget _buildCoverGallerySection(BuildContext context) {
    final activeTheme = ref.watch(activeAdvancedThemeProvider).valueOrNull;
    final coverGalleries =
        ref.watch(coverGalleriesProvider).valueOrNull ?? const [];
    final activeGalleryId = activeTheme?.coverGalleryId?.trim() ?? '';
    final activeGalleryName = coverGalleries
        .where((gallery) => gallery.id == activeGalleryId)
        .map((gallery) => gallery.name.trim())
        .where((name) => name.isNotEmpty)
        .cast<String?>()
        .firstWhere((name) => name != null, orElse: () => null);

    return _buildSectionCard(
      context,
      icon: Icons.photo_library_outlined,
      title: '封面图集',
      subtitle:
          activeGalleryName == null
              ? '预览当前高级主题的实际封面效果，未绑定图集时会回退为文字封面。'
              : '当前高级主题已绑定：$activeGalleryName',
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
                        ResolvedBookCoverView(
                          cover: resolveBookCover(
                            activeTheme: activeTheme,
                            galleries: coverGalleries,
                            bookId: 'appearance_cover_sample_$sample',
                            sourceId: 'appearance.preview',
                            detailUrl:
                                'appearance://cover/${sample['title'] ?? ''}',
                          ),
                          title: sample['title'] ?? '',
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
    final fontSettings = ref.watch(appInterfaceFontSettingsProvider);
    final fontScale = ref.watch(appInterfaceTextScaleProvider);
    final fontWeight = ref.watch(appInterfaceFontWeightProvider);

    return _buildSectionCard(
      context,
      icon: Icons.text_fields_outlined,
      title: '应用界面字体',
      subtitle: '仅影响书架、发现、我的等外部页面，阅读器保持独立设置。',
      child: Column(
        children: [
          _buildFontFamilyTile(context, fontSettings),
          const SizedBox(height: 8),
          _buildFontScaleTile(context, fontScale),
          const SizedBox(height: 8),
          _buildFontWeightTile(context, fontWeight),
        ],
      ),
    );
  }

  Widget _buildFontFamilyTile(
    BuildContext context,
    AppInterfaceFontSettings selectedFont,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final fontLabel = _currentInterfaceFontLabel(selectedFont);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showFontFamilyBottomSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.font_download_outlined,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '界面字体',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              fontLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
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

  Widget _buildFontScaleTile(BuildContext context, double scale) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showFontScaleBottomSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.zoom_in_outlined,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '界面缩放',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${(scale * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
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

  Widget _buildFontWeightTile(BuildContext context, int weight) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showFontWeightBottomSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.format_bold,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '界面字重',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              weight.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
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

  Future<void> _showFontFamilyBottomSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: _FontFamilyPickerDialog(
              fontRegistryService: _fontRegistryService,
              initialFonts: _availableCustomFonts,
            ),
          ),
        );
      },
    );
    await _loadAvailableFonts();
  }

  Future<void> _showFontScaleBottomSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        var draftValue = ref.read(appInterfaceTextScaleProvider);
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '界面缩放',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(draftValue * 100).round()}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '范围 60% - 150%，基于系统字体大小微调外部页面',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Slider(
                      min: 0.6,
                      max: 1.5,
                      divisions: 18,
                      label: '${(draftValue * 100).round()}%',
                      value: draftValue,
                      onChanged: (value) {
                        setSheetState(() {
                          draftValue = value;
                        });
                        unawaited(
                          ref
                              .read(appInterfaceTextScaleProvider.notifier)
                              .setScale(value),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '60%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        Text(
                          '150%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showFontWeightBottomSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        var draftValue = ref.read(appInterfaceFontWeightProvider).toDouble();
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final displayWeight = draftValue.round();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '界面字重',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$displayWeight',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: appInterfaceFontWeightValue(displayWeight),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '范围 100 - 900，数值越大文字越粗',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Slider(
                      min: 100,
                      max: 900,
                      divisions: 8,
                      label: '$displayWeight',
                      value: draftValue,
                      onChanged: (value) {
                        final normalized =
                            ((value / 100).round() * 100)
                                .clamp(100, 900)
                                .toDouble();
                        setSheetState(() {
                          draftValue = normalized;
                        });
                        unawaited(
                          ref
                              .read(appInterfaceFontWeightProvider.notifier)
                              .setWeight(normalized.toInt()),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: const [
                            100,
                            200,
                            300,
                            400,
                            500,
                            600,
                            700,
                            800,
                            900,
                          ]
                          .map(
                            (weight) => Chip(
                              label: Text('$weight'),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _currentInterfaceFontLabel(AppInterfaceFontSettings settings) {
    if (settings.fontSource == AppInterfaceFontSource.custom) {
      final familyKey = settings.fontFamilyKey?.trim() ?? '';
      if (familyKey.isEmpty) {
        return '自定义字体';
      }
      for (final entry in _availableCustomFonts) {
        if (entry.fontFamilyKey == familyKey) {
          return entry.displayName;
        }
      }
      return '自定义字体';
    }

    return appInterfaceSystemFontPresetLabel(settings.systemFontPreset);
  }

  Widget _buildBackgroundGallerySection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
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
                Icons.wallpaper_outlined,
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
                    '应用背景',
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '移动端可选相册或文件，桌面端从文件选择。长按图片可删除。',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '新增背景',
              onPressed: _uploadBackground,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_isLoadingBackgrounds)
          const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              const columns = 3;
              final itemWidth =
                  (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

              if (_backgroundPaths.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 8,
                  ),
                  child: Text(
                    '还没有自定义应用背景，点击右上角 + 号开始。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _backgroundPaths
                    .map((path) {
                      return GestureDetector(
                        onLongPress: () => _confirmDeleteBackground(path),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: itemWidth,
                                height: itemWidth * 1.28,
                                child: Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '长按删除',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(growable: false),
              );
            },
          ),
      ],
    );
  }

  String _imageExtensionForName(String fileName) {
    final normalized = fileName.trim().toLowerCase();
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex >= normalized.length - 1) {
      return 'png';
    }
    final extension = normalized.substring(dotIndex + 1);
    return switch (extension) {
      'jpg' || 'jpeg' => 'jpg',
      'png' => 'png',
      'webp' => 'webp',
      'gif' => 'gif',
      _ => 'png',
    };
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
            children: _navigationStyleOptions
                .map((option) {
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
                })
                .toList(growable: false),
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
    Widget? trailing,
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
              if (trailing != null) ...[const SizedBox(width: 10), trailing],
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
    final tabs = <
      ({AppShellTab tab, String label, IconData icon, bool active, bool locked})
    >[
      (
        tab: AppShellTab.home,
        label: '首页',
        icon: Icons.home_outlined,
        active: navigationState.showHome,
        locked: false,
      ),
      (
        tab: AppShellTab.bookshelf,
        label: '书架',
        icon: Icons.auto_stories_outlined,
        active: navigationState.showBookshelf,
        locked: false,
      ),
      (
        tab: AppShellTab.discover,
        label: '发现',
        icon: Icons.explore_outlined,
        active: navigationState.showDiscover,
        locked: false,
      ),
      (
        tab: AppShellTab.stats,
        label: '统计',
        icon: Icons.bar_chart_outlined,
        active: navigationState.showStats,
        locked: false,
      ),
      (
        tab: AppShellTab.mine,
        label: '我的',
        icon: Icons.person_outline,
        active: true,
        locked: true,
      ),
    ];

    return Row(
      children: [
        for (var index = 0; index < tabs.length; index++) ...[
          _buildThemeModeStyleTab(
            context,
            tab: tabs[index].tab,
            label: tabs[index].label,
            icon: tabs[index].icon,
            active: tabs[index].active,
            locked: tabs[index].locked,
            isLast: index == tabs.length - 1,
          ),
          if (index != tabs.length - 1) const SizedBox(width: 6),
        ],
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
    required bool isLast,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: isLast ? 0 : 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: locked || _isSaving ? null : () => _toggle(tab, !active),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
            decoration: BoxDecoration(
              color:
                  active ? colorScheme.secondaryContainer : colorScheme.surface,
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

class _FontFamilyPickerDialog extends ConsumerStatefulWidget {
  const _FontFamilyPickerDialog({
    required this.fontRegistryService,
    required this.initialFonts,
  });

  final ReaderFontRegistryService fontRegistryService;
  final List<ReaderCustomFontEntry> initialFonts;

  @override
  ConsumerState<_FontFamilyPickerDialog> createState() =>
      _FontFamilyPickerDialogState();
}

class _FontFamilyPickerDialogState
    extends ConsumerState<_FontFamilyPickerDialog> {
  late List<ReaderCustomFontEntry> _availableCustomFonts;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _availableCustomFonts = List<ReaderCustomFontEntry>.from(
      widget.initialFonts,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedFont = ref.watch(appInterfaceFontSettingsProvider);
    final selectedCustomFont = _resolveSelectedCustomFont(selectedFont);

    Widget buildFontChoiceTile({
      required String label,
      required bool selected,
      required Future<void> Function()? onTap,
      IconData? icon,
      bool loading = false,
    }) {
      final colorScheme = Theme.of(context).colorScheme;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap == null ? null : () => unawaited(onTap()),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color:
                  selected
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerLow,
              border: Border.all(
                color:
                    selected
                        ? colorScheme.primary.withValues(alpha: 0.45)
                        : colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                else if (icon != null)
                  Icon(
                    icon,
                    size: 14,
                    color:
                        selected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                  ),
                if (icon != null || loading) const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color:
                          selected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 320,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '选择字体',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '与阅读器共用同一批已导入字体，只调整应用界面全局显示。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.35,
                children: [
                  buildFontChoiceTile(
                    label: appInterfaceSystemFontPresetLabel(
                      AppInterfaceSystemFontPreset.defaultSans,
                    ),
                    selected:
                        selectedFont.fontSource ==
                            AppInterfaceFontSource.system &&
                        selectedFont.systemFontPreset ==
                            AppInterfaceSystemFontPreset.defaultSans,
                    icon: Icons.text_fields_rounded,
                    onTap:
                        () => _selectSystemFont(
                          AppInterfaceSystemFontPreset.defaultSans,
                        ),
                  ),
                  buildFontChoiceTile(
                    label: appInterfaceSystemFontPresetLabel(
                      AppInterfaceSystemFontPreset.serif,
                    ),
                    selected:
                        selectedFont.fontSource ==
                            AppInterfaceFontSource.system &&
                        selectedFont.systemFontPreset ==
                            AppInterfaceSystemFontPreset.serif,
                    icon: Icons.format_shapes_rounded,
                    onTap:
                        () => _selectSystemFont(
                          AppInterfaceSystemFontPreset.serif,
                        ),
                  ),
                  buildFontChoiceTile(
                    label: appInterfaceSystemFontPresetLabel(
                      AppInterfaceSystemFontPreset.monospace,
                    ),
                    selected:
                        selectedFont.fontSource ==
                            AppInterfaceFontSource.system &&
                        selectedFont.systemFontPreset ==
                            AppInterfaceSystemFontPreset.monospace,
                    icon: Icons.code_rounded,
                    onTap:
                        () => _selectSystemFont(
                          AppInterfaceSystemFontPreset.monospace,
                        ),
                  ),
                  ..._availableCustomFonts.map(
                    (entry) => buildFontChoiceTile(
                      label: entry.displayName,
                      selected:
                          selectedCustomFont?.fontFamilyKey ==
                          entry.fontFamilyKey,
                      icon: Icons.font_download_outlined,
                      onTap: () => _selectCustomFont(entry),
                    ),
                  ),
                  buildFontChoiceTile(
                    label: '自定义',
                    selected: false,
                    loading: _isImporting,
                    icon: Icons.upload_file_rounded,
                    onTap: _importCustomFontFromSheet,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ReaderCustomFontEntry? _resolveSelectedCustomFont(
    AppInterfaceFontSettings settings,
  ) {
    if (settings.fontSource != AppInterfaceFontSource.custom) {
      return null;
    }
    final familyKey = settings.fontFamilyKey?.trim() ?? '';
    if (familyKey.isEmpty) {
      return null;
    }
    for (final entry in _availableCustomFonts) {
      if (entry.fontFamilyKey == familyKey) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _selectSystemFont(AppInterfaceSystemFontPreset preset) async {
    await ref
        .read(appInterfaceFontSettingsProvider.notifier)
        .setSystemFont(preset);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _selectCustomFont(ReaderCustomFontEntry entry) async {
    await ref
        .read(appInterfaceFontSettingsProvider.notifier)
        .setCustomFont(entry);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _importCustomFontFromSheet() async {
    if (_isImporting) {
      return;
    }
    setState(() {
      _isImporting = true;
    });

    try {
      final imported = await widget.fontRegistryService.pickAndImportFont();
      if (imported == null) {
        return;
      }
      final refreshedFonts =
          await widget.fontRegistryService.listRegisteredFonts();
      if (!mounted) {
        return;
      }
      setState(() {
        _availableCustomFonts = refreshedFonts;
      });
      await ref
          .read(appInterfaceFontSettingsProvider.notifier)
          .setCustomFont(imported);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on PlatformException catch (error) {
      _showMessage('导入字体失败：${error.message ?? error.code}');
    } on ReaderFontRegistryException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('导入字体失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
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
