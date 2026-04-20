import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/navigation/bottom_nav_icon_gallery_provider.dart';
import '../../../app/navigation/mobile_bottom_navigation_inset.dart';
import '../../../app/navigation/app_navigation_style_provider.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/theme/app_border_tokens.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../app/theme/app_theme_provider.dart';
import '../../../app/theme/app_theme_seed_provider.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../core/app_update/app_update_dialog.dart';
import '../../../core/app_update/app_update_service.dart';
import '../../../core/auth/auth_event_bus.dart';
import '../../../core/auth/auth_session_store.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../core/membership/membership_features.dart';
import '../../../core/membership/membership_service.dart';
import '../../../core/mobile_features/mobile_feature_module.dart';
import '../../../core/mobile_features/mobile_feature_service.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../application/advanced_theme_provider.dart';

class MinePage extends ConsumerStatefulWidget {
  const MinePage({super.key});

  @override
  ConsumerState<MinePage> createState() => _MinePageState();
}

enum _MineLayoutMode { grid, list }

enum _ProfileAvatarAction { change, remove }

class _MinePageState extends ConsumerState<MinePage> {
  static const String _layoutModeKey = 'mine.page.layoutMode';
  String? _highlightedTileId;

  static final Uri _sourceFeedbackUri = Uri.parse(
    'https://qun.qq.com/universal-share/share?ac=1&authKey=Tabvg05EAafVbER7E8%2BzAQ18yErg2a%2B5PoqQH41t6dbPjcZIfDSnNX%2F4KCAXhzVh&busi_data=eyJncm91cENvZGUiOiIxMDgyODI3MjI0IiwidG9rZW4iOiIzam5tVFQ0cUs1T3VlMytzVk9iOXB1Zk40Q1RaUXJiQytzd2JlZUx3NDhXQTJscy9ZZGE5WW1hQXhPdGFwMHU1IiwidWluIjoiNzgyMDQ1MDExIn0%3D&data=PHNA5IOU4A3ujR5i9rmpWqWn4Qc-L9MNr8ByREa7IfvpXTo1utwnHVIfjkB7Rlk4x3yE9dfMR5_ZjOfsQ9wYcA&svctype=4&tempid=h5_group_info',
  );

  final AuthSessionStore _authSessionStore = AuthSessionStore();
  final AppUpdateService _updateService = AppUpdateService();
  final MobileFeatureService _mobileFeatureService = MobileFeatureService();
  final MembershipService _membershipService = MembershipService();
  final ImageSelectionService _imageSelectionService = ImageSelectionService();
  StreamSubscription<AuthEvent>? _authEventSub;
  String? _userId;
  String? _username;
  String? _localAvatarPath;
  bool _isLoadingSession = true;
  bool _isCheckingUpdate = false;
  bool _showSourceEntry = false;
  bool _hasMembership = false;
  bool _hasThemeCustom = false;
  int _sourceImportLimit = 10;
  _MineLayoutMode _layoutMode = _MineLayoutMode.list;

  bool get _isListMode => _layoutMode == _MineLayoutMode.list;

  EdgeInsets get _actionSectionPadding =>
      _isListMode
          ? const EdgeInsets.fromLTRB(12, 4, 12, 4)
          : const EdgeInsets.fromLTRB(14, 8, 14, 8);

  double get _primarySectionGap => _isListMode ? 6 : 8;

  double get _secondarySectionGap => _isListMode ? 2 : 4;

  double get _quickAccessInnerGap => _isListMode ? 6 : 8;

  EdgeInsets get _profileCardPadding =>
      _isListMode
          ? const EdgeInsets.fromLTRB(12, 9, 12, 9)
          : const EdgeInsets.fromLTRB(16, 14, 16, 14);

  EdgeInsets get _quickCardPadding =>
      _isListMode
          ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
          : const EdgeInsets.fromLTRB(14, 12, 14, 12);

  EdgeInsets get _actionListTilePadding =>
      _isListMode
          ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
          : const EdgeInsets.fromLTRB(14, 12, 14, 12);

  @override
  void initState() {
    super.initState();
    _authEventSub = AuthEventBus.instance.stream.listen(_handleAuthEvent);
    _restoreLayoutMode();
    _loadSession();
  }

