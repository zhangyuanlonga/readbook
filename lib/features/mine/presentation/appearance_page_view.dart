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
    final routeTopBar = _buildRouteTopBar(context);
    final topInset = mediaQuery.padding.top + routeTopBar.preferredSize.height;
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
        appBar: routeTopBar,
        body: LayoutBuilder(
          builder: (context, _) {
            final maxWidth = AppLayout.pageContentMaxWidth(
              context,
              maxWidth:
                  widget.section == AppearanceSection.appearance &&
                          metrics.isExpandedWindow
                      ? 1120
                      : AppLayout.settingsContentMaxWidth,
            );
            final sections = _buildSectionContent(
              context,
              navigationState,
              selectedThemeMode: selectedThemeMode,
              selectedSeedColor: selectedSeedColor,
              selectedNavigationStyle: selectedNavigationStyle,
              standardNavigationAppearance: standardNavigationAppearance,
              cupertinoDockAppearance: cupertinoDockAppearance,
              showNavigationLabels: showNavigationLabels,
            );
            final content =
                widget.section == AppearanceSection.appearance &&
                        metrics.isExpandedWindow
                    ? _buildDesktopAppearanceWorkspace(
                      context,
                      sections: sections,
                      horizontal: horizontal,
                      topInset: topInset,
                      bottomInset: bottomInset,
                    )
                    : ListView(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        topInset + metrics.contentGap,
                        horizontal,
                        metrics.sectionGap + bottomInset,
                      ),
                      children: _buildMotionEntries(sections),
                    );

            return DecoratedBox(
              decoration: buildAdvancedThemeBackdropDecoration(backdrop),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildRouteTopBar(BuildContext context) {
    final actions =
        widget.section == AppearanceSection.background
            ? <AdaptiveOverflowToolbarItem>[
              AdaptiveOverflowToolbarItem(
                icon: Icons.add_rounded,
                label: '新增背景',
                priority: 10,
                onPressed: _uploadBackground,
              ),
            ]
            : const <AdaptiveOverflowToolbarItem>[];
    final mobileActions =
        widget.section == AppearanceSection.background
            ? <Widget>[
              IconButton(
                tooltip: '新增背景',
                onPressed: _uploadBackground,
                icon: const Icon(Icons.add_rounded),
              ),
            ]
            : const <Widget>[];
    return buildMineRouteTopBar(
      context: context,
      title: _pageTitle(widget.section),
      subtitle: _pageSubtitle(widget.section),
      actions: actions,
      mobileActions: mobileActions,
    );
  }

  String _pageTitle(AppearanceSection section) {
    return switch (section) {
      AppearanceSection.appearance => '应用外观',
      AppearanceSection.tabBar => '底栏',
      AppearanceSection.cover => '封面',
      AppearanceSection.background => '应用背景',
    };
  }

  String? _pageSubtitle(AppearanceSection section) {
    return switch (section) {
      AppearanceSection.appearance => '主题、颜色、字体与导航外观',
      AppearanceSection.tabBar => '底栏图标和导航展示',
      AppearanceSection.cover => '书架与主题封面素材',
      AppearanceSection.background => '应用背景素材管理',
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
    final isDesktopAppearanceOnly =
        widget.section == AppearanceSection.appearance &&
        AppLayout.isDesktopLike(
          context,
          isWeb: kIsWeb,
          platform: Theme.of(context).platform,
        );
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
      if (!isDesktopAppearanceOnly) {
        sections.addAll([
          SizedBox(height: sectionGap),
          _buildNavigationStyleSection(
            context,
            selectedNavigationStyle: selectedNavigationStyle,
            standardNavigationAppearance: standardNavigationAppearance,
            cupertinoDockAppearance: cupertinoDockAppearance,
            showNavigationLabels: showNavigationLabels,
          ),
          SizedBox(height: sectionGap),
          _buildSectionCard(
            context,
            icon: Icons.space_dashboard_outlined,
            title: '底部菜单',
            subtitle: '控制底部主导航展示项，至少保留一个内容入口。',
            child: const _AppearanceNavigationVisibilityPanel(),
          ),
          SizedBox(height: sectionGap),
          _buildFontSection(context),
          SizedBox(height: sectionGap),
          const AppearanceOtherSettingsCard(),
        ]);
      }
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

  List<Widget> _buildMotionEntries(List<Widget> children) {
    return [
      for (var index = 0; index < children.length; index++)
        AppFadeSlideTransition(
          delay: Duration(milliseconds: (index * 28).clamp(0, 140)),
          child: children[index],
        ),
    ];
  }

  Widget _buildDesktopAppearanceWorkspace(
    BuildContext context, {
    required List<Widget> sections,
    required double horizontal,
    required double topInset,
    required double bottomInset,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    final cards = sections
        .where((widget) => widget is! SizedBox)
        .toList(growable: false);
    final leftCards = <Widget>[];
    final rightCards = <Widget>[];
    for (var index = 0; index < cards.length; index += 1) {
      if (index.isEven) {
        leftCards.add(cards[index]);
      } else {
        rightCards.add(cards[index]);
      }
    }
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        topInset + metrics.contentGap,
        horizontal,
        metrics.sectionGap + bottomInset,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: _buildDesktopColumnEntries(leftCards, startIndex: 0),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              children: _buildDesktopColumnEntries(rightCards, startIndex: 1),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDesktopColumnEntries(
    List<Widget> children, {
    required int startIndex,
  }) {
    final entries = <Widget>[];
    for (var index = 0; index < children.length; index += 1) {
      if (index > 0) {
        entries.add(const SizedBox(height: 14));
      }
      entries.add(
        AppFadeSlideTransition(
          delay: Duration(
            milliseconds: ((startIndex + index * 2) * 28).clamp(0, 140),
          ),
          child: children[index],
        ),
      );
    }
    return entries;
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
                  child: Builder(
                    builder: (buttonContext) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          if (selected) return;
                          unawaited(
                            _setAppThemeModeWithReveal(
                              buttonContext,
                              option.mode,
                            ),
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
                      );
                    },
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  Future<void> _setAppThemeModeWithReveal(
    BuildContext sourceContext,
    ThemeMode mode,
  ) async {
    final overlay = CircularThemeRevealOverlay.of(sourceContext);
    if (overlay == null) {
      await ref.read(appThemeModeProvider.notifier).setThemeMode(mode);
      return;
    }
    final center = CircularThemeRevealOverlay.getCenterFromContext(
      sourceContext,
    );
    await overlay.startTransition(
      center: center,
      reverse: false,
      onThemeChange: () {
        unawaited(ref.read(appThemeModeProvider.notifier).setThemeMode(mode));
      },
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            for (
              var index = 0;
              index < appThemeSeedOptions.length;
              index++
            ) ...[
              Builder(
                builder: (context) {
                  final option = appThemeSeedOptions[index];
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
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.4),
                                    width: 0.5,
                                  ),
                          boxShadow:
                              selected
                                  ? [
                                    BoxShadow(
                                      color: option.color.withValues(
                                        alpha: 0.4,
                                      ),
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
                },
              ),
              if (index < appThemeSeedOptions.length - 1)
                const SizedBox(width: 10),
            ],
          ],
        ),
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
      subtitle: '高级主题会覆盖应用基础主题',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push('/appearance/advanced-themes'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                        data:
                            (theme) =>
                                theme == null ? '未启用' : '当前：${theme.name}',
                        loading: () => '读取中',
                        error: (_, _) => '未启用',
                      ),
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
              activeAdvancedTheme.when(
                data:
                    (theme) =>
                        theme == null
                            ? const SizedBox.shrink()
                            : Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _buildAdvancedThemeSemanticSummary(
                                context,
                                theme,
                              ),
                            ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedThemeSemanticSummary(
    BuildContext context,
    AppAdvancedTheme theme,
  ) {
    final lightPreviews = _buildThemeSemanticModePreviews(
      theme,
      AppAdvancedThemeMode.light,
    );
    final darkPreviews = _buildThemeSemanticModePreviews(
      theme,
      AppAdvancedThemeMode.dark,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildThemeSemanticModeSummaryRow(
          context,
          label: '浅色',
          previews: lightPreviews,
        ),
        const SizedBox(height: 8),
        _buildThemeSemanticModeSummaryRow(
          context,
          label: '深色',
          previews: darkPreviews,
        ),
      ],
    );
  }

  List<ThemeSemanticColorPreview> _buildThemeSemanticModePreviews(
    AppAdvancedTheme theme,
    AppAdvancedThemeMode mode,
  ) {
    final seedColor = ref.read(appSeedColorProvider);
    final colorScheme =
        mode == AppAdvancedThemeMode.light
            ? buildAppLightColorScheme(seedColor)
            : buildAppDarkColorScheme(seedColor);
    final config = theme.configFor(mode);
    final palette = resolveAdvancedThemePaletteFromModeConfig(
      colorScheme,
      config,
    );
    final backdrop = resolveAdvancedThemeBackdropFromModeConfig(
      colorScheme,
      config,
    );
    return buildColorCardThemeSemanticPreviews(
      palette: palette,
      backdrop: backdrop,
    );
  }

  Widget _buildThemeSemanticModeSummaryRow(
    BuildContext context, {
    required String label,
    required List<ThemeSemanticColorPreview> previews,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label 语义色块',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final preview in previews)
                _buildThemeSemanticSummaryChip(context, preview: preview),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSemanticSummaryChip(
    BuildContext context, {
    required ThemeSemanticColorPreview preview,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: preview.color,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            themeSemanticFieldSpecFor(preview.id).label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
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
      subtitle: '仅影响非阅读器页面',
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
    await _loadAvailableFonts();
    if (!context.mounted) {
      return;
    }
    await showAdaptiveActionSurface<void>(
      context: context,
      maxWidth: 560,
      maxHeightFactor: 0.76,
      padding: EdgeInsets.zero,
      builder: (context) {
        return _FontFamilyPickerDialog(
          fontRegistryService: _fontRegistryService,
          initialFonts: _availableCustomFonts,
        );
      },
    );
    await _loadAvailableFonts();
  }

  Future<void> _showFontScaleBottomSheet(BuildContext context) async {
    await showAdaptiveActionSurface<void>(
      context: context,
      maxWidth: 420,
      builder: (context) {
        var draftValue = ref.read(appInterfaceTextScaleProvider);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '界面缩放',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
                      Text('60%', style: Theme.of(context).textTheme.bodySmall),
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
        );
      },
    );
  }

  Future<void> _showFontWeightBottomSheet(BuildContext context) async {
    await showAdaptiveActionSurface<void>(
      context: context,
      maxWidth: 420,
      builder: (context) {
        var draftValue = ref.read(appInterfaceFontWeightProvider).toDouble();
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final displayWeight = draftValue.round();
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '界面字重',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
    final activeAdvancedTheme =
        ref.watch(activeAdvancedThemeProvider).valueOrNull;
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

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                itemCount: _visibleBackgroundPaths.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: 1 / 1.28,
                ),
                itemBuilder: (context, index) {
                  final path = _visibleBackgroundPaths[index];
                  final usageLabels = _backgroundUsageLabels(
                    path,
                    activeAdvancedTheme,
                    reader: false,
                  );
                  return GestureDetector(
                    onTap: () => _previewBackground(path),
                    onLongPress: () => _confirmDeleteBackground(path),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: LazyFileImage(
                            path: path,
                            fit: BoxFit.cover,
                            cacheWidth: 420,
                            borderRadius: BorderRadius.circular(12),
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
                        if (usageLabels.isNotEmpty)
                          Positioned(
                            left: 6,
                            top: 6,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final label in usageLabels)
                                  ImageResourceUsageBadge(label: label),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  List<String> _backgroundUsageLabels(
    String path,
    AppAdvancedTheme? activeTheme, {
    required bool reader,
  }) {
    if (activeTheme == null) {
      return const <String>[];
    }
    final lightPath =
        reader
            ? activeTheme.lightConfig.readerWallpaperPath
            : activeTheme.lightConfig.wallpaperPath;
    final darkPath =
        reader
            ? activeTheme.darkConfig.readerWallpaperPath
            : activeTheme.darkConfig.wallpaperPath;
    final usedByLight = _sameResourcePath(path, lightPath);
    final usedByDark = _sameResourcePath(path, darkPath);
    if (usedByLight && usedByDark) {
      return const <String>['主题默认'];
    }
    return <String>[if (usedByLight) '浅色默认', if (usedByDark) '深色默认'];
  }

  bool _sameResourcePath(String left, String? right) {
    final normalizedLeft = left.trim();
    final normalizedRight = right?.trim() ?? '';
    if (normalizedLeft.isEmpty || normalizedRight.isEmpty) {
      return false;
    }
    return normalizedLeft == normalizedRight ||
        p.normalize(normalizedLeft) == p.normalize(normalizedRight);
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
      subtitle: '切换自己喜欢的主导航风格吧',
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
