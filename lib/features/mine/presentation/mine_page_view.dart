part of 'mine_page.dart';

extension on _MinePageState {
  Widget _buildMinePage(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final platform = Theme.of(context).platform;
    final isDesktopMine = AppLayout.isDesktopLike(
      context,
      isWeb: kIsWeb,
      platform: platform,
    );
    final horizontal = metrics.pagePadding;
    final baseColorSchemeId = ref.watch(appBaseColorSchemeProvider);
    final themeSource = ref.watch(appThemeSourceProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final activeBottomNavIconGallery = ref.watch(
      effectiveBottomNavIconGalleryProvider,
    );
    final activeAdvancedTheme = ref.watch(activeAdvancedThemeProvider);
    final launchImageGalleries =
        ref.watch(launchImageGalleriesProvider).valueOrNull ?? const [];
    final advancedPalette = _resolveAdvancedPalette(
      context,
      activeAdvancedTheme.valueOrNull,
    );
    final advancedBackdrop = _resolveAdvancedBackdrop(
      context,
      activeAdvancedTheme.valueOrNull,
    );
    final navigationPreference = ref.watch(
      appNavigationStylePreferenceProvider,
    );
    final effectiveNavigationStyle = resolveAppNavigationStyle(
      navigationPreference,
      isWeb: false,
      platform: platform,
    );
    final showNavigationLabels = ref.watch(
      appNavigationLabelVisibilityProvider,
    );
    final standardNavigationAppearance = ref.watch(
      appStandardNavigationBarAppearanceProvider,
    );
    final visibilityState = ref.watch(minePageVisibilityProvider);
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final appearanceActions = _buildAppearanceActions(
      context,
      visibilityState: visibilityState,
      baseColorSchemeId: baseColorSchemeId,
      themeSource: themeSource,
      themeMode: themeMode,
      navigationPreference: navigationPreference,
      activeAdvancedTheme: activeAdvancedTheme,
      activeBottomNavIconGallery: activeBottomNavIconGallery,
      launchImageGalleries: launchImageGalleries,
    );
    final dataActions = _buildDataActions(
      context,
      visibilityState: visibilityState,
    );
    final otherActions = _buildOtherActions(
      context,
      visibilityState: visibilityState,
    );

    if (isDesktopMine) {
      return _buildDesktopMinePage(
        context,
        palette: advancedPalette,
        backdrop: advancedBackdrop,
        appearanceActions: appearanceActions,
        dataActions: dataActions,
        otherActions: otherActions,
      );
    }

    final toggleTooltip =
        _layoutMode == MinePageLayoutMode.grid ? '切换为列表' : '切换为网格';
    final toggleIcon =
        _layoutMode == MinePageLayoutMode.grid
            ? Icons.view_list_rounded
            : Icons.grid_view_rounded;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('我的'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: toggleTooltip,
            onPressed: _toggleLayoutMode,
            icon: Icon(toggleIcon),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, _) {
          final maxWidth = AppLayout.pageContentMaxWidth(
            context,
            maxWidth: AppLayout.mineContentMaxWidth,
          );

          return DecoratedBox(
            decoration: buildAdvancedThemeBackdropDecoration(advancedBackdrop),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: AppRefreshIndicator(
                  semanticsLabel: '刷新我的页面',
                  onRefresh: _refreshMine,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: mobileBottomNavigationBodyPadding(
                      context,
                      style: effectiveNavigationStyle,
                      showNavigationLabels: showNavigationLabels,
                      standardAppearance: standardNavigationAppearance,
                      left: horizontal,
                      top: topInset + metrics.contentGap * 0.5,
                      right: horizontal,
                      bottom: metrics.sectionGap,
                    ),
                    children: _buildPageChildren(
                      context,
                      palette: advancedPalette,
                      visibilityState: visibilityState,
                      appearanceActions: appearanceActions,
                      dataActions: dataActions,
                      otherActions: otherActions,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopMinePage(
    BuildContext context, {
    required _MineResolvedPalette palette,
    required ResolvedAdvancedThemeBackdrop backdrop,
    required List<_MineActionItem> appearanceActions,
    required List<_MineActionItem> dataActions,
    required List<_MineActionItem> otherActions,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    final contentMaxWidth = AppLayout.pageContentMaxWidth(
      context,
      maxWidth: AppLayout.mineContentMaxWidth,
    );
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: buildAdvancedThemeBackdropDecoration(backdrop),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                metrics.pagePadding,
                metrics.sectionGap,
                metrics.pagePadding,
                metrics.sectionGap + bottomPadding,
              ),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: _buildDesktopMineDashboard(
                      context,
                      palette: palette,
                      appearanceActions: appearanceActions,
                      dataActions: dataActions,
                      otherActions: otherActions,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopMineDashboard(
    BuildContext context, {
    required _MineResolvedPalette palette,
    required List<_MineActionItem> appearanceActions,
    required List<_MineActionItem> dataActions,
    required List<_MineActionItem> otherActions,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    final gap = metrics.contentGap;
    final toggleTooltip =
        _layoutMode == MinePageLayoutMode.grid ? '切换为列表' : '切换为网格';
    final toggleIcon =
        _layoutMode == MinePageLayoutMode.grid
            ? Icons.view_list_rounded
            : Icons.grid_view_rounded;
    final desktopSections = <Widget>[
      if (dataActions.isNotEmpty)
        _buildPageEntrance(
          index: 1,
          child: _buildActionSection(
            context,
            palette: palette,
            title: '数据',
            actions: dataActions,
            maxGridColumns: 3,
          ),
        ),
      if (otherActions.isNotEmpty)
        _buildPageEntrance(
          index: 2,
          child: _buildActionSection(
            context,
            palette: palette,
            title: '其他',
            actions: otherActions,
            maxGridColumns: 3,
          ),
        ),
      if (appearanceActions.isNotEmpty)
        _buildPageEntrance(
          index: 3,
          child: _buildActionSection(
            context,
            palette: palette,
            title: '外观',
            actions: appearanceActions,
            maxGridColumns: 3,
          ),
        ),
    ];

    final profile = _buildPageEntrance(
      index: 0,
      child: _buildProfileCard(context, palette: palette),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        profile,
        if (desktopSections.isNotEmpty) ...[
          SizedBox(height: metrics.sectionGap),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: toggleTooltip,
              onPressed: _toggleLayoutMode,
              icon: Icon(toggleIcon),
            ),
          ),
          SizedBox(height: gap * 0.5),
          _buildDesktopMineSectionGrid(sections: desktopSections, spacing: gap),
        ],
      ],
    );
  }

  Widget _buildDesktopMineSectionGrid({
    required List<Widget> sections,
    required double spacing,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desiredColumns =
            constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 620
                ? 2
                : 1;
        final columns =
            sections.length < desiredColumns ? sections.length : desiredColumns;
        final totalSpacing = spacing * (columns - 1);
        final tileWidth = (constraints.maxWidth - totalSpacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final section in sections)
              SizedBox(width: tileWidth, child: section),
          ],
        );
      },
    );
  }

  List<Widget> _buildPageChildren(
    BuildContext context, {
    required _MineResolvedPalette palette,
    required MinePageVisibilityState visibilityState,
    required List<_MineActionItem> appearanceActions,
    required List<_MineActionItem> dataActions,
    required List<_MineActionItem> otherActions,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    if (metrics.isMediumUpWindow) {
      return _buildExpandedPageChildren(
        context,
        palette: palette,
        visibilityState: visibilityState,
        appearanceActions: appearanceActions,
        dataActions: dataActions,
        otherActions: otherActions,
      );
    }

    final children = <Widget>[
      _buildPageEntrance(
        index: 0,
        child: _buildProfileCard(context, palette: palette),
      ),
      SizedBox(height: _primarySectionGapFor(context)),
      _buildQuickAccessCards(
        context,
        palette: palette,
        visibilityState: visibilityState,
      ),
    ];

    var sectionIndex = 1;
    void appendSection(
      String title,
      List<_MineActionItem> actions, {
      EdgeInsetsGeometry? padding,
      double? gap,
    }) {
      if (actions.isEmpty) {
        return;
      }
      children.add(SizedBox(height: gap ?? _secondarySectionGapFor(context)));
      children.add(
        _buildPageEntrance(
          index: sectionIndex,
          child: _buildActionSection(
            context,
            palette: palette,
            title: title,
            actions: actions,
            padding: padding,
          ),
        ),
      );
      sectionIndex += 1;
    }

    appendSection('外观', appearanceActions, gap: _primarySectionGapFor(context));
    appendSection('数据', dataActions);
    appendSection('其他', otherActions);
    return children;
  }

  List<Widget> _buildExpandedPageChildren(
    BuildContext context, {
    required _MineResolvedPalette palette,
    required MinePageVisibilityState visibilityState,
    required List<_MineActionItem> appearanceActions,
    required List<_MineActionItem> dataActions,
    required List<_MineActionItem> otherActions,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    final sectionCards = <Widget>[
      if (appearanceActions.isNotEmpty)
        _buildPageEntrance(
          index: 1,
          child: _buildActionSection(
            context,
            palette: palette,
            title: '外观',
            actions: appearanceActions,
          ),
        ),
      if (dataActions.isNotEmpty)
        _buildPageEntrance(
          index: 2,
          child: _buildActionSection(
            context,
            palette: palette,
            title: '数据',
            actions: dataActions,
          ),
        ),
      if (otherActions.isNotEmpty)
        _buildPageEntrance(
          index: 3,
          child: _buildActionSection(
            context,
            palette: palette,
            title: '其他',
            actions: otherActions,
          ),
        ),
    ];
    return [
      _buildPageEntrance(
        index: 0,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _buildProfileCard(context, palette: palette),
            ),
            SizedBox(width: metrics.contentGap),
            Expanded(
              flex: metrics.isExpandedWindow ? 7 : 6,
              child: _buildQuickAccessCards(
                context,
                palette: palette,
                visibilityState: visibilityState,
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: metrics.sectionGap),
      if (metrics.isExpandedWindow && sectionCards.length > 1)
        _buildMineDesktopColumns(sectionCards, spacing: metrics.contentGap)
      else
        Column(
          children: [
            for (var index = 0; index < sectionCards.length; index++) ...[
              sectionCards[index],
              if (index < sectionCards.length - 1)
                SizedBox(height: metrics.contentGap),
            ],
          ],
        ),
    ];
  }

  Widget _buildMineDesktopColumns(
    List<Widget> cards, {
    required double spacing,
  }) {
    final leftCards = <Widget>[];
    final rightCards = <Widget>[];
    for (var index = 0; index < cards.length; index += 1) {
      if (index.isEven) {
        leftCards.add(cards[index]);
      } else {
        rightCards.add(cards[index]);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              for (var index = 0; index < leftCards.length; index++) ...[
                leftCards[index],
                if (index < leftCards.length - 1) SizedBox(height: spacing),
              ],
            ],
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: Column(
            children: [
              for (var index = 0; index < rightCards.length; index++) ...[
                rightCards[index],
                if (index < rightCards.length - 1) SizedBox(height: spacing),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessCards(
    BuildContext context, {
    required _MineResolvedPalette palette,
    required MinePageVisibilityState visibilityState,
  }) {
    return const SizedBox.shrink();
  }

  List<_MineActionItem> _buildAppearanceActions(
    BuildContext context, {
    required MinePageVisibilityState visibilityState,
    required AppBaseColorSchemeId baseColorSchemeId,
    required AppThemeSource themeSource,
    required ThemeMode themeMode,
    required AppNavigationStylePreference navigationPreference,
    required AsyncValue<AppAdvancedTheme?> activeAdvancedTheme,
    required AsyncValue<dynamic> activeBottomNavIconGallery,
    required List<dynamic> launchImageGalleries,
  }) {
    final actions = <_MineActionItem>[];

    if (visibilityState.isVisible(MinePageItemId.appAppearance)) {
      actions.add(
        _MineActionItem(
          icon: Icons.palette_outlined,
          label: '应用外观',
          subtitle:
              '${_themeModeLabel(themeMode)} · ${_themeSourceSummaryLabel(themeSource, activeAdvancedTheme)} · ${baseColorSchemeId.label} · ${appNavigationStylePreferenceLabel(navigationPreference)}',
          colorDot: baseColorSchemeId.swatch,
          onTap: _pushMineRouteAction('/appearance?section=appearance'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.advancedTheme)) {
      actions.add(
        _MineActionItem(
          icon: Icons.auto_awesome_outlined,
          label: '主题预设与高级主题',
          subtitle: activeAdvancedTheme.when(
            data: (theme) {
              final source = _themeSourceDetailLabel(themeSource, theme);
              return _hasThemeCustom ? source : '$source · 自定义编辑需会员';
            },
            loading: () => _hasThemeCustom ? '读取中' : '校验中',
            error: (_, _) => _hasThemeCustom ? '未启用' : '校验中',
          ),
          tagText: _hasThemeCustom ? null : '官方免费',
          onTap: _handleAdvancedThemeTap,
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.bottomNavGallery)) {
      actions.add(
        _MineActionItem(
          icon: Icons.dashboard_outlined,
          label: '底栏图集',
          subtitle: activeBottomNavIconGallery.when(
            data:
                (gallery) =>
                    gallery?.name.trim().isNotEmpty == true
                        ? gallery!.name
                        : null,
            loading: () => null,
            error: (_, _) => null,
          ),
          onTap: _pushMineRouteAction('/bottom-nav-icon-galleries'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.coverGallery)) {
      actions.add(
        _MineActionItem(
          icon: Icons.photo_library_outlined,
          label: '封面图集',
          onTap: _pushMineRouteAction('/cover-galleries'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.appBackground)) {
      actions.add(
        _MineActionItem(
          icon: Icons.wallpaper_outlined,
          label: '应用背景',
          onTap: _pushMineRouteAction('/appearance?section=background'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.readerBackground)) {
      actions.add(
        _MineActionItem(
          icon: Icons.auto_stories_outlined,
          label: '阅读背景',
          onTap: _pushMineRouteAction('/appearance/reader-background'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.launchGallery)) {
      actions.add(
        _MineActionItem(
          icon: Icons.rocket_launch_outlined,
          label: '启动图集',
          subtitle: activeAdvancedTheme.when(
            data: (theme) {
              final galleryId = theme?.launchImageGalleryId?.trim() ?? '';
              if (galleryId.isEmpty) {
                return null;
              }
              for (final gallery in launchImageGalleries) {
                if (gallery.id == galleryId && gallery.name.trim().isNotEmpty) {
                  return gallery.name as String;
                }
              }
              return '当前主题已绑定';
            },
            loading: () => null,
            error: (_, _) => null,
          ),
          onTap: _pushMineRouteAction('/appearance/launch-image'),
        ),
      );
    }

    return actions;
  }

  List<_MineActionItem> _buildDataActions(
    BuildContext context, {
    required MinePageVisibilityState visibilityState,
  }) {
    final actions = <_MineActionItem>[];
    if (visibilityState.isVisible(MinePageItemId.inspiration)) {
      actions.add(
        _MineActionItem(
          icon: Icons.auto_awesome_outlined,
          label: '灵感笔记',
          onTap: _pushMineRouteAction('/bookmarks'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.bookSources)) {
      actions.add(
        _MineActionItem(
          icon: Icons.library_books_outlined,
          label: '我的书源',
          onTap: _pushMineRouteAction('/mine/book-sources'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.tagManagement)) {
      actions.add(
        _MineActionItem(
          icon: Icons.sell_outlined,
          label: '标签管理',
          onTap: _pushMineRouteAction('/mine/tags'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.categoryManagement)) {
      actions.add(
        _MineActionItem(
          icon: Icons.folder_copy_outlined,
          label: '分类管理',
          onTap: _pushMineRouteAction('/mine/categories'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.fontManagement)) {
      actions.add(
        _MineActionItem(
          icon: Icons.font_download_outlined,
          label: '字体管理',
          onTap: _pushMineRouteAction('/font-management'),
        ),
      );
    }
    return actions;
  }

  List<_MineActionItem> _buildOtherActions(
    BuildContext context, {
    required MinePageVisibilityState visibilityState,
  }) {
    final actions = <_MineActionItem>[];
    if (visibilityState.isVisible(MinePageItemId.about)) {
      actions.add(
        _MineActionItem(
          icon: Icons.info_outline,
          label: '关于我们',
          onTap: _pushMineRouteAction('/about'),
        ),
      );
    }
    return actions;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildProfileMembershipRow(
    BuildContext context,
    _MineResolvedPalette palette,
    Color membershipAccent,
  ) {
    if (_userId == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final accent = _hasMembership ? membershipAccent : palette.primaryColor;
    final title = _hasMembership ? '高级会员' : '开通会员';
    final detail = _buildMembershipInlineDetail();
    final actionLabel = _hasMembership ? '查看权益' : '开通会员';
    final icon =
        _hasMembership
            ? Icons.workspace_premium_rounded
            : Icons.workspace_premium_outlined;
    return LayoutBuilder(
      key: const ValueKey<String>('mine_profile_membership_panel'),
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 250;
        final showDetail = constraints.maxWidth >= 190;
        final showAction = constraints.maxWidth >= 150;
        final effectiveActionLabel =
            compact
                ? _hasMembership
                    ? '权益'
                    : '开通'
                : actionLabel;
        final action =
            showAction
                ? _buildProfileMembershipActionButton(
                  context,
                  label: effectiveActionLabel,
                  accent: accent,
                  palette: palette,
                  prominent: !_hasMembership,
                  onPressed: _openMembershipCenter,
                )
                : null;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (constraints.maxWidth >= 48) ...[
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textPrimaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (showDetail)
                      TextSpan(
                        text: '  ·  $detail',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textSecondaryColor,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showAction) ...[
              const SizedBox(width: 8),
              Flexible(flex: 0, child: action!),
            ],
          ],
        );
      },
    );
  }

  String _buildMembershipInlineDetail() {
    if (_userId == null) {
      return '';
    }
    if (!_hasMembership) {
      return '享专属特权';
    }
    final isLifetime = _membershipPlanType?.toLowerCase() == 'lifetime';
    if (isLifetime) {
      return '终身会员 · 永久有效';
    }
    final expireAt = _vipExpireAt;
    if (expireAt != null) {
      return '有效期至 ${_formatDate(expireAt)}';
    }
    return '会员有效';
  }

  Widget _buildProfileMembershipActionButton(
    BuildContext context, {
    required String label,
    required Color accent,
    required _MineResolvedPalette palette,
    required bool prominent,
    required VoidCallback onPressed,
  }) {
    final icon =
        _hasMembership
            ? Icons.chevron_right_rounded
            : Icons.workspace_premium_rounded;
    final foreground =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
            ? Colors.white
            : Colors.black;
    final baseStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 34)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      textStyle: WidgetStatePropertyAll<TextStyle?>(
        Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    if (prominent) {
      return FilledButton.icon(
        key: const ValueKey<String>('mine_profile_membership_action_button'),
        onPressed: _isLoggingOut ? null : onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: baseStyle.copyWith(
          backgroundColor: WidgetStatePropertyAll<Color>(accent),
          foregroundColor: WidgetStatePropertyAll<Color>(foreground),
        ),
      );
    }

    return OutlinedButton.icon(
      key: const ValueKey<String>('mine_profile_membership_action_button'),
      onPressed: _isLoggingOut ? null : onPressed,
      icon: Icon(_userId == null ? Icons.login_rounded : icon, size: 16),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: baseStyle.copyWith(
        foregroundColor: WidgetStatePropertyAll<Color>(accent),
        backgroundColor: WidgetStatePropertyAll<Color>(palette.cardColor),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: accent.withValues(alpha: 0.20)),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context, {
    required _MineResolvedPalette palette,
  }) {
    final theme = Theme.of(context);
    final metrics = AppAdaptiveMetrics.of(context);
    final isDesktopProfile = AppLayout.isDesktopLike(
      context,
      isWeb: kIsWeb,
      platform: theme.platform,
    );
    final displayName =
        _userId == null
            ? '登录 / 注册'
            : ((_username?.trim().isNotEmpty ?? false) ? _username! : _userId!);
    final avatarLabel = _buildProfileAvatarLabel(displayName);
    final avatarFill = palette.iconBackgroundColor;
    const membershipAccent = Color(0xFFB68A4D);
    final membershipBorderColor =
        _hasMembership
            ? membershipAccent.withValues(alpha: 0.28)
            : resolveAppBorderColor(
              theme.colorScheme,
              baseColor: palette.cardBorderColor,
              containerColor: palette.cardColor,
              tone: AppBorderTone.subtle,
            );

    if (isDesktopProfile) {
      return _buildDesktopProfileCard(
        context,
        palette: palette,
        displayName: displayName,
        avatarLabel: avatarLabel,
        avatarFill: avatarFill,
        membershipAccent: membershipAccent,
      );
    }

    return Card(
      key: const ValueKey<String>('mine_mobile_profile_card'),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: membershipBorderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _isLoggingOut ? null : _handleProfileCardTap,
        child: Ink(
          decoration:
              _hasMembership
                  ? BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.alphaBlend(
                          membershipAccent.withValues(alpha: 0.12),
                          palette.cardColor,
                        ),
                        Color.alphaBlend(
                          membershipAccent.withValues(alpha: 0.04),
                          palette.cardColor,
                        ),
                      ],
                    ),
                  )
                  : null,
          child: Padding(
            padding: _profileCardPaddingFor(context),
            child: Row(
              crossAxisAlignment:
                  metrics.isMediumUpWindow
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _handleAvatarTap(context),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                _hasMembership
                                    ? Border.all(
                                      color: membershipAccent,
                                      width: 1.8,
                                    )
                                    : null,
                            boxShadow:
                                _hasMembership
                                    ? [
                                      BoxShadow(
                                        color: membershipAccent.withValues(
                                          alpha: 0.18,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: avatarFill,
                              shape: BoxShape.circle,
                            ),
                            clipBehavior: Clip.antiAlias,
                            alignment: Alignment.center,
                            child: _buildProfileAvatarContent(
                              context,
                              avatarLabel: avatarLabel,
                              palette: palette,
                            ),
                          ),
                        ),
                        if (_hasMembership)
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: membershipAccent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: palette.cardColor,
                                  width: 1.4,
                                ),
                              ),
                              child: const Icon(
                                Icons.workspace_premium_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        if (_userId != null)
                          Positioned(
                            top: -1,
                            right: -1,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: palette.cardColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: membershipBorderColor,
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt_outlined,
                                size: 11,
                                color: palette.textSecondaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final showMembershipBadge =
                              _hasMembership && constraints.maxWidth >= 86;
                          final showGuestBadge =
                              _userId == null &&
                              !isDesktopProfile &&
                              constraints.maxWidth >= 112;

                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (showMembershipBadge)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: membershipAccent.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'PRO',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: membershipAccent,
                                    ),
                                  ),
                                ),
                              if (showGuestBadge)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.noticeSurfaceColor,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: palette.noticeAccentColor
                                          .withValues(alpha: 0.55),
                                    ),
                                  ),
                                  child: Text(
                                    '未登录',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: palette.noticeAccentColor,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      if (_userId != null) ...[
                        const SizedBox(height: 8),
                        _buildProfileMembershipRow(
                          context,
                          palette,
                          membershipAccent,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!metrics.isMediumUpWindow) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: palette.textSecondaryColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopProfileCard(
    BuildContext context, {
    required _MineResolvedPalette palette,
    required String displayName,
    required String? avatarLabel,
    required Color avatarFill,
    required Color membershipAccent,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderColor = resolveAppBorderColor(
      colorScheme,
      baseColor: palette.cardBorderColor,
      containerColor: palette.cardColor,
      tone: AppBorderTone.subtle,
    );
    final cardShadowColor =
        colorScheme.brightness == Brightness.light
            ? const Color(0xFFCBD5E1).withValues(alpha: 0.26)
            : Colors.black.withValues(alpha: 0.22);
    final topTint = Color.alphaBlend(
      palette.primaryColor.withValues(alpha: 0.05),
      palette.cardColor,
    );
    final bottomTint = Color.alphaBlend(
      const Color(0xFF94A3B8).withValues(alpha: 0.035),
      palette.cardColor,
    );
    final statusText = MembershipAccessPresentation.accountBadge(
      isLoggedIn: _userId != null,
      hasMembership: _hasMembership,
    );
    final statusColor =
        _userId == null
            ? palette.noticeAccentColor
            : (_hasMembership ? membershipAccent : palette.primaryColor);
    final actionLabel =
        _userId == null ? '登录 / 注册' : (_isLoggingOut ? '退出中...' : '退出登录');

    return Material(
      key: const ValueKey<String>('mine_desktop_profile_card'),
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey<String>('mine_desktop_profile_card_tap_area'),
        borderRadius: BorderRadius.circular(24),
        onTap: _isLoggingOut ? null : _handleProfileCardTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
                  _hasMembership
                      ? membershipAccent.withValues(alpha: 0.32)
                      : borderColor,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  _hasMembership
                      ? [
                        Color.alphaBlend(
                          membershipAccent.withValues(alpha: 0.10),
                          palette.cardColor,
                        ),
                        palette.cardColor,
                        Color.alphaBlend(
                          palette.primaryColor.withValues(alpha: 0.035),
                          palette.cardColor,
                        ),
                      ]
                      : [topTint, palette.cardColor, bottomTint],
            ),
            boxShadow: [
              BoxShadow(
                color: cardShadowColor,
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '我的账户',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: palette.textSecondaryColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _buildDesktopProfileStatusPill(
                      context,
                      label: statusText,
                      color: statusColor,
                      palette: palette,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compactIdentity = constraints.maxWidth < 560;
                    final identityRow = Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildDesktopProfileAvatar(
                          context,
                          avatarLabel: avatarLabel,
                          avatarFill: avatarFill,
                          membershipAccent: membershipAccent,
                          palette: palette,
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _buildDesktopProfileIdentityText(
                            context,
                            displayName: displayName,
                            palette: palette,
                          ),
                        ),
                      ],
                    );

                    if (compactIdentity) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          identityRow,
                          const SizedBox(height: 16),
                          _buildDesktopProfileActionButton(
                            context,
                            label: actionLabel,
                            palette: palette,
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: identityRow),
                        const SizedBox(width: 14),
                        _buildDesktopProfileActionButton(
                          context,
                          label: actionLabel,
                          palette: palette,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                _buildDesktopProfileMetrics(context, palette: palette),
                if (_userId != null) ...[
                  const SizedBox(height: 18),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _buildProfileMembershipRow(
                        context,
                        palette,
                        membershipAccent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopProfileIdentityText(
    BuildContext context, {
    required String displayName,
    required _MineResolvedPalette palette,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: palette.textPrimaryColor,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopProfileAvatar(
    BuildContext context, {
    required String? avatarLabel,
    required Color avatarFill,
    required Color membershipAccent,
    required _MineResolvedPalette palette,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _userId == null ? null : () => _handleAvatarTap(context),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      _hasMembership
                          ? membershipAccent
                          : palette.cardBorderColor.withValues(alpha: 0.8),
                  width: _hasMembership ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_hasMembership
                            ? membershipAccent
                            : palette.primaryColor)
                        .withValues(alpha: 0.14),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: avatarFill,
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: _buildProfileAvatarContent(
                  context,
                  avatarLabel: avatarLabel,
                  palette: palette,
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _hasMembership ? membershipAccent : palette.cardColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.cardColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _hasMembership
                      ? Icons.workspace_premium_rounded
                      : Icons.camera_alt_outlined,
                  size: 13,
                  color:
                      _hasMembership
                          ? Colors.white
                          : palette.textSecondaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopProfileStatusPill(
    BuildContext context, {
    required String label,
    required Color color,
    required _MineResolvedPalette palette,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.08),
          palette.cardColor,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildDesktopProfileActionButton(
    BuildContext context, {
    required String label,
    required _MineResolvedPalette palette,
  }) {
    return OutlinedButton.icon(
      key: const ValueKey<String>('mine_desktop_profile_action_button'),
      onPressed: _isLoggingOut ? null : _handleProfileActionButtonTap,
      icon:
          _isLoggingOut
              ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : Icon(_userId == null ? Icons.login_rounded : Icons.logout),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.primaryColor,
        side: BorderSide(color: palette.primaryColor.withValues(alpha: 0.28)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildDesktopProfileMetrics(
    BuildContext context, {
    required _MineResolvedPalette palette,
  }) {
    final items =
        _userId == null
            ? const <({String label, String value})>[
              (label: '账号状态', value: '未登录'),
              (label: '书架同步', value: '登录后'),
              (label: '会员权益', value: '登录后'),
            ]
            : <({String label, String value})>[
              (label: '账号状态', value: '已登录'),
              (
                label: '会员状态',
                value: MembershipAccessPresentation.accountBadge(
                  isLoggedIn: true,
                  hasMembership: _hasMembership,
                ),
              ),
              (
                label: '主题权益',
                value: MembershipAccessPresentation.themeEntitlementValue(
                  _hasThemeCustom,
                ),
              ),
            ];

    return Row(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  items[index].value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  items[index].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: palette.textSecondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (index < items.length - 1)
            Container(
              width: 1,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              color: palette.cardBorderColor.withValues(alpha: 0.55),
            ),
        ],
      ],
    );
  }

  String? _buildProfileAvatarLabel(String displayName) {
    final normalized = displayName.trim();
    if (normalized.isEmpty || normalized == '登录 / 注册') {
      return null;
    }
    return String.fromCharCode(normalized.runes.first).toUpperCase();
  }

  Widget _buildProfileAvatarContent(
    BuildContext context, {
    required String? avatarLabel,
    required _MineResolvedPalette palette,
  }) {
    if (_localAvatarPath != null) {
      return buildLocalFileImage(
        imagePath: _localAvatarPath,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        fallback: _buildProfileAvatarFallback(
          context,
          avatarLabel: avatarLabel,
          palette: palette,
        ),
      );
    }
    return _buildProfileAvatarFallback(
      context,
      avatarLabel: avatarLabel,
      palette: palette,
    );
  }

  Widget _buildProfileAvatarFallback(
    BuildContext context, {
    required String? avatarLabel,
    required _MineResolvedPalette palette,
  }) {
    if (avatarLabel == null) {
      return Icon(
        Icons.person_outline_rounded,
        color: palette.textPrimaryColor,
        size: 24,
      );
    }
    return Text(
      avatarLabel,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: palette.textPrimaryColor,
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => '日间',
      ThemeMode.dark => '夜间',
      ThemeMode.system => '跟随系统',
    };
  }

  String _themeSourceSummaryLabel(
    AppThemeSource source,
    AsyncValue<AppAdvancedTheme?> activeAdvancedTheme,
  ) {
    return switch (source.kind) {
      AppThemeSourceKind.baseColorScheme => '基础配色生效',
      AppThemeSourceKind.official =>
        '${appOfficialThemePresetById(source.officialPresetId!).id.label} 官方',
      AppThemeSourceKind.customAdvancedTheme => activeAdvancedTheme.when(
        data: (theme) => theme == null ? '自定义主题' : theme.name,
        loading: () => '自定义主题',
        error: (_, _) => '自定义主题',
      ),
    };
  }

  String _themeSourceDetailLabel(
    AppThemeSource source,
    AppAdvancedTheme? activeTheme,
  ) {
    return switch (source.kind) {
      AppThemeSourceKind.baseColorScheme => '未启用主题预设，基础配色生效',
      AppThemeSourceKind.official =>
        '当前：${appOfficialThemePresetById(source.officialPresetId!).id.label}（官方）',
      AppThemeSourceKind.customAdvancedTheme =>
        activeTheme == null ? '当前：自定义主题' : '当前：${activeTheme.name}',
    };
  }

  _MineResolvedPalette _resolveAdvancedPalette(
    BuildContext context,
    AppAdvancedTheme? activeTheme,
  ) {
    final resolved = resolveAdvancedThemePalette(
      Theme.of(context).colorScheme,
      activeTheme,
    );
    return _MineResolvedPalette(
      cardColor: resolved.cardColor,
      cardTextColor: resolved.cardTextColor,
      cardBorderColor: resolved.cardBorderColor,
      iconBackgroundColor: resolved.iconBackgroundColor,
      textPrimaryColor: resolved.textPrimaryColor,
      textSecondaryColor: resolved.textSecondaryColor,
      primaryColor: resolved.primaryColor,
      noticeAccentColor: resolved.noticeAccentColor,
      noticeSurfaceColor: resolved.noticeSurfaceColor,
    );
  }

  ResolvedAdvancedThemeBackdrop _resolveAdvancedBackdrop(
    BuildContext context,
    AppAdvancedTheme? activeTheme,
  ) {
    return resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      activeTheme,
    );
  }
}
