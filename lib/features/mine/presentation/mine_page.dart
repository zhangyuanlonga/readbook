import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/images/local_file_image.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/navigation/bottom_nav_icon_gallery_provider.dart';
import '../../../app/navigation/mobile_bottom_navigation_inset.dart';
import '../../../app/navigation/app_navigation_style_provider.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/theme/app_border_tokens.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../app/theme/app_theme_provider.dart';
import '../../../app/theme/app_theme_seed_provider.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../core/app_update/app_update_dialog.dart';
import '../../../core/app_update/app_update_service.dart';
import '../../../core/auth/auth_event_bus.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../application/advanced_theme_provider.dart';
import '../application/launch_image_gallery_provider.dart';
import '../application/mine_page_flow_coordinator.dart';
import '../application/mine_page_preferences_service.dart';
import '../application/mine_page_session_service.dart';
import '../providers.dart';

part 'mine_page_view.dart';

class MinePage extends ConsumerStatefulWidget {
  const MinePage({super.key});

  @override
  ConsumerState<MinePage> createState() => _MinePageState();
}

enum _MineLayoutMode { grid, list }

enum _ProfileAvatarAction { change, remove }

class _MinePageState extends ConsumerState<MinePage> {
  static const String _layoutModeKey = 'mine.page.layoutMode';
  static final Uri _sourceFeedbackUri = Uri.parse(
    'https://qun.qq.com/universal-share/share?ac=1&authKey=Tabvg05EAafVbER7E8%2BzAQ18yErg2a%2B5PoqQH41t6dbPjcZIfDSnNX%2F4KCAXhzVh&busi_data=eyJncm91cENvZGUiOiIxMDgyODI3MjI0IiwidG9rZW4iOiIzam5tVFQ0cUs1T3VlMytzVk9iOXB1Zk40Q1RaUXJiQytzd2JlZUx3NDhXQTJscy9ZZGE5WW1hQXhPdGFwMHU1IiwidWluIjoiNzgyMDQ1MDExIn0%3D&data=PHNA5IOU4A3ujR5i9rmpWqWn4Qc-L9MNr8ByREa7IfvpXTo1utwnHVIfjkB7Rlk4x3yE9dfMR5_ZjOfsQ9wYcA&svctype=4&tempid=h5_group_info',
  );

  late final AppUpdateService _updateService;
  late final ImageSelectionService _imageSelectionService;
  late final MinePageFlowCoordinator _pageFlowCoordinator;
  late final MinePageSessionService _sessionService;
  String? _userId;
  String? _username;
  String? _localAvatarPath;
  bool _isCheckingUpdate = false;
  bool _hasMembership = false;
  bool _hasThemeCustom = false;
  bool _isRemoteAccessResolved = false;
  _MineLayoutMode _layoutMode = _MineLayoutMode.list;
  bool _didRestoreLayoutMode = false;
  String? _openingRoute;

  bool get _isListMode => _layoutMode == _MineLayoutMode.list;

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
    _updateService = ref.read(mineUpdateServiceProvider);
    _imageSelectionService = ref.read(mineImageSelectionServiceProvider);
    _pageFlowCoordinator = ref.read(minePageFlowCoordinatorProvider)();
    _sessionService = ref.read(minePageSessionServiceProvider);
    _pageFlowCoordinator.initialize(onAuthEvent: _handleAuthEvent);
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

  Future<void> _restoreLayoutMode() async {
    final preferGridByDefault = AppAdaptiveMetrics.of(context).isMediumUpWindow;
    final defaultMode =
        preferGridByDefault ? _MineLayoutMode.grid : _MineLayoutMode.list;
    final raw = await _sessionService.restoreLayoutMode(_layoutModeKey);
    final mode =
        raw == null
            ? defaultMode
            : raw == 'grid'
            ? _MineLayoutMode.grid
            : _MineLayoutMode.list;
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
    await _sessionService.persistLayoutMode(
      storageKey: _layoutModeKey,
      value: next == _MineLayoutMode.list ? 'list' : 'grid',
    );
  }

  Future<void> _loadSession() async {
    await _reloadSession(showLoading: true, refreshRemote: false);
  }

  Future<void> _refreshMine() async {
    await _reloadSession(showLoading: false, refreshRemote: true);
  }

  Future<void> _reloadSession({
    required bool showLoading,
    required bool refreshRemote,
  }) async {
    final snapshot = await _sessionService.loadSession(
      refreshRemote: refreshRemote,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _userId = snapshot.session?.userId;
      _username =
          snapshot.session?.displayIdentity ?? snapshot.session?.loginIdentity;
      _hasMembership = snapshot.hasMembership;
      _hasThemeCustom = snapshot.hasThemeCustom;
      _isRemoteAccessResolved = snapshot.isRemoteAccessResolved;
      _localAvatarPath = snapshot.localAvatarPath;
    });
    if (snapshot.session == null) {
      return;
    }
  }

  Future<void> _handleAvatarTap(BuildContext context) async {
    if (_userId == null) {
      await context.push('/auth');
      await _loadSession();
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
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
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
    if (!_isRemoteAccessResolved) {
      await _refreshMine();
      if (!mounted) {
        return;
      }
      if (_hasThemeCustom) {
        await _pushMineRoute('/appearance/advanced-themes');
        return;
      }
    }
    await _showMembershipPrompt('高级主题为会员专属功能，开通后可用。');
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
              '开通会员可用',
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
                  child: const Text('前往会员页'),
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
        unawaited(_reloadSession(showLoading: false, refreshRemote: true));
        break;
      case AuthEventType.loggedOut:
      case AuthEventType.sessionExpired:
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
  }) {
    final layout = _layoutMode;
    final sectionKey = ValueKey<String>('mine_section_${title}_$layout');
    final sectionChild =
        layout == _MineLayoutMode.list
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
                      final columns = AppLayout.mineActionGridColumnsForWidth(
                        constraints.maxWidth,
                      );
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

    final incomingIsGrid = layout == _MineLayoutMode.grid;
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
