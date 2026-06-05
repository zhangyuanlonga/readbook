import 'dart:async';
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:circular_theme_reveal/circular_theme_reveal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth/auth_event_bus.dart';
import '../core/auth/auth_session.dart';
import '../core/auth/auth_service.dart';
import '../core/auth/auth_session_store.dart';
import '../domain/entities/bottom_nav_icon_gallery.dart';
import '../features/auth/providers.dart';
import '../features/bookshelf/providers.dart';
import '../features/mine/application/advanced_theme_provider.dart';
import 'layout/app_adaptive.dart';
import 'theme/app_advanced_theme_tokens.dart';
import 'theme/app_theme_provider.dart';
import 'theme/app_border_tokens.dart';
import 'theme/app_component_theme_tokens.dart';
import 'layout/app_layout.dart';
import 'navigation/bottom_nav_icon_gallery_provider.dart';
import 'navigation/bottom_nav_icon_resolver.dart';
import 'navigation/app_navigation_style_provider.dart';
import 'shell_navigation_provider.dart';
import 'widgets/bottom_nav_icon_view.dart';
import 'widgets/cupertino_dock_navigation_bar.dart';
import 'widgets/app_task_queue_surface.dart';
import 'widgets/adaptive_search_bar.dart';

class ShellScaffold extends ConsumerStatefulWidget {
  const ShellScaffold({
    super.key,
    required this.location,
    this.navigationShell,
    this.child,
  }) : assert(
         navigationShell != null || child != null,
         'Either navigationShell or child must be provided.',
       );

  final String location;
  final StatefulNavigationShell? navigationShell;
  final Widget? child;