  @override
  void dispose() {
    _authEventSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final seedColor = ref.watch(appSeedColorProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final activeBottomNavIconGallery = ref.watch(
      effectiveBottomNavIconGalleryProvider,
    );
    final activeAdvancedTheme = ref.watch(activeAdvancedThemeProvider);
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
    final bottomInset = mobileBottomNavigationContentInset(
      context,
      style: effectiveNavigationStyle,
      showNavigationLabels: showNavigationLabels,
    );
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final toggleTooltip =
        _layoutMode == _MineLayoutMode.grid ? '切换为列表' : '切换为网格';
    final toggleIcon =
        _layoutMode == _MineLayoutMode.grid
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
                child: RefreshIndicator(
                  onRefresh: _refreshMine,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      topInset + 4,
                      horizontal,
                      24 + bottomInset,
                    ),
                    children: [
                      _buildPageEntrance(
                        index: 0,
                        child: _buildProfileCard(
                          context,
                          palette: advancedPalette,
                        ),
                      ),
                      SizedBox(height: _primarySectionGap),
                      _buildQuickAccessCards(context, palette: advancedPalette),
                      SizedBox(height: _primarySectionGap),
                      _buildPageEntrance(
                        index: 1,
                        child: _buildActionSection(
                          context,
                          palette: advancedPalette,
                          title: '外观',
                          actions: [
                            _MineActionItem(
                              icon: Icons.palette_outlined,
                              label: '外观',
                              subtitle:
                                  '${_themeModeLabel(themeMode)} · ${appThemeSeedLabel(seedColor)} · ${appNavigationStylePreferenceLabel(navigationPreference)}',
                              colorDot: seedColor,
                              onTap:
                                  () => context.push(
                                    '/appearance?section=appearance',
                                  ),
                            ),
                            _MineActionItem(
                              icon: Icons.auto_awesome_outlined,
                              label: '高级主题',
                              subtitle: activeAdvancedTheme.when(
                                data: (theme) {
                                  final base =
                                      theme == null
                                          ? '未启用'
                                          : '当前：${theme.name}';
                                  return _hasThemeCustom
                                      ? base
                                      : '$base · 开通会员可用';
                                },
                                loading:
                                    () => _hasThemeCustom ? '读取中' : 'VIP 专属',
                                error:
                                    (_, _) =>
                                        _hasThemeCustom ? '未启用' : 'VIP 专属',
                              ),
                              tagText: 'VIP',
                              onTap: _handleAdvancedThemeTap,
                            ),
                            _MineActionItem(
                              icon: Icons.dashboard_outlined,
                              label: '底栏',
                              subtitle: activeBottomNavIconGallery.when(
                                data:
                                    (gallery) =>
                                        gallery?.name.trim().isNotEmpty == true
                                            ? gallery!.name
                                            : null,
                                loading: () => null,
                                error: (_, _) => null,
                              ),
                              onTap:
                                  () => context.push(
                                    '/bottom-nav-icon-galleries',
                                  ),
                            ),
                            _MineActionItem(
                              icon: Icons.photo_library_outlined,
                              label: '封面',
                              onTap: () => context.push('/cover-galleries'),
                            ),
                            _MineActionItem(
                              icon: Icons.wallpaper_outlined,
                              label: '背景',
                              onTap:
                                  () => context.push(
                                    '/appearance?section=background',
                                  ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: _secondarySectionGap),
                      _buildPageEntrance(
                        index: 2,
                        child: _buildActionSection(
                          context,
                          palette: advancedPalette,
                          title: '常用',
                          padding:
                              _isListMode
                                  ? const EdgeInsets.fromLTRB(10, 2, 10, 2)
                                  : null,
                          actions: [
                            _MineActionItem(
                              icon: Icons.sell_outlined,
                              label: '标签管理',
                              onTap: () => context.push('/mine/tags'),
                            ),
                            _MineActionItem(
                              icon: Icons.folder_copy_outlined,
                              label: '分类管理',
                              onTap: () => context.push('/mine/categories'),
                            ),
                            _MineActionItem(
                              icon: Icons.rule_rounded,
                              label: '分章规则',
                              onTap: () => context.push('/mine/chapter-rules'),
                            ),
                            _MineActionItem(
                              icon: Icons.cleaning_services_outlined,
                              label: '正文净化',
                              onTap:
                                  () => context.push('/mine/content-cleanup'),
                            ),
                            _MineActionItem(
                              icon: Icons.tune_rounded,
                              label: '系统',
                              onTap: () => context.push('/system-settings'),
                            ),
                            if (_showSourceEntry)
                              _MineActionItem(
                                icon: Icons.menu_book_rounded,
                                label: '书源',
                                subtitle: _buildSourceSubtitle(),
                                onTap: _handleSourceTap,
                              ),
                            _MineActionItem(
                              icon: Icons.cloud_outlined,
                              label: '本地缓存',
                              onTap: () => context.push('/cache'),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: _secondarySectionGap),
                      _buildPageEntrance(
                        index: 3,
                        child: _buildActionSection(
                          context,
                          palette: advancedPalette,
                          title: '其他',
                          actions: [
                            _MineActionItem(
                              icon: Icons.rate_review_outlined,
                              label: '问题反馈',
                              onTap: () => context.push('/feedback'),
                            ),
                            _MineActionItem(
                              icon: Icons.feedback_outlined,
                              label: '官方群',
                              onTap: _openSourceFeedback,
                            ),
                            _MineActionItem(
                              icon: Icons.system_update_alt,
                              label: '检查更新',
                              onTap: _checkUpdateFromMine,
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
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _restoreLayoutMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_layoutModeKey);
    final mode = raw == 'grid' ? _MineLayoutMode.grid : _MineLayoutMode.list;
    if (!mounted || _layoutMode == mode) {
      return;
    }
    setState(() {
      _layoutMode = mode;
    });
  }

  Future<void> _toggleLayoutMode() async {
    final next =
        _layoutMode == _MineLayoutMode.grid
            ? _MineLayoutMode.list
            : _MineLayoutMode.grid;
    setState(() {
      _layoutMode = next;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _layoutModeKey,
      next == _MineLayoutMode.list ? 'list' : 'grid',
    );
  }

  Widget _buildQuickAccessCards(
    BuildContext context, {
    required _MineResolvedPalette palette,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMembershipQuickCard(context, palette: palette),
        SizedBox(height: _quickAccessInnerGap),
        Row(
          children: [
            Expanded(
              child: _buildQuickCard(
                context,
                palette: palette,
                icon: Icons.sync_rounded,
                label: _isLoadingSession ? '同步中' : '同步',
                tagText: 'VIP',
                onTap: _handleSyncTap,
              ),
            ),
            SizedBox(width: _quickAccessInnerGap),
            Expanded(
              child: _buildQuickCard(
                context,
                palette: palette,
                icon: Icons.auto_awesome_outlined,
                label: '灵感',
                onTap: () => context.push('/bookmarks'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMembershipQuickCard(
    BuildContext context, {
    required _MineResolvedPalette palette,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/membership'),
        child: Container(
          padding: _quickCardPadding,
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
          padding: _quickCardPadding,
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
            padding: _profileCardPadding,
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
    if (_isLoadingSession) {
      return '正在同步账号状态与阅读数据。';
    }
    if (_userId == null) {
      return '登录后可同步阅读进度、书架和个性设置。';
    }
    if (_hasMembership) {
      return '高级权益已生效，可继续同步阅读进度并管理个性化设置。';
    }
    return '阅读进度、书架与个性设置会随账号持续同步。';
  }

  String _buildProfileStatusLabel() {
    if (_isLoadingSession) {
      return '同步中';
    }
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

  Future<void> _loadSession() async {
    await _reloadSession(showLoading: true);
  }

  Future<void> _refreshMine() async {
    await _reloadSession(showLoading: false);
  }

  Future<void> _reloadSession({required bool showLoading}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoadingSession = true;
      });
    }
    final session = await _authSessionStore.getSession();
    if (!mounted) {
      return;
    }
    setState(() {
      _userId = session?.userId;
      _username = session?.username;
      _showSourceEntry = false;
      _hasMembership = false;
      _hasThemeCustom = false;
      _sourceImportLimit = 10;
      _localAvatarPath = null;
      _isLoadingSession = false;
    });
    if (session == null) {
      return;
    }
    await _loadLocalAvatar(session.userId);
    await _loadFeatureModules();
  }

  Future<void> _loadLocalAvatar(String? userId) async {
    if (userId == null || userId.trim().isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _localAvatarPath = null;
      });
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final rawPath = prefs.getString(_profileAvatarStorageKey(userId))?.trim();
    String? nextPath;
    if (rawPath != null && rawPath.isNotEmpty) {
      final file = File(rawPath);
      if (await file.exists()) {
        nextPath = rawPath;
      } else {
        await prefs.remove(_profileAvatarStorageKey(userId));
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _localAvatarPath = nextPath;
    });
  }

  Future<void> _loadFeatureModules() async {
    try {
      final modules = await _mobileFeatureService.fetchMyModules();
      final entitlement = await _membershipService.fetchEntitlement();
      MobileFeatureModule? sourceEntry;
      MobileFeatureModule? sourceImport;
      for (final item in modules) {
        if (item.code == 'source_entry') {
          sourceEntry = item;
        } else if (item.code == 'source_import') {
          sourceImport = item;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _showSourceEntry = sourceEntry?.visible == true;
        _hasMembership = entitlement.isActive;
        _hasThemeCustom = MembershipFeatures.hasFeature(
          entitlement,
          MembershipFeatures.themeCustom,
        );
        _sourceImportLimit = sourceImport?.quotaLimit ?? 10;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _showSourceEntry = false;
        _hasMembership = false;
        _hasThemeCustom = false;
        _sourceImportLimit = 10;
      });
    }
  }

  String _profileAvatarStorageKey(String userId) =>
      'mine.profile.avatar.path.$userId';

  Future<void> _handleAvatarTap(BuildContext context) async {
    if (_userId == null) {
      await context.push('/auth');
      await _loadSession();
      return;
    }
    final action = await showModalBottomSheet<_ProfileAvatarAction>(
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
                    Icons.photo_camera_back_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('更换头像'),
                  subtitle: const Text('从本地相册或文件中选择头像'),
                  onTap:
                      () => Navigator.of(
                        context,
                      ).pop(_ProfileAvatarAction.change),
                ),
                if (_localAvatarPath != null)
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: colorScheme.error,
                    ),
                    title: const Text('移除头像'),
                    subtitle: const Text('恢复默认头像样式'),
                    onTap:
                        () => Navigator.of(
                          context,
                        ).pop(_ProfileAvatarAction.remove),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _ProfileAvatarAction.change:
        await _pickLocalAvatar();
        break;
      case _ProfileAvatarAction.remove:
        await _removeLocalAvatar();
        break;
    }
  }

  Future<void> _pickLocalAvatar() async {
    final userId = _userId;
    if (userId == null || userId.trim().isEmpty) {
      return;
    }
    try {
      final source = await _selectAvatarImageSource();
      if (source == null || !mounted) {
        return;
      }
      final picked = await _imageSelectionService.pickImage(
        confirmButtonText: '选择头像',
        allowedExtensions: const {'jpg', 'jpeg', 'png', 'webp'},
        source: source,
      );
      if (picked == null) {
        return;
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final avatarDir = Directory('${docsDir.path}/profile_avatars');
      if (!await avatarDir.exists()) {
        await avatarDir.create(recursive: true);
      }

      final existingPath = _localAvatarPath;
      if (existingPath != null && existingPath.trim().isNotEmpty) {
        final existingFile = File(existingPath);
        if (await existingFile.exists()) {
          await existingFile.delete();
        }
      }

      final extension = _avatarExtensionForName(picked.name);
      final targetPath = '${avatarDir.path}/$userId.$extension';
      final targetFile = File(targetPath);
      await targetFile.writeAsBytes(picked.bytes, flush: true);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profileAvatarStorageKey(userId), targetPath);

      if (!mounted) {
        return;
      }
      setState(() {
        _localAvatarPath = targetPath;
      });
      _showMessage('头像已更新');
    } on ImageSelectionException catch (error) {
      _showMessage(error.message);
    } on PlatformException catch (error) {
      _showMessage('选择头像失败：${error.message ?? error.code}');
    } catch (error) {
      _showMessage('更新头像失败：$error');
    }
  }

  Future<void> _removeLocalAvatar() async {
    final userId = _userId;
    if (userId == null || userId.trim().isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final existingPath = _localAvatarPath;
    if (existingPath != null && existingPath.trim().isNotEmpty) {
      final file = File(existingPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await prefs.remove(_profileAvatarStorageKey(userId));
    if (!mounted) {
      return;
    }
    setState(() {
      _localAvatarPath = null;
    });
    _showMessage('已恢复默认头像');
  }

  Future<ImageSelectionSource?> _selectAvatarImageSource() async {
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
                  subtitle: const Text('从系统照片库选择头像'),
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
                  subtitle: const Text('从文件目录选择头像'),
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

  String _avatarExtensionForName(String fileName) {
    final trimmed = fileName.trim().toLowerCase();
    if (trimmed.endsWith('.png')) {
      return 'png';
    }
    if (trimmed.endsWith('.webp')) {
      return 'webp';
    }
    if (trimmed.endsWith('.jpeg')) {
      return 'jpeg';
    }
    return 'jpg';
  }

  String _buildSourceSubtitle() {
    if (_sourceImportLimit < 0) {
      return _hasMembership ? '会员不限数量' : '默认可用';
    }
    if (_hasMembership && _sourceImportLimit > 10) {
      return '当前上限 $_sourceImportLimit 个';
    }
    return '默认最多 $_sourceImportLimit 个，扩容需会员';
  }

  Future<void> _handleAdvancedThemeTap() async {
    if (_hasThemeCustom) {
      await context.push('/appearance/advanced-themes');
      return;
    }
    await _showMembershipPrompt('高级主题为会员专属功能，开通后可用。');
  }

  void _handleSyncTap() {
    if (_hasMembership) {
      _showMessage('多端同步计划开发中，后续将优先向高级会员开放。');
      return;
    }
    unawaited(_showMembershipPrompt('多端同步为会员计划功能，当前正在开发中。'));
  }

  Future<void> _handleSourceTap() async {
    await context.push('/source');
  }

  Future<void> _showMembershipPrompt(String message) async {
    final goMembership = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('开通会员可用'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('稍后再说'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('前往会员页'),
            ),
          ],
        );
      },
    );
    if (goMembership == true && mounted) {
      await context.push('/membership');
      await _refreshMine();
    }
  }

  void _handleAuthEvent(AuthEvent event) {
    switch (event.type) {
      case AuthEventType.loggedIn:
      case AuthEventType.loggedOut:
      case AuthEventType.sessionExpired:
        unawaited(_loadSession());
        break;
    }
  }

  Widget _buildActionSection(
    BuildContext context, {
    required _MineResolvedPalette palette,
    required String title,
    required List<_MineActionItem> actions,
    EdgeInsetsGeometry? padding,
    Widget? trailing,
  }) {
    if (_layoutMode == _MineLayoutMode.list) {
      return _buildActionListSection(
        context,
        palette: palette,
        title: title,
        actions: actions,
        padding: padding,
        trailing: trailing,
      );
    }

    return _buildSectionCardShell(
      context,
      padding: padding ?? _actionSectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          SizedBox(height: _isListMode ? 8 : 2),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = AppLayout.mineActionGridColumnsForWidth(
                constraints.maxWidth,
              );
              final denseGrid = columns >= 4;
              final crossSpacing = denseGrid ? 9.0 : 10.0;
              final runSpacing = denseGrid ? 9.0 : 10.0;
              final tileHeight = switch (columns) {
                >= 4 => 92.0,
                3 => 98.0,
                _ => 106.0,
              };
              final totalCrossSpacing = crossSpacing * (columns - 1);
              final tileWidth =
                  (constraints.maxWidth - totalCrossSpacing) / columns;

              return Wrap(
                spacing: crossSpacing,
                runSpacing: runSpacing,
                children: [
                  for (var index = 0; index < actions.length; index++)
                    SizedBox(
                      width: tileWidth,
                      height: tileHeight,
                      child: _buildGridEntrance(
                        section: title,
                        index: index,
                        child: _buildActionTile(
                          context,
                          item: actions[index],
                          denseGrid: denseGrid,
                          tileId: 'mine_${title}_$index',
                          highlighted:
                              _highlightedTileId == 'mine_${title}_$index',
                          borderColor: resolveAppBorderColor(
                            Theme.of(context).colorScheme,
                            baseColor: palette.cardBorderColor,
                            containerColor: palette.cardColor,
                            tone:
                                denseGrid
                                    ? AppBorderTone.subtle
                                    : AppBorderTone.defaultTone,
                          ),
                          palette: palette,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionListSection(
    BuildContext context, {
    required _MineResolvedPalette palette,
    required String title,
    required List<_MineActionItem> actions,
    EdgeInsetsGeometry? padding,
    Widget? trailing,
  }) {
    return _buildSectionCardShell(
      context,
      padding: padding ?? _actionSectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          SizedBox(height: _isListMode ? 8 : 10),
          Container(
            decoration: BoxDecoration(
              color: palette.cardColor,
              borderRadius: BorderRadius.circular(_isListMode ? 16 : 18),
              border: Border.all(
                color: resolveAppBorderColor(
                  Theme.of(context).colorScheme,
                  baseColor: palette.cardBorderColor,
                  containerColor: palette.cardColor,
                ),
              ),
            ),
            child: Column(
              children: [
                for (var index = 0; index < actions.length; index++) ...[
                  _buildActionListTile(
                    context,
                    item: actions[index],
                    palette: palette,
                  ),
                  if (index < actions.length - 1)
                    Divider(
                      height: 1,
                      indent: 56,
                      endIndent: 14,
                      color: resolveAppBorderColor(
                        Theme.of(context).colorScheme,
                        baseColor: palette.cardBorderColor,
                        containerColor: palette.cardColor,
                        tone: AppBorderTone.subtle,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionListTile(
    BuildContext context, {
    required _MineActionItem item,
    required _MineResolvedPalette palette,
  }) {
    final iconFill = palette.iconBackgroundColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_isListMode ? 16 : 18),
        onTap: item.onTap,
        child: Padding(
          padding: _actionListTilePadding,
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: _isListMode ? 32 : 34,
                    height: _isListMode ? 32 : 34,
                    decoration: BoxDecoration(
                      color: iconFill,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.icon,
                      size: _isListMode ? 17 : 18,
                      color: palette.textPrimaryColor,
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
                            color: palette.cardColor,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.label,
                            style: (_isListMode
                                    ? Theme.of(context).textTheme.bodyMedium
                                    : Theme.of(context).textTheme.bodyLarge)
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: palette.cardTextColor,
                                ),
                          ),
                        ),
                        if (item.tagText case final tagText?) ...[
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
                    if (item.subtitle case final subtitle?) ...[
                      SizedBox(height: _isListMode ? 1 : 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.textSecondaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: palette.textSecondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required _MineActionItem item,
    required bool denseGrid,
    required String tileId,
    required bool highlighted,
    required Color borderColor,
    required _MineResolvedPalette palette,
  }) {
    final theme = Theme.of(context);
    final iconFill = palette.iconBackgroundColor;
    final iconSize = denseGrid ? 30.0 : 34.0;
    final iconGlyphSize = denseGrid ? 17.0 : 19.0;
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
        borderRadius: BorderRadius.circular(14),
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
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
              color: Colors.transparent,
            ),
            child: Padding(
              padding:
                  denseGrid
                      ? const EdgeInsets.fromLTRB(8, 7, 8, 7)
                      : const EdgeInsets.fromLTRB(9, 9, 9, 9),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: iconSize,
                              height: iconSize,
                              decoration: BoxDecoration(
                                color: iconFill,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.icon,
                                size: iconGlyphSize,
                                color: palette.textPrimaryColor,
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
                                      color: palette.cardColor,
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: denseGrid ? 4 : 8),
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
                  if (denseGrid &&
                      item.tagText != null &&
                      item.tagText!.isNotEmpty)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: palette.noticeAccentColor.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.tagText!,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: palette.noticeAccentColor,
                            height: 1.0,
                          ),
                        ),
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

  Widget _buildSectionCardShell(
    BuildContext context, {
    required Widget child,
    required EdgeInsetsGeometry padding,
  }) {
    return Padding(padding: padding, child: child);
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

  Future<void> _checkUpdateFromMine() async {
    if (_isCheckingUpdate) {
      _showMessage('正在检查更新...');
      return;
    }
    setState(() {
      _isCheckingUpdate = true;
    });
    try {
      final result = await _updateService.checkUpdate();
      if (!mounted) {
        return;
      }
      final release = result.release;
      if (!result.hasUpdate || release == null) {
        _showMessage('已是最新版本');
        return;
      }
      await AppUpdateDialog.showUpdateDialog(context, release);
    } catch (_) {
      if (mounted) {
        _showMessage('检查更新失败，请稍后再试。');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
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

class _MineActionItem {
  const _MineActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.tagText,
    this.colorDot,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? subtitle;
  final String? tagText;
  final Color? colorDot;
}

class _MineResolvedPalette {
  const _MineResolvedPalette({
    required this.cardColor,
    required this.cardTextColor,
    required this.cardBorderColor,
    required this.iconBackgroundColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.primaryColor,
    required this.noticeAccentColor,
    required this.noticeSurfaceColor,
  });

  final Color cardColor;
  final Color cardTextColor;
  final Color cardBorderColor;
  final Color iconBackgroundColor;
  final Color textPrimaryColor;
  final Color textSecondaryColor;
  final Color primaryColor;
  final Color noticeAccentColor;
  final Color noticeSurfaceColor;
}
