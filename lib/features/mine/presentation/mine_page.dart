import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/images/local_file_image.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/navigation/bottom_nav_icon_gallery_provider.dart';
import '../../../app/navigation/mobile_bottom_navigation_inset.dart';
import '../../../app/navigation/app_navigation_style_provider.dart';
import '../../../app/platform/app_platform_capabilities.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/theme/app_border_tokens.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../app/theme/app_theme_provider.dart';
import '../../../app/theme/app_theme_seed_provider.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/foundation/app_feedback.dart';
import '../../../app/widgets/foundation/app_refresh_indicator.dart';
import '../../../core/auth/auth_event_bus.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../core/membership/membership_access_presentation.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../application/advanced_theme_provider.dart';
import '../application/launch_image_gallery_provider.dart';
import '../application/mine_page_flow_coordinator.dart';
import '../application/mine_page_preferences_service.dart';
import '../application/mine_page_session_service.dart';
import '../../auth/providers.dart';
import '../providers.dart';

part 'mine_page_view.dart';

class MinePage extends ConsumerStatefulWidget {
  const MinePage({super.key});

  @override
  ConsumerState<MinePage> createState() => _MinePageState();
}

enum _ProfileAvatarAction { change, remove }

class _MinePageState extends ConsumerState<MinePage> {
  late final ImageSelectionService _imageSelectionService;
  late final MinePageFlowCoordinator _pageFlowCoordinator;
  late final MinePageSessionService _sessionService;
  late final AuthService _authService;
  late final ProviderSubscription<int> _snapshotRevisionSubscription;
  String? _userId;
  String? _username;
  String? _localAvatarPath;
  DateTime? _vipExpireAt;
  String? _membershipPlanType;
  bool _hasMembership = false;
  bool _hasThemeCustom = false;
  bool _isRemoteAccessResolved = false;
  bool _isLoggingOut = false;
  MinePageLayoutMode _layoutMode = MinePageLayoutMode.list;
  bool _didRestoreLayoutMode = false;
  String? _openingRoute;
  int _sessionReloadVersion = 0;

  bool get _isListMode => _layoutMode == MinePageLayoutMode.list;

  VoidCallback _pushMineRouteAction(String route) {
    return () => unawaited(_pushMineRoute(route));
  }

  Future<void> _pushMineRoute(String route) async {
    if (_openingRoute == route) {
      return;
    }
    _openingRoute = route;
    try {
      await context.push(route);
    } finally {
      if (_openingRoute == route) {
        _openingRoute = null;
      }
    }
  }

  EdgeInsets _actionSectionPaddingFor(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return _isListMode
        ? EdgeInsets.symmetric(vertical: metrics.contentGap * 0.35)
        : EdgeInsets.fromLTRB(
          metrics.cardPadding,
          metrics.contentGap * 0.55,
          metrics.cardPadding,
          metrics.contentGap * 0.55,
        );
  }

  double _primarySectionGapFor(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return _isListMode ? metrics.contentGap * 0.85 : metrics.contentGap;
  }

  double _secondarySectionGapFor(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return _isListMode ? metrics.contentGap * 0.75 : metrics.contentGap * 0.45;
  }

  EdgeInsets _profileCardPaddingFor(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return _isListMode
        ? EdgeInsets.fromLTRB(
          metrics.cardPadding,
          metrics.contentGap,
          metrics.cardPadding,
          metrics.contentGap,
        )
        : EdgeInsets.fromLTRB(
          metrics.cardPadding + 2,
          metrics.cardPadding,
          metrics.cardPadding + 2,
          metrics.cardPadding,
        );
  }

  EdgeInsets _actionListTilePaddingFor(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return _isListMode
        ? EdgeInsets.fromLTRB(
          metrics.cardPadding * 0.95,
          metrics.contentGap * 1.15,
          metrics.cardPadding * 0.95,
          metrics.contentGap * 1.15,
        )
        : EdgeInsets.fromLTRB(
          metrics.cardPadding * 0.8,
          metrics.cardPadding * 0.65,
          metrics.cardPadding * 0.8,
          metrics.cardPadding * 0.65,
        );
  }

