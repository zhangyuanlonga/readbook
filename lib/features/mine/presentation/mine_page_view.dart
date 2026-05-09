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
    final configurationActions = _buildConfigurationActions(
      context,
      visibilityState: visibilityState,
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
                      configurationActions: configurationActions,
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
    required List<_MineActionItem> configurationActions,
    required List<_MineActionItem> dataActions,
    required List<_MineActionItem> otherActions,
  }) {
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
    appendSection(
      '配置',
      configurationActions,
      padding: _isListMode ? const EdgeInsets.fromLTRB(10, 2, 10, 2) : null,
    );
    appendSection('数据', dataActions);
    appendSection('其他', otherActions);
    return children;
  }

  Widget _buildQuickAccessCards(
    BuildContext context, {
    required _MineResolvedPalette palette,
    required MinePageVisibilityState visibilityState,
  }) {
    final quickCards = <Widget>[
      if (visibilityState.isVisible(MinePageItemId.sync))
        _buildQuickCard(
          context,
          palette: palette,
          icon: Icons.sync_rounded,
          label: '同步',
          tagText: 'VIP',
          onTap: _handleSyncTap,
        ),
      if (visibilityState.isVisible(MinePageItemId.inspiration))
        _buildQuickCard(
          context,
          palette: palette,
          icon: Icons.auto_awesome_outlined,
          label: '灵感',
          onTap: () => context.push('/bookmarks'),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMembershipQuickCard(context, palette: palette),
        if (quickCards.isNotEmpty) ...[
          SizedBox(height: _quickAccessInnerGapFor(context)),
          if (quickCards.length == 1)
            quickCards.single
          else
            Row(
              children: [
                Expanded(child: quickCards[0]),
                SizedBox(width: _quickAccessInnerGapFor(context)),
                Expanded(child: quickCards[1]),
              ],
            ),
        ],
      ],
    );
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
          onTap: () => context.push('/appearance?section=appearance'),
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
            loading: () => _hasThemeCustom ? '读取中' : 'VIP 专属',
            error: (_, _) => _hasThemeCustom ? '未启用' : 'VIP 专属',
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
          onTap: () => context.push('/bottom-nav-icon-galleries'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.coverGallery)) {
      actions.add(
        _MineActionItem(
          icon: Icons.photo_library_outlined,
          label: '封面图集',
          onTap: () => context.push('/cover-galleries'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.appBackground)) {
      actions.add(
        _MineActionItem(
          icon: Icons.wallpaper_outlined,
          label: '应用背景',
          onTap: () => context.push('/appearance?section=background'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.readerBackground)) {
      actions.add(
        _MineActionItem(
          icon: Icons.auto_stories_outlined,
          label: '阅读背景',
          onTap: () => context.push('/appearance/reader-background'),
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
          onTap: () => context.push('/appearance/launch-image'),
        ),
      );
    }

    return actions;
  }

  List<_MineActionItem> _buildConfigurationActions(
    BuildContext context, {
    required MinePageVisibilityState visibilityState,
  }) {
    final actions = <_MineActionItem>[];
    if (visibilityState.isVisible(MinePageItemId.tagManagement)) {
      actions.add(
        _MineActionItem(
          icon: Icons.sell_outlined,
          label: '标签管理',
          onTap: () => context.push('/mine/tags'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.categoryManagement)) {
      actions.add(
        _MineActionItem(
          icon: Icons.folder_copy_outlined,
          label: '分类管理',
          onTap: () => context.push('/mine/categories'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.chapterRule)) {
      actions.add(
        _MineActionItem(
          icon: Icons.rule_rounded,
          label: '分章规则',
          onTap: () => context.push('/mine/chapter-rules'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.contentCleanup)) {
      actions.add(
        _MineActionItem(
          icon: Icons.cleaning_services_outlined,
          label: '正文净化',
          onTap: () => context.push('/mine/content-cleanup'),
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
    if (visibilityState.isVisible(MinePageItemId.fontManagement)) {
      actions.add(
        _MineActionItem(
          icon: Icons.font_download_outlined,
          label: '字体管理',
          onTap: () => context.push('/font-management'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.systemSettings)) {
      actions.add(
        _MineActionItem(
          icon: Icons.tune_rounded,
          label: '系统',
          onTap: () => context.push('/system-settings'),
        ),
      );
    }
    if (_showSourceEntry &&
        visibilityState.isVisible(MinePageItemId.sourceManagement)) {
      actions.add(
        _MineActionItem(
          icon: Icons.menu_book_rounded,
          label: '书源管理',
          subtitle: _buildSourceSubtitle(),
          onTap: _handleSourceTap,
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.sourceDebugService)) {
      actions.add(
        _MineActionItem(
          icon: Icons.lan_outlined,
          label: '网页调试服务',
          subtitle: '为网站调试台提供局域网本地接口',
          onTap: () => context.push('/mine/source-debug-service'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.cacheManagement)) {
      actions.add(
        _MineActionItem(
          icon: Icons.cloud_outlined,
          label: '存储管理',
          subtitle: '分类清理章节缓存、分页缓存、封面缓存等',
          onTap: () => context.push('/cache'),
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
    if (visibilityState.isVisible(MinePageItemId.feedback)) {
      actions.add(
        _MineActionItem(
          icon: Icons.rate_review_outlined,
          label: '问题反馈',
          onTap: () => context.push('/feedback'),
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.officialGroup)) {
      actions.add(
        _MineActionItem(
          icon: Icons.feedback_outlined,
          label: '官方 Q 群',
          onTap: _openSourceFeedback,
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.checkUpdate)) {
      actions.add(
        _MineActionItem(
          icon: Icons.system_update_alt,
          label: '检查更新',
          onTap: _checkUpdateFromMine,
        ),
      );
    }
    if (visibilityState.isVisible(MinePageItemId.about)) {
      actions.add(
        _MineActionItem(
          icon: Icons.info_outline,
          label: '关于我们',
          onTap: () => context.push('/about'),
        ),
      );
    }
    return actions;
  }

  Widget _buildMembershipQuickCard(
    BuildContext context, {
    required _MineResolvedPalette palette,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openMembershipCenter,
        child: Container(
          padding: _quickCardPaddingFor(context),
          decoration: BoxDecoration(
            color: palette.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: resolveAppBorderColor(
                Theme.of(context).colorScheme,
                baseColor: palette.cardBorderColor,
                containerColor: palette.cardColor,
                tone: AppBorderTone.subtle,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                size: 22,
                color: palette.primaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '高级会员',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.cardTextColor,
                  ),
                ),
              ),
              Text(
                '查看',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.primaryColor,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: palette.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickCard(
    BuildContext context, {
    required _MineResolvedPalette palette,
    required IconData icon,
    required String label,
    String? tagText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: _quickCardPaddingFor(context),
          decoration: BoxDecoration(
            color: palette.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: resolveAppBorderColor(
                Theme.of(context).colorScheme,
                baseColor: palette.cardBorderColor,
                containerColor: palette.cardColor,
                tone: AppBorderTone.subtle,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: palette.primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: palette.cardTextColor,
                        ),
                      ),
                    ),
                    if (tagText != null && tagText.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: palette.noticeAccentColor.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tagText,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: palette.noticeAccentColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context, {
    required _MineResolvedPalette palette,
  }) {
    final theme = Theme.of(context);
    final displayName =
        _userId == null
            ? '登录 / 注册'
            : ((_username?.trim().isNotEmpty ?? false) ? _username! : _userId!);
    final signature = _buildProfileSignature();
    final statusLabel = _buildProfileStatusLabel();
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
              crossAxisAlignment: CrossAxisAlignment.center,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  displayName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (_hasMembership)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: membershipAccent.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: membershipAccent.withValues(
                                          alpha: 0.32,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 12,
                                          color: membershipAccent,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'PRO',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: membershipAccent,
                                                letterSpacing: 0.2,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _userId == null
                              ? Container(
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
                                  statusLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: palette.noticeAccentColor,
                                  ),
                                ),
                              )
                              : const SizedBox(width: 64, height: 28),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        signature,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textSecondaryColor,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.chevron_right_rounded,
                  color: palette.textSecondaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildProfileSignature() {
    if (_userId == null) {
      return '登录后可同步阅读进度、书架和个性设置。';
    }
    if (_hasMembership) {
      return '高级权益已生效，可继续同步阅读进度并管理个性化设置。';
    }
    return '阅读进度、书架与个性设置会随账号持续同步。';
  }

  String _buildProfileStatusLabel() {
    if (_userId == null) {
      return '未登录';
    }
    return '已登录';
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
      return Image.file(
        File(_localAvatarPath!),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) => _buildProfileAvatarFallback(
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
