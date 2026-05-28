part of 'mine_page.dart';

extension on _MinePageState {
  Widget _buildMinePage(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final horizontal = metrics.pagePadding;
    final seedColor = ref.watch(appSeedColorProvider);
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
    final platform = Theme.of(context).platform;
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
    final toggleTooltip =
        _layoutMode == _MineLayoutMode.grid ? '切换为列表' : '切换为网格';
    final toggleIcon =
        _layoutMode == _MineLayoutMode.grid
            ? Icons.view_list_rounded
            : Icons.grid_view_rounded;
    final appearanceActions = _buildAppearanceActions(
      context,
      visibilityState: visibilityState,
      seedColor: seedColor,
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
                child: RefreshIndicator(
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
    required Color seedColor,
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
              '${_themeModeLabel(themeMode)} · ${appThemeSeedLabel(seedColor)} · ${appNavigationStylePreferenceLabel(navigationPreference)}',
          colorDot: seedColor,
          onTap: _pushMineRouteAction('/appearance?section=appearance'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.advancedTheme)) {
      actions.add(
        _MineActionItem(
          icon: Icons.auto_awesome_outlined,
          label: '高级主题',
          subtitle: activeAdvancedTheme.when(
            data: (theme) {
              final base = theme == null ? '未启用' : '当前：${theme.name}';
              return _hasThemeCustom ? base : '$base · 开通会员可用';
            },
            loading: () => _hasThemeCustom ? '读取中' : '校验中',
            error: (_, _) => _hasThemeCustom ? '未启用' : '校验中',
          ),
          tagText: 'VIP',
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
    if (visibilityState.isVisible(MinePageItemId.membershipCenter)) {
      actions.add(
        _MineActionItem(
          icon: Icons.workspace_premium_outlined,
          label: '高级会员',
          onTap: _openMembershipCenter,
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.inspiration)) {
      actions.add(
        _MineActionItem(
          icon: Icons.auto_awesome_outlined,
          label: '灵感笔记',
          onTap: _pushMineRouteAction('/bookmarks'),
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

  String _buildProfileStats() {
    if (_userId == null) {
      return '登录后可同步书架、阅读记录和会员权益';
    }
    final readingHours = _totalReadingHours;
    final streakDays = _readingStreakDays;
    if (readingHours <= 0 && streakDays <= 0) {
      return '还没有阅读记录，今天开始第一段阅读吧';
    }
    return '已读 $readingHours 小时  ·  连续 $streakDays 天';
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

    if (_hasMembership) {
      return _buildMembershipProgressRow(context, palette, membershipAccent);
    }

    return _buildUpgradeRow(context, palette);
  }

  Widget _buildMembershipProgressRow(
    BuildContext context,
    _MineResolvedPalette palette,
    Color membershipAccent,
  ) {
    final expireAt = _vipExpireAt;
    final isLifetime = _membershipPlanType?.toLowerCase() == 'lifetime';
    if (expireAt == null) {
      if (!isLifetime) {
        return const SizedBox.shrink();
      }
      return Row(
        children: [
          Icon(Icons.all_inclusive_rounded, size: 15, color: membershipAccent),
          const SizedBox(width: 6),
          Text(
            '终身会员 · 永久有效',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: membershipAccent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    final now = DateTime.now();
    final totalDays = _membershipCycleDays(_membershipPlanType, expireAt, now);
    final remainingDays = expireAt.difference(now).inDays.clamp(0, totalDays);
    final progress =
        totalDays > 0
            ? ((totalDays - remainingDays).clamp(0, totalDays) / totalDays)
            : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: palette.cardBorderColor.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(membershipAccent),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '会员有效期至 ${_formatDate(expireAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.textSecondaryColor,
                fontSize: 11,
              ),
            ),
            Text(
              '剩余 $remainingDays 天',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: membershipAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  int _membershipCycleDays(String? planType, DateTime expireAt, DateTime now) {
    final normalized = planType?.trim().toLowerCase() ?? '';
    if (normalized.contains('year') || normalized.contains('annual')) {
      return 365;
    }
    if (normalized.contains('quarter')) {
      return 92;
    }
    if (normalized.contains('month')) {
      return 31;
    }
    if (normalized.contains('week')) {
      return 7;
    }
    final remainingDays = expireAt.difference(now).inDays;
    return remainingDays.clamp(1, 365).toInt();
  }

  Widget _buildUpgradeRow(BuildContext context, _MineResolvedPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 14,
            color: palette.primaryColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '开通会员，享受专属特权',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.primaryColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context, {
    required _MineResolvedPalette palette,
  }) {
    final theme = Theme.of(context);
    final metrics = AppAdaptiveMetrics.of(context);
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

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: membershipBorderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          final target = _userId == null ? '/auth' : '/profile';
          context.push(target).then((_) => _loadSession());
        },
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
                      Row(
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
                          if (_hasMembership)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: membershipAccent.withValues(alpha: 0.12),
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
                          if (_userId == null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: palette.noticeSurfaceColor,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: palette.noticeAccentColor.withValues(
                                    alpha: 0.55,
                                  ),
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
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _buildProfileStats(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildProfileMembershipRow(
                        context,
                        palette,
                        membershipAccent,
                      ),
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
