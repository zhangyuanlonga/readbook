import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/navigation/mobile_bottom_navigation_inset.dart';
import '../../../app/navigation/app_navigation_style_provider.dart';
import '../../../app/shell_navigation_provider.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../app/theme/app_theme_provider.dart';
import '../../../app/theme/app_theme_seed_provider.dart';
import '../../../core/app_update/app_update_dialog.dart';
import '../../../core/app_update/app_update_service.dart';
import '../../../core/auth/auth_event_bus.dart';
import '../../../core/auth/auth_session_store.dart';
import '../../../core/mobile_features/mobile_feature_module.dart';
import '../../../core/mobile_features/mobile_feature_service.dart';

class MinePage extends ConsumerStatefulWidget {
  const MinePage({super.key});

  @override
  ConsumerState<MinePage> createState() => _MinePageState();
}

enum _MineLayoutMode { grid, list }

class _MinePageState extends ConsumerState<MinePage> {
  static const String _layoutModeKey = 'mine.page.layoutMode';
  String? _highlightedTileId;
  static const EdgeInsets _actionSectionPadding = EdgeInsets.fromLTRB(
    14,
    8,
    14,
    8,
  );

  static final Uri _sourceFeedbackUri = Uri.parse(
    'https://qun.qq.com/universal-share/share?ac=1&authKey=Tabvg05EAafVbER7E8%2BzAQ18yErg2a%2B5PoqQH41t6dbPjcZIfDSnNX%2F4KCAXhzVh&busi_data=eyJncm91cENvZGUiOiIxMDgyODI3MjI0IiwidG9rZW4iOiIzam5tVFQ0cUs1T3VlMytzVk9iOXB1Zk40Q1RaUXJiQytzd2JlZUx3NDhXQTJscy9ZZGE5WW1hQXhPdGFwMHU1IiwidWluIjoiNzgyMDQ1MDExIn0%3D&data=PHNA5IOU4A3ujR5i9rmpWqWn4Qc-L9MNr8ByREa7IfvpXTo1utwnHVIfjkB7Rlk4x3yE9dfMR5_ZjOfsQ9wYcA&svctype=4&tempid=h5_group_info',
  );

