part of 'appearance_page.dart';

extension on _AppearancePageState {
  List<String> get _visibleBackgroundPaths {
    final keyword = _backgroundSearchQuery.trim().toLowerCase();
    if (keyword.isEmpty) {
      return _backgroundPaths;
    }
    return _backgroundPaths
        .where((path) => p.basename(path).toLowerCase().contains(keyword))
        .toList(growable: false);
  }

  Widget _buildAppearancePage(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final horizontal = metrics.pagePadding;
    final selectedThemeMode = ref.watch(appThemeModeProvider);
    final selectedSeedColor = ref.watch(appSeedColorProvider);
    final selectedNavigationStyle = ref.watch(
      appNavigationStylePreferenceProvider,
    );
    final standardNavigationAppearance = ref.watch(
      appStandardNavigationBarAppearanceProvider,
    );
    final cupertinoDockAppearance = ref.watch(
      appCupertinoDockAppearanceProvider,
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
    final mediaQuery = MediaQuery.of(context);
    final topInset = mediaQuery.padding.top + kToolbarHeight;
    final bottomInset = mediaQuery.viewPadding.bottom;

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
          actions: [
            if (widget.section == AppearanceSection.background)
              IconButton(
                tooltip: '新增背景',
                onPressed: _uploadBackground,
                icon: const Icon(Icons.add_rounded),
              ),
          ],
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
                      topInset + metrics.contentGap,
                      horizontal,
                      metrics.sectionGap + bottomInset,
                    ),
                    children: _buildSectionContent(
                      context,
                      navigationState,
                      selectedThemeMode: selectedThemeMode,
                      selectedSeedColor: selectedSeedColor,
                      selectedNavigationStyle: selectedNavigationStyle,
                      standardNavigationAppearance:
                          standardNavigationAppearance,
                      cupertinoDockAppearance: cupertinoDockAppearance,
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
      AppearanceSection.background => '应用背景',
    };
  }