  @override
  void initState() {
    super.initState();
    _imageSelectionService = ref.read(mineImageSelectionServiceProvider);
    _pageFlowCoordinator = ref.read(minePageFlowCoordinatorProvider)();
    _sessionService = ref.read(minePageSessionServiceProvider);
    _authService = ref.read(authServiceProvider);
    _pageFlowCoordinator.initialize(onAuthEvent: _handleAuthEvent);
    _snapshotRevisionSubscription = ref.listenManual<int>(
      mineRemoteAccessSnapshotRevisionProvider,
      (_, __) {
        // 会员中心更新缓存后，立即同步刷新本地状态，避免显示旧的会员状态
        unawaited(_reloadSession(showLoading: false, refreshRemote: false));
      },
    );
    _applyPrimedSession();
    _loadSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didRestoreLayoutMode) {
      return;
    }
    _didRestoreLayoutMode = true;
    unawaited(_restoreLayoutMode());
  }

  @override
  void dispose() {
    _snapshotRevisionSubscription.close();
    unawaited(_pageFlowCoordinator.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildMinePage(context);

  void _applyPrimedSession() {
    final session = MinePageSessionPriming.take();
    if (session == null) {
      return;
    }
    _userId = session.userId;
    _username = session.displayIdentity ?? session.loginIdentity;
  }

  void _resetAccountScopedState({bool remoteAccessResolved = true}) {
    _userId = null;
    _username = null;
    _localAvatarPath = null;
    _vipExpireAt = null;
    _membershipPlanType = null;
    _hasMembership = false;
    _hasThemeCustom = false;
    _isRemoteAccessResolved = remoteAccessResolved;
  }

  Future<void> _restoreLayoutMode() async {
    final preferGridByDefault = AppAdaptiveMetrics.of(context).isMediumUpWindow;
    final defaultMode =
        preferGridByDefault ? MinePageLayoutMode.grid : MinePageLayoutMode.list;
    final persistedMode =
        await ref.read(minePagePreferencesServiceProvider).loadLayoutMode();
    final mode = persistedMode ?? defaultMode;
    if (!mounted || _layoutMode == mode) {
      return;
    }
    setState(() {
      _layoutMode = mode;
    });
  }

  Future<void> _toggleLayoutMode() async {
    final next =
        _layoutMode == MinePageLayoutMode.grid
            ? MinePageLayoutMode.list
            : MinePageLayoutMode.grid;
    setState(() {
      _layoutMode = next;
    });
    await ref.read(minePagePreferencesServiceProvider).saveLayoutMode(next);
  }

  Future<void> _loadSession() async {
    // 先读缓存展示首屏
    await _reloadSession(showLoading: true, refreshRemote: false);
    if (!mounted || _userId == null) {
      return;
    }
    // 登录页返回、资料页返回都可能触发普通加载；先用缓存保障首屏，再补远端刷新，
    // 避免新账号或刚开通会员继续命中旧的本地权益快照。
    // 远端刷新完成后，会通过 _reloadSession 的逻辑自动更新 UI 状态
    unawaited(_reloadSession(showLoading: false, refreshRemote: true));
  }

  Future<void> _refreshMine() async {
    await _reloadSession(showLoading: false, refreshRemote: true);
  }

  Future<void> _reloadSession({
    required bool showLoading,
    required bool refreshRemote,
  }) async {
    // 登录、注册、退出和远端权益刷新都可能同时触发 Mine 页重载；只允许最后一次请求回写，避免旧账号资料覆盖新账号卡片。
    final reloadVersion = ++_sessionReloadVersion;
    final snapshot = await _sessionService.loadSession(
      refreshRemote: refreshRemote,
    );
    if (!mounted || reloadVersion != _sessionReloadVersion) {
      return;
    }
    setState(() {
      if (snapshot.session == null) {
        _resetAccountScopedState(
          remoteAccessResolved: snapshot.isRemoteAccessResolved,
        );
      } else {
        _userId = snapshot.session?.userId;
        _username =
            snapshot.session?.displayIdentity ??
            snapshot.session?.loginIdentity;
        _hasMembership = snapshot.hasMembership;
        _hasThemeCustom = snapshot.hasThemeCustom;
        _isRemoteAccessResolved = snapshot.isRemoteAccessResolved;
        _localAvatarPath = snapshot.localAvatarPath;
        _vipExpireAt = snapshot.vipExpireAt;
        _membershipPlanType = snapshot.membershipPlanType;
      }
    });
    if (snapshot.session == null) {
      return;
    }
    // 如果缓存过期或者会员信息不完整，触发远程刷新
    // 注意：这里只在非远程刷新模式下检查，避免无限递归
    final shouldRefreshRemote =
        !refreshRemote &&
        (snapshot.shouldRefreshRemoteAccess ||
            (snapshot.hasMembership && snapshot.vipExpireAt == null));
    if (shouldRefreshRemote) {
      unawaited(_reloadSession(showLoading: false, refreshRemote: true));
    }
  }

  Future<void> _handleProfileCardTap() async {
    if (_userId == null) {
      // 未登录：跳转到登录页
      // 登录成功后会触发 AuthEventType.loggedIn 事件，_handleAuthEvent 会自动刷新
      await context.push('/auth');
      return;
    }
    // 已登录：跳转到资料页
    // 资料页可能修改了用户信息（如头像、昵称），返回后需要刷新
    await context.push('/profile');
    await _refreshMine();
  }

  Future<void> _handleProfileActionButtonTap() async {
    if (_userId == null) {
      await _handleProfileCardTap();
      return;
    }
    final confirmed = await showAdaptiveActionSurface<bool>(
      context: context,
      useRootNavigator: true,
      maxWidth: 420,
      builder: (surfaceContext) {
        final colorScheme = Theme.of(surfaceContext).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.logout_rounded, color: colorScheme.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '退出登录',
                    style: Theme.of(surfaceContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '确定要退出当前账号吗？',
              style: Theme.of(surfaceContext).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(surfaceContext).pop(false),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(surfaceContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                  ),
                  child: const Text('退出'),
                ),
              ],
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await _logoutFromMineCard();
  }

  Future<void> _logoutFromMineCard() async {
    if (_isLoggingOut) {
      return;
    }
    setState(() {
      _isLoggingOut = true;
    });
    try {
      await _authService.logout();
      // logout() 会触发 AuthEventType.loggedOut 事件
      // _handleAuthEvent 会处理状态清理，这里只显示消息
      if (!mounted) {
        return;
      }
      _showMessage('已退出登录。');
    } catch (_) {
      if (mounted) {
        _showMessage('退出失败，请稍后再试。');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  Future<void> _handleAvatarTap(BuildContext context) async {
    if (_userId == null) {
      // 未登录：跳转到登录页
      // 登录成功后会触发 AuthEventType.loggedIn 事件，_handleAuthEvent 会自动刷新
      await context.push('/auth');
      return;
    }
    final action = await showAdaptiveActionSurface<_ProfileAvatarAction>(
      context: context,
      useRootNavigator: true,
      maxWidth: 420,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Column(
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
                  () => Navigator.of(context).pop(_ProfileAvatarAction.change),
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
                    () =>
                        Navigator.of(context).pop(_ProfileAvatarAction.remove),
              ),
          ],
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
      final targetPath = await _sessionService.saveLocalAvatar(
        userId: userId,
        picked: picked,
        existingPath: _localAvatarPath,
      );

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
    await _sessionService.removeLocalAvatar(
      userId: userId,
      existingPath: _localAvatarPath,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _localAvatarPath = null;
    });
    _showMessage('已恢复默认头像');
  }

  Future<ImageSelectionSource?> _selectAvatarImageSource() async {
    final capabilities = ref.read(appPlatformCapabilitiesProvider);
    if (capabilities.shouldUseFilePickerForProfileAvatar) {
      return ImageSelectionSource.files;
    }
    return showAdaptiveActionSurface<ImageSelectionSource>(
      context: context,
      useRootNavigator: true,
      maxWidth: 420,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Column(
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
                  () => Navigator.of(context).pop(ImageSelectionSource.gallery),
            ),
            ListTile(
              leading: Icon(
                Icons.folder_open_outlined,
                color: colorScheme.primary,
              ),
              title: const Text('文件'),
              subtitle: const Text('从文件目录选择头像'),
              onTap:
                  () => Navigator.of(context).pop(ImageSelectionSource.files),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAdvancedThemeTap() async {
    if (_hasThemeCustom) {
      await _pushMineRoute('/appearance/advanced-themes');
      return;
    }
    if (!_isRemoteAccessResolved || _userId != null) {
      await _refreshMine();
      if (!mounted) {
        return;
      }
      if (_hasThemeCustom) {
        await _pushMineRoute('/appearance/advanced-themes');
        return;
      }
    }
    await _showMembershipPrompt(
      MembershipAccessPresentation.unavailableMessage(
        MembershipFeatureGate.advancedTheme,
        isLoggedIn: _userId != null,
      ),
    );
  }

  Future<void> _openMembershipCenter() async {
    await _pushMineRoute('/membership');
    await _refreshMine();
  }

  Future<void> _showMembershipPrompt(String message) async {
    final goMembership = await showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 420,
      builder: (dialogContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              MembershipAccessPresentation.upgradeTitle,
              style: Theme.of(
                dialogContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(message, style: Theme.of(dialogContext).textTheme.bodyMedium),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('稍后再说'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text(
                    MembershipAccessPresentation.membershipButtonLabel,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    if (goMembership == true && mounted) {
      await _openMembershipCenter();
    }
  }

  void _handleAuthEvent(AuthEvent event) {
    switch (event.type) {
      case AuthEventType.loggedIn:
        // 用户登录成功，递增版本号防止旧的加载覆盖新账号数据
        ++_sessionReloadVersion;
        if (mounted) {
          // 先清空旧账号的状态，避免显示旧账号的会员信息
          // 重要：必须清空，否则会员A退出后登录普通账号B，会显示A的会员状态
          setState(() {
            _resetAccountScopedState(remoteAccessResolved: false);
          });
        }
        // 触发远程刷新，加载新账号的会员信息
        unawaited(_reloadSession(showLoading: false, refreshRemote: true));
        break;
      case AuthEventType.loggedOut:
      case AuthEventType.sessionExpired:
        ++_sessionReloadVersion;
        if (mounted) {
          setState(() {
            _resetAccountScopedState();
          });
        }
        unawaited(_reloadSession(showLoading: false, refreshRemote: false));
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
    int? maxGridColumns,
  }) {
    final layout = _layoutMode;
    final sectionKey = ValueKey<String>('mine_section_${title}_$layout');
    final sectionChild =
        layout == MinePageLayoutMode.list
            ? _buildActionListSection(
              context,
              palette: palette,
              title: title,
              actions: actions,
              padding: padding,
              trailing: trailing,
            )
            : _buildSectionCardShell(
              context,
              padding: padding ?? _actionSectionPaddingFor(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (trailing != null) trailing,
                    ],
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      var columns = AppLayout.mineActionGridColumnsForWidth(
                        constraints.maxWidth,
                      );
                      final gridColumnLimit = maxGridColumns;
                      if (gridColumnLimit != null &&
                          columns > gridColumnLimit) {
                        columns = gridColumnLimit;
                      }
                      final denseGrid = columns >= 4;
                      final crossSpacing = denseGrid ? 8.0 : 10.0;
                      final runSpacing = denseGrid ? 8.0 : 10.0;
                      final tileHeight = switch (columns) {
                        >= 4 => 82.0,
                        3 => 88.0,
                        _ => 96.0,
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

    final incomingIsGrid = layout == MinePageLayoutMode.grid;
    return AppAnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final isIncoming = child.key == sectionKey;
        final beginScale =
            incomingIsGrid
                ? (isIncoming ? 0.94 : 1.0)
                : (isIncoming ? 1.03 : 1.0);
        final beginOffset =
            incomingIsGrid ? const Offset(0, 0.03) : const Offset(0, -0.02);
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(fade),
            child: ScaleTransition(
              scale: Tween<double>(begin: beginScale, end: 1).animate(fade),
              child: child,
            ),
          ),
        );
      },
      child: KeyedSubtree(key: sectionKey, child: sectionChild),
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
      padding: padding ?? _actionSectionPaddingFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: palette.cardColor,
              borderRadius: BorderRadius.circular(18),
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
                      indent: 58,
                      endIndent: 16,
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
        borderRadius: BorderRadius.circular(18),
        onTap: item.onTap,
        child: Padding(
          padding: _actionListTilePaddingFor(context),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: _isListMode ? 36 : 34,
                    height: _isListMode ? 36 : 34,
                    decoration: BoxDecoration(
                      color: iconFill,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item.icon,
                      size: _isListMode ? 18 : 18,
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
                        maxLines: _isListMode ? 2 : 1,
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
    required Color borderColor,
    required _MineResolvedPalette palette,
  }) {
    final theme = Theme.of(context);
    final iconFill = palette.iconBackgroundColor;
    final iconSize = denseGrid ? 28.0 : 32.0;
    final iconGlyphSize = denseGrid ? 16.0 : 18.0;
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
        onTap: item.onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            color: palette.cardColor.withValues(alpha: 0.48),
          ),
          child: Padding(
            padding:
                denseGrid
                    ? const EdgeInsets.fromLTRB(7, 6, 7, 6)
                    : const EdgeInsets.fromLTRB(8, 8, 8, 8),
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
                      SizedBox(height: denseGrid ? 4 : 6),
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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
    return child;
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

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    AppFeedback.showSnackBar(
      context,
      message: message,
      tone:
          message.contains('失败') ? AppFeedbackTone.error : AppFeedbackTone.info,
      useHaptics: false,
    );
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