  @override
  ConsumerState<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<ShellScaffold>
    with SingleTickerProviderStateMixin {
  static const double _kSwipeVelocityThreshold = 420;
  static const bool _kEnableMobileTabSwitchAnimation = true;
  static const Duration _kTabSwitchDuration = Duration(milliseconds: 240);

  late int _currentOrderIndex;
  bool _isForward = true;
  String? _pendingRedirectLocation;
  late final AnimationController _tabSwitchController;
  late final Animation<double> _tabSlideCurve;
  late final Animation<double> _tabFadeCurve;
  late final Animation<double> _tabScaleCurve;
  late final AuthService _authService;
  late final TextEditingController _desktopBookshelfSearchController;
  late final FocusNode _desktopBookshelfSearchFocusNode;
  StreamSubscription<AuthEvent>? _authEventSubscription;
  AuthSession? _topBarSession;
  bool _isShellLoggingOut = false;

  Future<void> _openSearchWithReveal(
    BuildContext sourceContext, {
    String route = '/search?entry=dock',
  }) async {
    final overlay = CircularThemeRevealOverlay.of(sourceContext);
    final center = CircularThemeRevealOverlay.getCenterFromContext(
      sourceContext,
    );
    if (overlay == null) {
      await sourceContext.push(route);
      return;
    }
    await overlay.startTransition(
      center: center,
      reverse: false,
      onThemeChange: () {
        sourceContext.push(route);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _desktopBookshelfSearchController = TextEditingController();
    _desktopBookshelfSearchFocusNode = FocusNode();
    _authService = ref.read(authServiceProvider);
    _authEventSubscription = AuthEventBus.instance.stream.listen(
      _handleAuthEvent,
    );
    unawaited(_loadTopBarSession());
    _currentOrderIndex = _locationOrderIndex(widget.location);
    _tabSwitchController = AnimationController(
      vsync: this,
      duration: _kTabSwitchDuration,
      value: 1,
    );
    _tabSlideCurve = CurvedAnimation(
      parent: _tabSwitchController,
      curve: Curves.easeOutCubic,
    );
    _tabFadeCurve = CurvedAnimation(
      parent: _tabSwitchController,
      curve: const Interval(0.08, 1, curve: Curves.easeOutCubic),
    );
    _tabScaleCurve = CurvedAnimation(
      parent: _tabSwitchController,
      curve: const Interval(0.0, 1, curve: Curves.easeOutQuart),
    );
  }

  @override
  void didUpdateWidget(covariant ShellScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextIndex = _locationOrderIndex(widget.location);
    if (nextIndex == _currentOrderIndex) {
      return;
    }

    _isForward = nextIndex > _currentOrderIndex;
    _currentOrderIndex = nextIndex;
    if (_kEnableMobileTabSwitchAnimation) {
      _tabSwitchController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    unawaited(_authEventSubscription?.cancel());
    _tabSwitchController.dispose();
    _desktopBookshelfSearchFocusNode.dispose();
    _desktopBookshelfSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadTopBarSession() async {
    final prefs = await SharedPreferences.getInstance();
    final session = AuthSessionStore.readDisplaySession(prefs);
    if (!mounted) {
      return;
    }
    setState(() {
      _topBarSession = session;
    });
  }

  void _handleAuthEvent(AuthEvent event) {
    switch (event.type) {
      case AuthEventType.loggedIn:
        unawaited(_loadTopBarSession());
        break;
      case AuthEventType.loggedOut:
      case AuthEventType.sessionExpired:
        if (!mounted) {
          return;
        }
        setState(() {
          _topBarSession = null;
        });
        break;
    }
  }

  Future<void> _handleShellLogout(BuildContext context) async {
    if (_isShellLoggingOut || _topBarSession == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('退出登录'),
          content: const Text('确定要退出当前账号吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('退出'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted || !context.mounted) {
      return;
    }
    setState(() {
      _isShellLoggingOut = true;
    });
    try {
      await _authService.logout();
      if (!mounted || !context.mounted) {
        return;
      }
      setState(() {
        _topBarSession = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已退出登录。')));
    } catch (_) {
      if (!mounted || !context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('退出失败，请稍后再试。')));
    } finally {
      if (mounted) {
        setState(() {
          _isShellLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final platform = Theme.of(context).platform;
    final shellChild = RepaintBoundary(
      child: widget.navigationShell ?? widget.child!,
    );
    final metrics = AppAdaptiveMetrics.of(context);
    final useNavigationRail =
        AppLayout.isMediumUp(context) ||
        metrics.isDesktopLikeForPlatform(isWeb: kIsWeb, platform: platform);
    final enableTabSwipe =
        !kIsWeb && _isMobilePlatform(platform) && !useNavigationRail;
    final navigationStylePreference = ref.watch(
      appNavigationStylePreferenceProvider,
    );
    final showNavigationLabels = ref.watch(
      appNavigationLabelVisibilityProvider,
    );
    final standardNavigationAppearance = ref.watch(
      appStandardNavigationBarAppearanceProvider,
    );
    final cupertinoDockAppearance = ref.watch(
      appCupertinoDockAppearanceProvider,
    );
    final navigationState = ref.watch(appShellNavigationProvider);
    final visibleDestinations = visibleAppShellDestinations(navigationState);
    final activeIconGallery =
        ref.watch(effectiveBottomNavIconGalleryProvider).value;
    ref.watch(activeAdvancedThemeProvider);
    final effectiveNavigationStyle = resolveAppNavigationStyle(
      navigationStylePreference,
      isWeb: kIsWeb,
      platform: platform,
    );
    final currentTab = _locationTab(widget.location);
    final selectedIndex = visibleDestinations.indexWhere(
      (destination) => destination.tab == currentTab,
    );
    final effectiveSelectedIndex = selectedIndex >= 0 ? selectedIndex : 0;
    final canShowNavigation = visibleDestinations.length >= 2;

    if (selectedIndex < 0 && visibleDestinations.isNotEmpty) {
      _scheduleRedirectToVisibleTab(
        context,
        visibleDestinations.first.location,
      );
    } else {
      _pendingRedirectLocation = null;
    }

    final shouldAnimateSwitch =
        enableTabSwipe &&
        _kEnableMobileTabSwitchAnimation &&
        currentTab != AppShellTab.mine &&
        !disableAnimations;

    final switchedChild =
        shouldAnimateSwitch
            ? AnimatedBuilder(
              animation: _tabSwitchController,
              child: shellChild,
              builder: (context, child) {
                final slideProgress = _tabSlideCurve.value;
                final fadeProgress = _tabFadeCurve.value;
                final scaleProgress = _tabScaleCurve.value;
                final dx = (_isForward ? 12.0 : -12.0) * (1 - slideProgress);
                final opacity = lerpDouble(0.84, 1.0, fadeProgress)!;
                final scale = lerpDouble(0.996, 1.0, scaleProgress)!;
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(scale: scale, child: child),
                  ),
                );
              },
            )
            : shellChild;
    final clippedChild = ClipRect(child: switchedChild);

    final navigatedBody =
        enableTabSwipe
            ? GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd:
                  (details) => _onHorizontalDragEnd(
                    context,
                    currentIndex: effectiveSelectedIndex,
                    destinations: visibleDestinations,
                    details: details,
                  ),
              child: clippedChild,
            )
            : clippedChild;
    final taskQueueBottom = useNavigationRail ? 24.0 : 96.0;
    final body = Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: navigatedBody),
        AppTaskQueueButton(bottom: taskQueueBottom),
      ],
    );

    if (!canShowNavigation) {
      return Scaffold(body: body);
    }

    if (useNavigationRail) {
      return _buildDesktopShell(
        context,
        body: body,
        destinations: visibleDestinations,
        selectedIndex: effectiveSelectedIndex,
      );
    }

    return Scaffold(
      extendBody: true,
      body: body,
      bottomNavigationBar: _buildMobileBottomNavigationBar(
        context,
        destinations: visibleDestinations,
        selectedIndex: effectiveSelectedIndex,
        style: effectiveNavigationStyle,
        showNavigationLabels: showNavigationLabels,
        activeIconGallery: activeIconGallery,
        standardAppearance: standardNavigationAppearance,
        cupertinoDockAppearance: cupertinoDockAppearance,
        showSearchButton: true,
      ),
    );
  }

  bool _isMobilePlatform(TargetPlatform platform) {
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  Widget _buildDesktopShell(
    BuildContext context, {
    required Widget body,
    required List<AppShellDestination> destinations,
    required int selectedIndex,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final width = AppLayout.screenWidth(context);
    final sidebarWidth =
        width >= AppLayout.expandedBreakpointWidth ? 244.0 : 216.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Row(
        children: [
          _buildDesktopSidebar(
            context,
            width: sidebarWidth,
            destinations: destinations,
            selectedIndex: selectedIndex,
          ),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(color: colorScheme.surface),
              child: Column(
                children: [
                  _buildDesktopTopBar(
                    context,
                    destinations: destinations,
                    selectedIndex: selectedIndex,
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTopBar(
    BuildContext context, {
    required List<AppShellDestination> destinations,
    required int selectedIndex,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    final currentTab = _locationTab(widget.location);
    final bookshelfSearchKeyword = ref.watch(
      desktopBookshelfSearchKeywordProvider,
    );
    final bookshelfToolbarActions =
        currentTab == AppShellTab.bookshelf
            ? ref.watch(desktopBookshelfToolbarActionsProvider)
            : null;
    final bookshelfLibraryActions =
        currentTab == AppShellTab.bookshelf
            ? ref.watch(desktopBookshelfLibraryActionsProvider)
            : null;
    if (_desktopBookshelfSearchController.text != bookshelfSearchKeyword) {
      _desktopBookshelfSearchController.value = TextEditingValue(
        text: bookshelfSearchKeyword,
        selection: TextSelection.collapsed(
          offset: bookshelfSearchKeyword.length,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.98),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.62),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        left: false,
        right: false,
        child: SizedBox(
          height: 74,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.pagePadding,
              12,
              metrics.pagePadding,
              12,
            ),
            child: Row(
              children: [
                if (currentTab == AppShellTab.bookshelf) ...[
                  _buildDesktopBookshelfViewSelector(
                    context,
                    actions: bookshelfLibraryActions,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDesktopTopBarBookshelfSearch(context)),
                ] else
                  const Expanded(child: SizedBox.shrink()),
                const SizedBox(width: 18),
                if (currentTab == AppShellTab.bookshelf) ...[
                  _buildDesktopBookshelfViewOptionsButton(
                    context,
                    actions: bookshelfToolbarActions,
                  ),
                  const SizedBox(width: 10),
                ],
                _buildDesktopTopBarNotificationButton(context),
                const SizedBox(width: 10),
                _buildDesktopTopBarThemeModeButton(context),
                const SizedBox(width: 10),
                _buildDesktopTopBarSettingsButton(context),
                const SizedBox(width: 14),
                _buildDesktopTopBarDivider(context),
                const SizedBox(width: 14),
                _buildDesktopTopBarAccountEntry(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopBookshelfViewSelector(
    BuildContext context, {
    required DesktopBookshelfLibraryActions? actions,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeLabel = actions?.activeLabel.trim();
    return MenuAnchor(
      menuChildren:
          actions == null
              ? const <Widget>[]
              : [
                for (final action in actions.statusActions)
                  MenuItemButton(
                    leadingIcon:
                        action.selected
                            ? const Icon(Icons.check_rounded)
                            : Icon(action.icon),
                    onPressed:
                        action.enabled && !action.selected
                            ? action.onSelected
                            : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(action.label),
                        const SizedBox(width: 16),
                        Text(
                          '${action.count}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
              ],
      builder: (menuContext, controller, child) {
        return Material(
          key: const ValueKey<String>('desktop_bookshelf_view_selector'),
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap:
                actions == null
                    ? null
                    : () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    },
            child: SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 116),
                      child: Text(
                        activeLabel == null || activeLabel.isEmpty
                            ? '全部'
                            : activeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopBookshelfViewOptionsButton(
    BuildContext context, {
    required DesktopBookshelfToolbarActions? actions,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return MenuAnchor(
      menuChildren:
          actions == null
              ? const <Widget>[]
              : [
                SubmenuButton(
                  leadingIcon: const Icon(Icons.sort_rounded),
                  menuChildren: [
                    if (actions.hasBooks)
                      for (final option in actions.sortOptions)
                        MenuItemButton(
                          leadingIcon:
                              option.selected
                                  ? const Icon(Icons.check_rounded)
                                  : const SizedBox(width: 24),
                          onPressed:
                              option.selected
                                  ? null
                                  : () =>
                                      actions.onSortModeSelected(option.mode),
                          child: Text(option.label),
                        )
                    else
                      const MenuItemButton(
                        onPressed: null,
                        child: Text('暂无书籍'),
                      ),
                  ],
                  child: const Text('排序方式'),
                ),
                SubmenuButton(
                  leadingIcon: const Icon(Icons.view_comfy_alt_rounded),
                  menuChildren: [
                    MenuItemButton(
                      leadingIcon:
                          actions.useGridView
                              ? const Icon(Icons.check_rounded)
                              : const SizedBox(width: 24),
                      onPressed:
                          actions.useGridView
                              ? null
                              : () => actions.onViewModeSelected(true),
                      child: const Text('网格'),
                    ),
                    MenuItemButton(
                      leadingIcon:
                          !actions.useGridView
                              ? const Icon(Icons.check_rounded)
                              : const SizedBox(width: 24),
                      onPressed:
                          !actions.useGridView
                              ? null
                              : () => actions.onViewModeSelected(false),
                      child: const Text('列表'),
                    ),
                  ],
                  child: const Text('显示模式'),
                ),
                const Divider(height: 1),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.checklist_rounded),
                  onPressed:
                      actions.hasFilteredBooks ? actions.onSelectBooks : null,
                  child: const Text('选择书籍'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.library_add_rounded),
                  onPressed: actions.onImportLocal,
                  child: const Text('导入图书'),
                ),
                SubmenuButton(
                  leadingIcon: const Icon(Icons.tune_rounded),
                  menuChildren: [
                    for (final option
                        in actions.useGridView
                            ? actions.gridSettingOptions
                            : actions.listSettingOptions)
                      MenuItemButton(
                        leadingIcon:
                            option.selected
                                ? const Icon(Icons.check_rounded)
                                : const SizedBox(width: 24),
                        onPressed:
                            option.modeGroup == null
                                ? () => option.onChanged(!option.selected)
                                : option.selected
                                ? null
                                : () => option.onChanged(true),
                        child: Text(option.label),
                      ),
                  ],
                  child: Text(actions.useGridView ? '网格设置' : '列表设置'),
                ),
              ],
      builder: (menuContext, controller, child) {
        return Tooltip(
          message: '视图选项',
          child: Material(
            key: const ValueKey<String>(
              'desktop_bookshelf_view_options_button',
            ),
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap:
                  actions == null
                      ? null
                      : () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      },
              child: SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  Icons.tune_rounded,
                  size: 21,
                  color:
                      actions == null
                          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.38)
                          : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTopBarBookshelfSearch(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: AdaptiveSearchBar(
          key: const ValueKey<String>('desktop_bookshelf_local_search'),
          controller: _desktopBookshelfSearchController,
          focusNode: _desktopBookshelfSearchFocusNode,
          hintText: '搜索当前书架',
          backgroundColor: colorScheme.surfaceContainerLow,
          outlineColor: colorScheme.outlineVariant,
          borderRadius: 999,
          onChanged:
              (value) =>
                  ref
                      .read(desktopBookshelfSearchKeywordProvider.notifier)
                      .state = value,
          onClear: () {
            _desktopBookshelfSearchController.clear();
            ref.read(desktopBookshelfSearchKeywordProvider.notifier).state = '';
          },
        ),
      ),
    );
  }

  Widget _buildDesktopTopBarNotificationButton(BuildContext context) {
    return _buildDesktopTopBarIconButton(
      context,
      key: const ValueKey<String>('desktop_top_bar_notification_button'),
      icon: Icons.notifications_none_outlined,
      tooltip: '通知',
      onTap: () {
        unawaited(context.push('/announcements'));
      },
      showBadge: true,
    );
  }

  Widget _buildDesktopTopBarThemeModeButton(BuildContext context) {
    ref.watch(appThemeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nextMode = isDark ? ThemeMode.light : ThemeMode.dark;
    return _buildDesktopTopBarIconButton(
      context,
      key: const ValueKey<String>('desktop_top_bar_theme_mode_toggle'),
      icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      tooltip: isDark ? '切换为日间' : '切换为夜间',
      onTap: () {
        unawaited(
          ref.read(appThemeModeProvider.notifier).setThemeMode(nextMode),
        );
      },
    );
  }

  Widget _buildDesktopTopBarSettingsButton(BuildContext context) {
    return _buildDesktopTopBarIconButton(
      context,
      key: const ValueKey<String>('desktop_top_bar_settings_button'),
      icon: Icons.settings_outlined,
      tooltip: '设置',
      onTap: () {
        unawaited(context.push('/system-settings'));
      },
    );
  }

  Widget _buildDesktopTopBarIconButton(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    bool showBadge = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor =
        onTap == null
            ? colorScheme.onSurfaceVariant.withValues(alpha: 0.38)
            : colorScheme.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: Material(
        key: key,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 21, color: iconColor),
                if (showBadge)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surfaceContainerLowest,
                          width: 1.5,
                        ),
                      ),
                      child: const SizedBox(width: 7, height: 7),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTopBarDivider(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 32,
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: colorScheme.outlineVariant.withValues(alpha: 0.86),
      ),
    );
  }

  Widget _buildDesktopTopBarAccountEntry(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final session = _topBarSession;
    final displayName = session?.displayIdentity ?? '登录';
    final avatarLabel = _topBarAvatarLabel(displayName);

    return Material(
      key: const ValueKey<String>('desktop_top_bar_account_entry'),
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          unawaited(context.push(session == null ? '/auth' : '/profile'));
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.surfaceContainerHigh,
                child:
                    avatarLabel == null
                        ? Icon(
                          Icons.person_outline,
                          size: 19,
                          color: colorScheme.onSurfaceVariant,
                        )
                        : Text(
                          avatarLabel,
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 112),
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _topBarAvatarLabel(String displayName) {
    final normalized = displayName.trim();
    if (normalized.isEmpty || normalized == '登录') {
      return null;
    }
    return normalized.characters.first.toUpperCase();
  }

  Widget _buildDesktopSidebar(
    BuildContext context, {
    required double width,
    required List<AppShellDestination> destinations,
    required int selectedIndex,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentTab = _locationTab(widget.location);
    final bookshelfLibraryActions =
        currentTab == AppShellTab.bookshelf
            ? ref.watch(desktopBookshelfLibraryActionsProvider)
            : null;
    return SizedBox(
      key: const ValueKey('desktop_shell_sidebar'),
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          border: Border(
            right: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.72),
            ),
          ),
        ),
        child: SafeArea(
          right: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 24, 12, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDesktopSidebarHeader(context),
                const SizedBox(height: 34),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (
                        var index = 0;
                        index < destinations.length;
                        index++
                      ) ...[
                        _buildDesktopNavItem(
                          context,
                          destination: destinations[index],
                          selected: index == selectedIndex,
                          onTap:
                              () => _goToDestination(
                                context,
                                destinations[index],
                              ),
                        ),
                        if (index != destinations.length - 1)
                          const SizedBox(height: 8),
                      ],
                      if (bookshelfLibraryActions != null) ...[
                        const SizedBox(height: 24),
                        _buildDesktopBookshelfLibrarySection(
                          context,
                          actions: bookshelfLibraryActions,
                        ),
                      ],
                    ],
                  ),
                ),
                _buildDesktopSidebarFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopBookshelfLibrarySection(
    BuildContext context, {
    required DesktopBookshelfLibraryActions actions,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(
            color: colorScheme.outlineVariant.withValues(alpha: 0.74),
            height: 1,
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '我的书架',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final action in actions.statusActions) ...[
            _buildDesktopBookshelfLibraryStatusItem(context, action: action),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopBookshelfLibraryStatusItem(
    BuildContext context, {
    required DesktopBookshelfLibraryStatusAction action,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = action.selected;
    final foreground =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final background =
        selected
            ? _desktopSelectedNavBackground(colorScheme)
            : Colors.transparent;
    final enabledForeground =
        action.enabled ? foreground : foreground.withValues(alpha: 0.38);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        onTap: action.enabled && !selected ? action.onSelected : null,
        child: SizedBox(
          height: 36,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(action.icon, size: 18, color: enabledForeground),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: enabledForeground,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${action.count}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        selected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.74,
                            ),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebarHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selune',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'CLEAR READING',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.74),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  IconData _desktopShellIconFor(
    AppShellDestination destination,
    bool selected,
  ) {
    if (destination.tab == AppShellTab.bookshelf) {
      return selected
          ? Icons.library_books_rounded
          : Icons.library_books_outlined;
    }
    return selected ? destination.selectedIcon : destination.icon;
  }

  double _desktopShellIconSizeFor(AppShellDestination destination) {
    return destination.tab == AppShellTab.bookshelf ? 21 : 22;
  }

  Color _desktopSelectedNavBackground(ColorScheme colorScheme) {
    return Color.alphaBlend(
      colorScheme.onSurface.withValues(alpha: 0.04),
      colorScheme.surfaceContainerLow,
    );
  }

  Color _desktopDividerColor(ColorScheme colorScheme) {
    return colorScheme.outline.withValues(alpha: 0.68);
  }

  Widget _desktopInkWell({
    required BorderRadius borderRadius,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return InkWell(
      borderRadius: borderRadius,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      onTap: onTap,
      child: child,
    );
  }

  Widget _buildDesktopNavItem(
    BuildContext context, {
    required AppShellDestination destination,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.primary;
    final foreground = selected ? activeColor : colorScheme.onSurfaceVariant;
    final selectedBackground = _desktopSelectedNavBackground(colorScheme);
    final icon = _desktopShellIconFor(destination, selected);

    return Material(
      color: Colors.transparent,
      child: _desktopInkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (selected)
                Positioned.fill(
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 7,
                      height: 42,
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                right: selected ? 3 : 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected ? selectedBackground : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 16),
                    Icon(
                      icon,
                      color: foreground,
                      size: _desktopShellIconSizeFor(destination),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebarFooter(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dividerColor = _desktopDividerColor(colorScheme);
    final session = _topBarSession;

    // 桌面端账号资料和设置统一放在顶部右侧，侧边栏底部只保留登录态退出入口，
    // 避免同一个账号信息在顶部栏和侧边栏重复出现，后续维护也更容易判断入口职责。
    if (session == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: dividerColor),
        const SizedBox(height: 14),
        Tooltip(
          message: '退出登录',
          child: _buildDesktopFooterLogoutButton(
            context,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopFooterLogoutButton(
    BuildContext context, {
    required ColorScheme colorScheme,
  }) {
    return Material(
      key: const ValueKey<String>('desktop_shell_logout_entry'),
      color: Colors.transparent,
      child: _desktopInkWell(
        borderRadius: BorderRadius.circular(12),
        onTap:
            _isShellLoggingOut
                ? () {}
                : () => unawaited(_handleShellLogout(context)),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              const SizedBox(width: 16),
              if (_isShellLoggingOut)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.logout_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '退出登录',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBottomNavigationBar(
    BuildContext context, {
    required List<AppShellDestination> destinations,
    required int selectedIndex,
    required AppNavigationStyle style,
    required bool showNavigationLabels,
    required BottomNavIconGallery? activeIconGallery,
    required AppStandardNavigationBarAppearance standardAppearance,
    required AppCupertinoDockAppearance cupertinoDockAppearance,
    required bool showSearchButton,
  }) {
    final brightness = Theme.of(context).brightness;
    final backdrop = resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      ref.read(activeAdvancedThemeProvider).valueOrNull,
    );
    final advancedPalette = resolveAdvancedThemePalette(
      Theme.of(context).colorScheme,
      ref.read(activeAdvancedThemeProvider).valueOrNull,
    );
    final componentTokens = appComponentThemeTokensOf(context);
    final hasWallpaper =
        backdrop.wallpaperPath != null && backdrop.wallpaperPath!.isNotEmpty;

    switch (style) {
      case AppNavigationStyle.standard:
        final floating = standardAppearance.floatingBar;
        final frosted = standardAppearance.frostedEffect;
        final borderColor = resolveAppBorderColor(
          Theme.of(context).colorScheme,
          baseColor: advancedPalette.cardBorderColor,
          containerColor: advancedPalette.cardColor,
        );
        final surfaceColor = _standardNavigationSurfaceColor(
          baseColor: advancedPalette.cardColor,
          hasWallpaper: hasWallpaper,
          floating: floating,
          frosted: frosted,
        );
        final radius =
            floating ? componentTokens.navigation.standardFloatingRadius : 0.0;
        final navigationBar = NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            indicatorColor: Colors.transparent,
            height:
                showNavigationLabels
                    ? componentTokens.navigation.standardHeightWithLabel
                    : componentTokens.navigation.standardHeightIconOnly,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        selected
                            ? advancedPalette.textPrimaryColor
                            : advancedPalette.textSecondaryColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ) ??
                  TextStyle(
                    color:
                        selected
                            ? advancedPalette.textPrimaryColor
                            : advancedPalette.textSecondaryColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  );
            }),
          ),
          child: IconTheme(
            data: IconThemeData(color: advancedPalette.textSecondaryColor),
            child: NavigationBar(
              height:
                  showNavigationLabels
                      ? componentTokens.navigation.standardHeightWithLabel
                      : componentTokens.navigation.standardHeightIconOnly,
              labelBehavior:
                  showNavigationLabels
                      ? NavigationDestinationLabelBehavior.alwaysShow
                      : NavigationDestinationLabelBehavior.alwaysHide,
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                _goToDestination(context, destinations[index]);
              },
              destinations: [
                for (final destination in destinations)
                  NavigationDestination(
                    icon: BottomNavIconView(
                      icon: resolveStandardBottomNavIcon(
                        destination: destination,
                        selected: false,
                        brightness: brightness,
                        gallery: activeIconGallery,
                      ),
                      size: 24,
                      fallbackColor: advancedPalette.textSecondaryColor,
                    ),
                    selectedIcon: BottomNavIconView(
                      icon: resolveStandardBottomNavIcon(
                        destination: destination,
                        selected: true,
                        brightness: brightness,
                        gallery: activeIconGallery,
                      ),
                      size: 24,
                      fallbackColor: advancedPalette.textPrimaryColor,
                    ),
                    label: destination.label,
                  ),
              ],
            ),
          ),
        );

        Widget surface = DecoratedBox(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius:
                floating ? BorderRadius.circular(radius) : BorderRadius.zero,
            border:
                floating
                    ? Border.all(
                      color: borderColor.withValues(alpha: 0.92),
                      width: componentTokens.navigation.standardBorderWidth,
                    )
                    : Border(
                      top: BorderSide(
                        color: borderColor,
                        width: componentTokens.navigation.standardBorderWidth,
                      ),
                    ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: floating ? 0.045 : 0.03),
                blurRadius:
                    floating
                        ? componentTokens.navigation.standardFloatingShadowBlur
                        : componentTokens.navigation.standardAttachedShadowBlur,
                offset: Offset(
                  0,
                  floating
                      ? componentTokens.navigation.standardFloatingShadowOffsetY
                      : componentTokens
                          .navigation
                          .standardAttachedShadowOffsetY,
                ),
              ),
            ],
          ),
          child: navigationBar,
        );

        if (frosted) {
          surface = ClipRRect(
            borderRadius:
                floating ? BorderRadius.circular(radius) : BorderRadius.zero,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX:
                    floating
                        ? componentTokens
                            .navigation
                            .standardFrostedBlurSigmaFloating
                        : componentTokens
                            .navigation
                            .standardFrostedBlurSigmaAttached,
                sigmaY:
                    floating
                        ? componentTokens
                            .navigation
                            .standardFrostedBlurSigmaFloating
                        : componentTokens
                            .navigation
                            .standardFrostedBlurSigmaAttached,
              ),
              child: surface,
            ),
          );
        }

        if (floating) {
          return SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: surface,
          );
        }

        return surface;
      case AppNavigationStyle.cupertinoDock:
        final dockFrosted = cupertinoDockAppearance.frostedEffect;
        return CupertinoDockNavigationBar(
          destinations: destinations,
          selectedIndex: selectedIndex,
          showLabels: showNavigationLabels,
          activeIconGallery: activeIconGallery,
          frostedEffect: dockFrosted,
          themePalette: DockThemePalette(
            containerColor:
                hasWallpaper
                    ? advancedPalette.cardColor.withValues(
                      alpha: dockFrosted ? 0.56 : 0.68,
                    )
                    : advancedPalette.cardColor.withValues(
                      alpha: dockFrosted ? 0.82 : 1.0,
                    ),
            borderColor: advancedPalette.cardBorderColor.withValues(
              alpha: 0.92,
            ),
            selectedIconColor: advancedPalette.textPrimaryColor,
            unselectedIconColor: advancedPalette.textSecondaryColor,
            selectedLabelColor: advancedPalette.textPrimaryColor,
            unselectedLabelColor: advancedPalette.textSecondaryColor,
          ),
          showSearchButton: showSearchButton,
          onDestinationSelected:
              (index) => _goToDestination(context, destinations[index]),
          onSearchPressed: (buttonContext) {
            unawaited(
              _openSearchWithReveal(buttonContext, route: '/search?entry=dock'),
            );
          },
        );
    }
  }

  Color _standardNavigationSurfaceColor({
    required Color baseColor,
    required bool hasWallpaper,
    required bool floating,
    required bool frosted,
  }) {
    final alpha = switch ((floating, frosted, hasWallpaper)) {
      (true, true, true) => 0.44,
      (true, true, false) => 0.76,
      (true, false, true) => 0.72,
      (true, false, false) => 0.96,
      (false, true, true) => 0.42,
      (false, true, false) => 0.8,
      (false, false, true) => 0.48,
      (false, false, false) => 0.92,
    };
    return baseColor.withValues(alpha: alpha);
  }

  void _onHorizontalDragEnd(
    BuildContext context, {
    required int currentIndex,
    required List<AppShellDestination> destinations,
    required DragEndDetails details,
  }) {
    if (destinations.length < 2) {
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < _kSwipeVelocityThreshold) {
      return;
    }

    if (velocity < 0) {
      final next = currentIndex + 1;
      if (next < destinations.length) {
        _goToDestination(context, destinations[next]);
      }
      return;
    }

    final previous = currentIndex - 1;
    if (previous >= 0) {
      _goToDestination(context, destinations[previous]);
    }
  }

  void _goToDestination(BuildContext context, AppShellDestination destination) {
    if (widget.location.startsWith(destination.location)) {
      return;
    }

    final navigationShell = widget.navigationShell;
    if (navigationShell != null) {
      navigationShell.goBranch(
        _tabOrderIndex(destination.tab),
        initialLocation: false,
      );
      return;
    }
    context.go(destination.location);
  }

  void _scheduleRedirectToVisibleTab(BuildContext context, String location) {
    if (_pendingRedirectLocation == location) {
      return;
    }

    _pendingRedirectLocation = location;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.location.startsWith(location)) {
        return;
      }
      context.go(location);
    });
  }

  int _locationOrderIndex(String currentLocation) {
    return _tabOrderIndex(_locationTab(currentLocation));
  }

  int _tabOrderIndex(AppShellTab tab) {
    return switch (tab) {
      AppShellTab.bookshelf => 0,
      AppShellTab.discover => 1,
      AppShellTab.stats => 2,
      AppShellTab.mine => 3,
      AppShellTab.home => 0,
    };
  }

  AppShellTab _locationTab(String currentLocation) {
    if (currentLocation.startsWith('/discover')) {
      return AppShellTab.discover;
    }
    if (currentLocation.startsWith('/stats') ||
        currentLocation.startsWith('/read-records')) {
      return AppShellTab.stats;
    }
    if (currentLocation.startsWith('/mine')) {
      return AppShellTab.mine;
    }
    return AppShellTab.bookshelf;
  }
}
