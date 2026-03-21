import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';

import '../../../app/theme/app_theme_seed_provider.dart';
import '../../../core/app_update/app_update_dialog.dart';
import '../../../core/app_update/app_update_service.dart';
import '../../../core/auth/auth_event_bus.dart';
import '../../../core/auth/auth_session_store.dart';
import '../../../core/user/user_profile.dart';
import '../../../core/user/user_profile_service.dart';

class MinePage extends ConsumerStatefulWidget {
  const MinePage({super.key});

  @override
  ConsumerState<MinePage> createState() => _MinePageState();
}

class _MinePageState extends ConsumerState<MinePage> {
  String? _highlightedTileId;
  static const double _ultraNarrowGridWidth = 250;
  static const EdgeInsets _profileCardPadding = EdgeInsets.fromLTRB(
    14,
    12,
    14,
    12,
  );
  static const EdgeInsets _actionSectionPadding = EdgeInsets.fromLTRB(
    14,
    12,
    14,
    14,
  );

  static final Uri _sourceFeedbackUri = Uri.parse(
    'https://qun.qq.com/universal-share/share?ac=1&authKey=Tabvg05EAafVbER7E8%2BzAQ18yErg2a%2B5PoqQH41t6dbPjcZIfDSnNX%2F4KCAXhzVh&busi_data=eyJncm91cENvZGUiOiIxMDgyODI3MjI0IiwidG9rZW4iOiIzam5tVFQ0cUs1T3VlMytzVk9iOXB1Zk40Q1RaUXJiQytzd2JlZUx3NDhXQTJscy9ZZGE5WW1hQXhPdGFwMHU1IiwidWluIjoiNzgyMDQ1MDExIn0%3D&data=PHNA5IOU4A3ujR5i9rmpWqWn4Qc-L9MNr8ByREa7IfvpXTo1utwnHVIfjkB7Rlk4x3yE9dfMR5_ZjOfsQ9wYcA&svctype=4&tempid=h5_group_info',
  );

  final AuthSessionStore _authSessionStore = AuthSessionStore();
  final AppUpdateService _updateService = AppUpdateService();
  final UserProfileService _userProfileService = UserProfileService();
  StreamSubscription<AuthEvent>? _authEventSub;
  String? _userId;
  String? _username;
  String? _vipStatusText;
  bool _isLoadingSession = true;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _authEventSub = AuthEventBus.instance.stream.listen(_handleAuthEvent);
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
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final seedColor = ref.watch(appSeedColorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
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
                    12 + bottomSafe,
                  ),
                  children: [
                    _buildPageEntrance(
                      index: 0,
                      child: _buildProfileCard(
                        context,
                        subtitle: _buildProfileSubtitle(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPageEntrance(
                      index: 1,
                      child: _buildActionSection(
                        context,
                        title: '常用',
                        actions: [
                          _MineActionItem(
                            icon: Icons.palette_outlined,
                            label: '外观',
                            colorDot: seedColor,
                            onTap: () => context.push('/appearance'),
                          ),
                          _MineActionItem(
                            icon: Icons.tune_rounded,
                            label: '系统',
                            onTap: () => context.push('/system-settings'),
                          ),
                          _MineActionItem(
                            icon: Icons.menu_book_rounded,
                            label: '书源',
                            onTap: () => context.push('/source'),
                          ),
                          _MineActionItem(
                            icon: Icons.rule_outlined,
                            label: '规则',
                            onTap: () => context.push('/rule-config'),
                          ),
                          _MineActionItem(
                            icon: Icons.cleaning_services_outlined,
                            label: '净化',
                            onTap: () => context.push('/reader-replace-rules'),
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
                            label: '阅读记录',
                            onTap: () => context.push('/read-records'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPageEntrance(
                      index: 2,
                      child: _buildActionSection(
                        context,
                        title: '其他',
                        actions: [
                          _MineActionItem(
                            icon: Icons.volunteer_activism_outlined,
                            label: '捐赠支持',
                            onTap: _showDonationSheet,
                          ),
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

  Widget _buildProfileCard(BuildContext context, {required String subtitle}) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayName =
        _userId == null
            ? '登录 / 注册'
            : ((_username?.trim().isNotEmpty ?? false) ? _username! : _userId!);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          final target = _userId == null ? '/auth' : '/profile';
          context.push(target).then((_) => _loadSession());
        },
        child: Padding(
          padding: _profileCardPadding,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.32,
                      ),
                    ),
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

  String _buildProfileSubtitle() {
    if (_isLoadingSession) {
      return '读取登录状态中...';
    }
    if (_userId == null) {
      return '未登录，点击登录/注册以同步阅读数据。';
    }
    return '会员状态：${_vipStatusText ?? '未同步'}';
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
    UserProfile? profile;
    if (session != null) {
      try {
        profile = await _userProfileService.fetchMe();
      } catch (_) {
        profile = null;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _userId = session?.userId;
      _username = profile?.username ?? session?.username;
      _vipStatusText = _resolveVipStatusText(profile);
      _isLoadingSession = false;
    });
  }

  String? _resolveVipStatusText(UserProfile? profile) {
    if (profile == null) {
      return null;
    }
    final level = (profile.vipLevel ?? '').trim().toLowerCase();
    final status = (profile.vipStatus ?? '').trim().toLowerCase();
    final isVip = level.isNotEmpty && level != 'none' && status == 'active';
    if (!isVip) {
      return '非 VIP';
    }
    if (level == 'svip') {
      return 'SVIP';
    }
    return 'VIP';
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
              final columns = _resolveGridColumns(width: constraints.maxWidth);
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

  int _resolveGridColumns({required double width}) {
    if (width < _ultraNarrowGridWidth) return 2;
    return 4;
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
                                color: colorScheme.primaryContainer.withValues(
                                  alpha: denseGrid ? 0.4 : 0.46,
                                ),
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

  Future<void> _showDonationSheet() async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '捐赠支持',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '感谢支持，扫码即可赞赏。',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.48,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/mov/vx.png',
                          width: 260,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
    this.colorDot,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? colorDot;
}