  final AuthSessionStore _authSessionStore = AuthSessionStore();
  final AppUpdateService _updateService = AppUpdateService();
  final MobileFeatureService _mobileFeatureService = MobileFeatureService();
  StreamSubscription<AuthEvent>? _authEventSub;
  String? _userId;
  String? _username;
  bool _isLoadingSession = true;
  bool _isCheckingUpdate = false;
  bool _showSourceEntry = false;
  _MineLayoutMode _layoutMode = _MineLayoutMode.list;

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
    final navigationPreference = ref.watch(
      appNavigationStylePreferenceProvider,
    );
    final navigationState = ref.watch(appShellNavigationProvider);
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
    final toggleTooltip =
        _layoutMode == _MineLayoutMode.grid ? '切换为列表' : '切换为网格';
    final toggleIcon =
        _layoutMode == _MineLayoutMode.grid
            ? Icons.view_list_rounded
            : Icons.grid_view_rounded;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
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

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: RefreshIndicator(
                onRefresh: _refreshMine,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    12,
                    horizontal,
                    12 + bottomInset,
                  ),
                  children: [
                    _buildPageEntrance(
                      index: 0,
                      child: _buildProfileCard(context),
                    ),
                    const SizedBox(height: 8),
                    _buildPageEntrance(
                      index: 1,
                      child: _buildActionSection(
                        context,
                        title: '外观',
                        actions: [
                          _MineActionItem(
                            icon: Icons.light_mode_outlined,
                            label: '主题模式',
                            subtitle: _themeModeLabel(themeMode),
                            onTap:
                                () => context.push(
                                  '/appearance?section=theme-mode',
                                ),
                          ),
                          _MineActionItem(
                            icon: Icons.palette_outlined,
                            label: '主题颜色',
                            subtitle: appThemeSeedLabel(seedColor),
                            colorDot: seedColor,
                            onTap:
                                () => context.push(
                                  '/appearance?section=theme-color',
                                ),
                          ),
                          _MineActionItem(
                            icon: Icons.dock_outlined,
                            label: '底栏配置',
                            subtitle:
                                '${appNavigationStylePreferenceLabel(navigationPreference)} · ${navigationState.visibleTabCount} 项',
                            onTap:
                                () => context.push(
                                  '/appearance?section=bottom-bar',
                                ),
                          ),
                          _MineActionItem(
                            icon: Icons.photo_library_outlined,
                            label: '封面图集',
                            onTap:
                                () => context.push(
                                  '/appearance?section=cover-gallery',
                                ),
                          ),
                          _MineActionItem(
                            icon: Icons.wallpaper_outlined,
                            label: '背景图集',
                            onTap:
                                () => context.push(
                                  '/appearance?section=background-gallery',
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildPageEntrance(
                      index: 2,
                      child: _buildActionSection(
                        context,
                        title: '常用',
                        actions: [
                          _MineActionItem(
                            icon: Icons.tune_rounded,
                            label: '系统',
                            onTap: () => context.push('/system-settings'),
                          ),
                          _MineActionItem(
                            icon: Icons.workspace_premium_outlined,
                            label: '会员中心',
                            onTap: () => context.push('/membership'),
                          ),
                          if (_showSourceEntry)
                            _MineActionItem(
                              icon: Icons.menu_book_rounded,
                              label: '书源',
                              onTap: () => context.push('/source'),
                            ),
                          _MineActionItem(
                            icon: Icons.cloud_outlined,
                            label: '缓存',
                            onTap: () => context.push('/cache'),
                          ),
                          _MineActionItem(
                            icon: Icons.bookmarks_outlined,
                            label: '书签',
                            onTap: () => context.push('/bookmarks'),
                          ),
                          _MineActionItem(
                            icon: Icons.history_rounded,
                            label: '统计',
                            onTap: () => context.push('/stats'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildPageEntrance(
                      index: 3,
                      child: _buildActionSection(
                        context,
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

  Widget _buildProfileCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayName =
        _userId == null
            ? '登录 / 注册'
            : ((_username?.trim().isNotEmpty ?? false) ? _username! : _userId!);
    final signature = _buildProfileSignature();
    final statusLabel = _buildProfileStatusLabel();
    final avatarLabel = _buildProfileAvatarLabel(displayName);
    final avatarFill = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.12),
      colorScheme.surface,
    );

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          final target = _userId == null ? '/auth' : '/profile';
          context.push(target).then((_) => _loadSession());
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: avatarFill,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child:
                    avatarLabel == null
                        ? Icon(
                          Icons.person_outline_rounded,
                          color: colorScheme.onSurface,
                          size: 24,
                        )
                        : Text(
                          avatarLabel,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      signature,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
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
    return '点击查看账号信息、会员状态与当前权益。';
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

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => '日间',
      ThemeMode.dark => '夜间',
      ThemeMode.system => '跟随系统',
    };
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
      _isLoadingSession = false;
    });
    if (session == null) {
      return;
    }
    await _loadFeatureModules();
  }

  Future<void> _loadFeatureModules() async {
    try {
      final modules =
          _userId == null
              ? await _mobileFeatureService.fetchPublicModules()
              : await _mobileFeatureService.fetchMyModules();
      MobileFeatureModule? sourceEntry;
      for (final item in modules) {
        if (item.code == 'source_entry') {
          sourceEntry = item;
          break;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _showSourceEntry =
            sourceEntry?.visible == true && sourceEntry?.enabled != false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _showSourceEntry = false;
      });
    }
  }

  void _handleAuthEvent(AuthEvent event) {
    switch (event.type) {
      case AuthEventType.loggedOut:
      case AuthEventType.sessionExpired:
        unawaited(_loadSession());
        break;
    }
  }

  Widget _buildActionSection(
    BuildContext context, {
    required String title,
    required List<_MineActionItem> actions,
    Widget? trailing,
  }) {
    if (_layoutMode == _MineLayoutMode.list) {
      return _buildActionListSection(
        context,
        title: title,
        actions: actions,
        trailing: trailing,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return _buildSectionCardShell(
      context,
      padding: _actionSectionPadding,
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
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = AppLayout.mineActionGridColumnsForWidth(
                constraints.maxWidth,
              );
              final denseGrid = columns >= 4;
              final crossSpacing = denseGrid ? 9.0 : 10.0;
              final mainSpacing = denseGrid ? 9.0 : 10.0;
              final mainAxisExtent = switch (columns) {
                >= 4 => 92.0,
                3 => 102.0,
                _ => 110.0,
              };

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: crossSpacing,
                  mainAxisSpacing: mainSpacing,
                  mainAxisExtent: mainAxisExtent,
                ),
                itemBuilder: (context, index) {
                  final item = actions[index];
                  final tileId = 'mine_${title}_$index';
                  return _buildGridEntrance(
                    section: title,
                    index: index,
                    child: _buildActionTile(
                      context,
                      item: item,
                      denseGrid: denseGrid,
                      tileId: tileId,
                      highlighted: _highlightedTileId == tileId,
                      borderColor: colorScheme.outlineVariant.withValues(
                        alpha: denseGrid ? 0.34 : 0.42,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionListSection(
    BuildContext context, {
    required String title,
    required List<_MineActionItem> actions,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return _buildSectionCardShell(
      context,
      padding: _actionSectionPadding,
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
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.48),
              ),
            ),
            child: Column(
              children: [
                for (var index = 0; index < actions.length; index++) ...[
                  _buildActionListTile(context, item: actions[index]),
                  if (index < actions.length - 1)
                    Divider(
                      height: 1,
                      indent: 56,
                      endIndent: 14,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.45),
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
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconFill = Color.alphaBlend(
      colorScheme.onSurface.withValues(alpha: 0.04),
      colorScheme.surface,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: iconFill,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.icon,
                      size: 18,
                      color: colorScheme.onSurface,
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
                            color: colorScheme.surface,
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
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.subtitle case final subtitle?) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
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
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconFill = Color.alphaBlend(
      colorScheme.onSurface.withValues(alpha: denseGrid ? 0.035 : 0.045),
      colorScheme.surface,
    );
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
              padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
              child: Stack(
                children: [
                  Center(
                    child: Column(
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
                                color: colorScheme.onSurface,
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
                                      color: colorScheme.surface,
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: denseGrid ? 6 : 8),
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
    this.colorDot,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? subtitle;
  final Color? colorDot;
}