  List<Widget> _buildSectionContent(
    BuildContext context,
    AppShellNavigationState navigationState, {
    required ThemeMode selectedThemeMode,
    required Color selectedSeedColor,
    required AppNavigationStylePreference selectedNavigationStyle,
    required AppStandardNavigationBarAppearance standardNavigationAppearance,
    required AppCupertinoDockAppearance cupertinoDockAppearance,
    required bool showNavigationLabels,
  }) {
    final sectionGap = AppAdaptiveMetrics.of(context).contentGap;
    final sections = <Widget>[];

    if (widget.section == AppearanceSection.appearance) {
      sections.add(
        _buildThemeModeSection(context, selectedThemeMode: selectedThemeMode),
      );
      sections.add(SizedBox(height: sectionGap));
      sections.add(
        _buildThemeColorSection(context, selectedSeedColor: selectedSeedColor),
      );
      sections.add(SizedBox(height: sectionGap));
      sections.add(_buildAdvancedThemeSummarySection(context));
      sections.add(SizedBox(height: sectionGap));
      sections.add(
        _buildNavigationStyleSection(
          context,
          selectedNavigationStyle: selectedNavigationStyle,
          standardNavigationAppearance: standardNavigationAppearance,
          cupertinoDockAppearance: cupertinoDockAppearance,
          showNavigationLabels: showNavigationLabels,
        ),
      );
      sections.add(SizedBox(height: sectionGap));
      sections.add(
        _buildSectionCard(
          context,
          icon: Icons.space_dashboard_outlined,
          title: '底部菜单',
          subtitle: '控制底部主导航展示项，至少保留一个内容入口。',
          child: const _AppearanceNavigationVisibilityPanel(),
        ),
      );
      sections.add(SizedBox(height: sectionGap));
      sections.add(_buildFontSection(context));
      sections.add(SizedBox(height: sectionGap));
      sections.add(const AppearanceOtherSettingsCard());
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
        children: _AppearancePageState._themeModeOptions
            .map((option) {
              final selected = option.mode == selectedThemeMode;
              final colorScheme = Theme.of(context).colorScheme;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right:
                        option == _AppearancePageState._themeModeOptions.last
                            ? 0
                            : 6,
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
    String? resolveGalleryName(String? galleryId) {
      final normalizedId = galleryId?.trim() ?? '';
      if (normalizedId.isEmpty) {
        return null;
      }
      return coverGalleries
          .where((gallery) => gallery.id == normalizedId)
          .map((gallery) => gallery.name.trim())
          .where((name) => name.isNotEmpty)
          .cast<String?>()
          .firstWhere((name) => name != null, orElse: () => null);
    }

    final lightGalleryName = resolveGalleryName(
      activeTheme?.coverGalleryIdFor(AppAdvancedThemeMode.light),
    );
    final darkGalleryName = resolveGalleryName(
      activeTheme?.coverGalleryIdFor(AppAdvancedThemeMode.dark),
    );
    final coverSubtitle = switch ((lightGalleryName, darkGalleryName)) {
      (null, null) => '预览当前高级主题的实际封面效果，未绑定图集时会回退为文字封面。',
      (final light?, final dark?) when light == dark => '当前高级主题已绑定：$light',
      (final light?, final dark?) => '当前高级主题已绑定：浅色 $light / 深色 $dark',
      (final light?, null) => '当前高级主题已绑定：浅色 $light',
      (null, final dark?) => '当前高级主题已绑定：深色 $dark',
    };

    return _buildSectionCard(
      context,
      icon: Icons.photo_library_outlined,
      title: '封面图集',
      subtitle: coverSubtitle,
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
            children: _AppearancePageState._coverGallerySamples
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
                            brightness: Theme.of(context).brightness,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompactCollectionSearchField(
          controller: _backgroundSearchController,
          hintText: '搜索应用背景文件名',
          query: _backgroundSearchQuery,
          onChanged: (value) {
            _updateBackgroundSearchState(() {
              _backgroundSearchQuery = value;
            });
          },
          onClear: () {
            _backgroundSearchController.clear();
            _updateBackgroundSearchState(() {
              _backgroundSearchQuery = '';
            });
          },
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

              if (_visibleBackgroundPaths.isEmpty) {
                return const SizedBox(
                  width: double.infinity,
                  child: ImageResourceEmptyStateCard(
                    icon: Icons.chrome_reader_mode_outlined,
                    title: '还没有应用背景',
                    description: '点击右上角新增，准备高级主题和应用可复用的背景素材。',
                  ),
                );
              }

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _visibleBackgroundPaths
                    .map((path) {
                      return GestureDetector(
                        onTap: () => _previewBackground(path),
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
                              child: const ImageResourceCornerHint(
                                label: '长按删除',
                                icon: Icons.delete_outline,
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

  Widget _buildNavigationStyleSection(
    BuildContext context, {
    required AppNavigationStylePreference selectedNavigationStyle,
    required AppStandardNavigationBarAppearance standardNavigationAppearance,
    required AppCupertinoDockAppearance cupertinoDockAppearance,
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
            children: _AppearancePageState._navigationStyleOptions
                .map((option) {
                  final selected = option.preference == selectedNavigationStyle;
                  final colorScheme = Theme.of(context).colorScheme;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right:
                            option ==
                                    _AppearancePageState
                                        ._navigationStyleOptions
                                        .last
                                ? 0
                                : 6,
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
          if (selectedNavigationStyle ==
              AppNavigationStylePreference.standard) ...[
            const SizedBox(height: 8),
            _buildStandardNavigationToggleTile(
              context,
              title: '悬浮底栏',
              description: '底栏悬浮在内容上方',
              enabled: standardNavigationAppearance.floatingBar,
              onChanged: (value) {
                unawaited(
                  ref
                      .read(appStandardNavigationBarAppearanceProvider.notifier)
                      .setFloatingBar(value),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildStandardNavigationToggleTile(
              context,
              title: '磨砂效果',
              description: '底栏启用磨砂背景效果',
              enabled: standardNavigationAppearance.frostedEffect,
              onChanged: (value) {
                unawaited(
                  ref
                      .read(appStandardNavigationBarAppearanceProvider.notifier)
                      .setFrostedEffect(value),
                );
              },
            ),
          ],
          if (selectedNavigationStyle ==
              AppNavigationStylePreference.cupertinoDock) ...[
            const SizedBox(height: 8),
            _buildStandardNavigationToggleTile(
              context,
              title: '磨砂效果',
              description: '苹果风格底栏启用磨砂背景效果',
              enabled: cupertinoDockAppearance.frostedEffect,
              onChanged: (value) {
                unawaited(
                  ref
                      .read(appCupertinoDockAppearanceProvider.notifier)
                      .setFrostedEffect(value),
                );
              },
            ),
          ],
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
    final metrics = AppAdaptiveMetrics.of(context);
    final iconBoxSize = metrics.isCompactDensity ? 26.0 : 28.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(metrics.cardRadius + 2),
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
                width: iconBoxSize,
                height: iconBoxSize,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(
                    metrics.cardRadius * 0.58,
                  ),
                ),
                child: Icon(
                  icon,
                  size: metrics.isCompactDensity ? 15 : 16,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              SizedBox(width: metrics.contentGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: metrics.isCompactDensity ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: metrics.contentGap),
                trailing,
              ],
            ],
          ),
          SizedBox(height: metrics.contentGap),
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
                  '控制底栏是否显示文字标签。',
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

  Widget _buildStandardNavigationToggleTile(
    BuildContext context, {
    required String title,
    required String description,
    required bool enabled,
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
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(value: enabled, onChanged: onChanged),
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
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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
}
