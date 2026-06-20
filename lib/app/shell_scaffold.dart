import 'dart:async';
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:circular_theme_reveal/circular_theme_reveal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_event_bus.dart';
import '../core/auth/auth_session.dart';
import '../core/auth/auth_service.dart';
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
import 'platform/desktop_window_chrome.dart';
import 'shell_page_toolbar_provider.dart';
import 'shell_navigation_provider.dart';
import 'widgets/adaptive_overflow_toolbar.dart';
import 'widgets/adaptive_bottom_sheet.dart';
import 'widgets/bottom_nav_icon_view.dart';
import 'widgets/cupertino_dock_navigation_bar.dart';
import 'widgets/app_task_queue_surface.dart';
import 'widgets/adaptive_search_bar.dart';
import 'widgets/foundation/foundation.dart';

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
  static const double _kDesktopSidebarNarrowWidth = 184;
  static const double _kDesktopSidebarRegularWidth = 216;
  static const double _kDesktopSidebarStandardWidth = 244;
  static const double _kDesktopSidebarWideWidth = 260;

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
    final session = await ref.read(authSessionStoreProvider).getSession();
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
    final confirmed = await showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 420,
      builder: (surfaceContext) {
        final colorScheme = Theme.of(surfaceContext).colorScheme;
        final textTheme = Theme.of(surfaceContext).textTheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.logout_rounded, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '退出登录',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('确定要退出当前账号吗？', style: textTheme.bodyMedium),
              const SizedBox(height: 20),
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
                    child: const Text('退出'),
                  ),
                ],
              ),
            ],
          ),
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
      AppFeedback.showSnackBar(
        context,
        message: '已退出登录。',
        tone: AppFeedbackTone.success,
      );
    } catch (_) {
      if (!mounted || !context.mounted) {
        return;
      }
      AppFeedback.showSnackBar(
        context,
        message: '退出失败，请稍后再试。',
        tone: AppFeedbackTone.error,
      );
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
    final sidebarWidth = _desktopSidebarWidthFor(width);

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
    final pageToolbarActions =
        currentTab == AppShellTab.bookshelf
            ? null
            : ref.watch(desktopShellPageToolbarActionsProvider);
    if (_desktopBookshelfSearchController.text != bookshelfSearchKeyword) {
      _desktopBookshelfSearchController.value = TextEditingValue(
        text: bookshelfSearchKeyword,
        selection: TextSelection.collapsed(
          offset: bookshelfSearchKeyword.length,
        ),
      );
    }

    return SizedBox(
      height: 74,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colorScheme.surface),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DesktopWindowDragArea(child: SizedBox.expand()),
            ),
            SafeArea(
              top: false,
              bottom: false,
              left: false,
              right: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  metrics.pagePadding,
                  12,
                  metrics.pagePadding,
                  12,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    final hasWindowControls =
                        DesktopWindowCaptionControls.isVisible(context);
                    final controlsWidth = hasWindowControls ? 138.0 : 0.0;
                    final contentWidth = availableWidth - controlsWidth;
                    final isNarrowTopBar =
                        contentWidth < AppLayout.expandedBreakpointWidth;
                    final hideBookshelfSearch = contentWidth < 640;
                    final showLowPriorityGlobalActions = contentWidth >= 760;
                    final showAccountName = contentWidth >= 820;
                    final middleSpacing = isNarrowTopBar ? 10.0 : 18.0;
                    final itemSpacing = isNarrowTopBar ? 6.0 : 10.0;

                    return Row(
                      children: [
                        if (currentTab == AppShellTab.bookshelf) ...[
                          _buildDesktopBookshelfViewSelector(
                            context,
                            actions: bookshelfLibraryActions,
                          ),
                          if (!hideBookshelfSearch) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDesktopTopBarBookshelfSearch(
                                context,
                              ),
                            ),
                          ] else
                            const Expanded(
                              child: DesktopWindowDragArea(
                                child: SizedBox.expand(),
                              ),
                            ),
                        ] else
                          Expanded(
                            child: _buildDesktopRegisteredPageToolbar(
                              context,
                              actions: pageToolbarActions,
                            ),
                          ),
                        SizedBox(width: middleSpacing),
                        if (currentTab == AppShellTab.bookshelf) ...[
                          _buildDesktopBookshelfViewOptionsButton(
                            context,
                            actions: bookshelfToolbarActions,
                          ),
                          SizedBox(width: itemSpacing),
                        ],
                        if (showLowPriorityGlobalActions) ...[
                          _buildDesktopTopBarNotificationButton(context),
                          SizedBox(width: itemSpacing),
                        ],
                        _buildDesktopTopBarThemeModeButton(context),
                        SizedBox(width: itemSpacing),
                        if (!showLowPriorityGlobalActions)
                          _buildDesktopTopBarGlobalMoreButton(context),
                        if (!isNarrowTopBar) ...[
                          const SizedBox(width: 14),
                          _buildDesktopTopBarDivider(context),
                        ],
                        SizedBox(width: isNarrowTopBar ? 8 : 14),
                        _buildDesktopTopBarAccountEntry(
                          context,
                          showName: showAccountName,
                        ),
                        if (hasWindowControls) ...[
                          SizedBox(width: itemSpacing),
                          const DesktopWindowCaptionControls(),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _desktopSidebarWidthFor(double width) {
    if (width >= AppLayout.wideDesktopBreakpointWidth) {
      return _kDesktopSidebarWideWidth;
    }
    if (width >= AppLayout.desktopBreakpointWidth) {
      return _kDesktopSidebarStandardWidth;
    }
    if (width >= AppLayout.expandedBreakpointWidth) {
      return _kDesktopSidebarRegularWidth;
    }
    return _kDesktopSidebarNarrowWidth;
  }

  Widget _buildDesktopRegisteredPageToolbar(
    BuildContext context, {
    required DesktopShellPageToolbarActions? actions,
  }) {
    final items = actions?.actions ?? const <DesktopShellPageToolbarAction>[];
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: AdaptiveOverflowToolbar(
          itemWidth: 44,
          spacing: 4,
          items: [
            for (final item in items)
              AdaptiveOverflowToolbarItem(
                icon: item.icon,
                label: item.label,
                tooltip: item.tooltip,
                priority: item.priority,
                enabled: item.enabled,
                onPressed: item.onPressed,
              ),
          ],
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
    final menuController = MenuController();
    return MenuAnchor(
      controller: menuController,
      alignmentOffset: const Offset(0, 10),
      animated: true,
      style: _desktopPopoverMenuStyle(colorScheme),
      menuChildren:
          actions == null
              ? const <Widget>[]
              : <Widget>[
                _DesktopBookshelfLibraryPicker(
                  actions: actions,
                  onClose: menuController.close,
                ),
              ],
      builder: (menuContext, controller, child) {
        return Material(
          key: const ValueKey<String>('desktop_bookshelf_view_selector'),
          color: colorScheme.surfaceContainerLowest,
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
                      constraints: const BoxConstraints(maxWidth: 160),
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
    final menuController = MenuController();
    return MenuAnchor(
      controller: menuController,
      alignmentOffset: const Offset(0, 10),
      animated: true,
      style: _desktopPopoverMenuStyle(
        colorScheme,
      ).copyWith(alignment: AlignmentDirectional.bottomEnd),
      menuChildren:
          actions == null
              ? const <Widget>[]
              : [
                _DesktopBookshelfToolbarOptionsPanel(
                  actions: actions,
                  onClose: menuController.close,
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
          backgroundColor: colorScheme.surfaceContainerLowest,
          outlineColor: colorScheme.primary.withValues(alpha: 0.46),
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

  Widget _buildDesktopTopBarGlobalMoreButton(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.notifications_none_outlined),
          onPressed: () {
            unawaited(context.push('/announcements'));
          },
          child: const Text('通知'),
        ),
      ],
      builder: (menuContext, controller, child) {
        return _buildDesktopTopBarIconButton(
          context,
          key: const ValueKey<String>('desktop_top_bar_global_more_button'),
          icon: Icons.more_horiz_rounded,
          tooltip: '更多',
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
        );
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
                          color: colorScheme.surface,
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
        color: colorScheme.outlineVariant.withValues(alpha: 0.28),
      ),
    );
  }

  MenuStyle _desktopPopoverMenuStyle(ColorScheme colorScheme) {
    return MenuStyle(
      backgroundColor: WidgetStatePropertyAll(
        colorScheme.surfaceContainerLowest,
      ),
      shadowColor: WidgetStatePropertyAll(
        colorScheme.shadow.withValues(alpha: 0.12),
      ),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(8),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      side: WidgetStatePropertyAll(
        BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.28)),
      ),
    );
  }

  Widget _buildDesktopTopBarAccountEntry(
    BuildContext context, {
    bool showName = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final session = _topBarSession;
    final displayName = session?.displayIdentity ?? '登录';
    final avatarLabel = _topBarAvatarLabel(displayName);

    return MenuAnchor(
      menuChildren: [
        if (session != null) ...[
          _buildDesktopAccountMenuHeader(
            context,
            displayName: displayName,
            avatarLabel: avatarLabel,
          ),
          const Divider(height: 1),
          MenuItemButton(
            key: const ValueKey<String>('desktop_account_menu_profile'),
            leadingIcon: const Icon(Icons.person_outline_rounded),
            onPressed: () {
              unawaited(context.push('/profile'));
            },
            child: const Text('个人信息'),
          ),
        ] else
          MenuItemButton(
            key: const ValueKey<String>('desktop_account_menu_login'),
            leadingIcon: const Icon(Icons.login_rounded),
            onPressed: () {
              unawaited(context.push('/auth'));
            },
            child: const Text('登录账号'),
          ),
        if (session != null) ...[
          const Divider(height: 1),
          MenuItemButton(
            key: const ValueKey<String>('desktop_account_menu_logout'),
            leadingIcon:
                _isShellLoggingOut
                    ? const AppProgressIndicator(
                      size: 18,
                      strokeWidth: 2,
                      semanticLabel: '退出登录中',
                    )
                    : Icon(Icons.logout_rounded, color: colorScheme.error),
            onPressed:
                _isShellLoggingOut
                    ? null
                    : () {
                      unawaited(_handleShellLogout(context));
                    },
            child: Text(
              '退出登录',
              style: textTheme.labelLarge?.copyWith(color: colorScheme.error),
            ),
          ),
        ],
      ],
      builder: (menuContext, controller, child) {
        return Material(
          key: const ValueKey<String>('desktop_top_bar_account_entry'),
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 3, 6, 3),
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
                  if (showName) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 88),
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
                  const SizedBox(width: 2),
                  Icon(
                    controller.isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopAccountMenuHeader(
    BuildContext context, {
    required String displayName,
    required String? avatarLabel,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final session = _topBarSession;
    final identity = session?.loginIdentity?.trim() ?? '';
    return SizedBox(
      key: const ValueKey<String>('desktop_account_menu_header'),
      width: 220,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colorScheme.surfaceContainerHigh,
              child:
                  avatarLabel == null
                      ? Icon(
                        Icons.person_outline,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      )
                      : Text(
                        avatarLabel,
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (identity.isNotEmpty)
                    Text(
                      identity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
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
          color: colorScheme.surface,
          border: Border(
            right: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.24),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          right: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              DesktopWindowChromeMetrics.sidebarTopPadding(context),
              12,
              20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DesktopWindowDragArea(
                  child: _buildDesktopSidebarHeader(context),
                ),
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
            color: colorScheme.outlineVariant.withValues(alpha: 0.26),
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
            '书享阅读',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.headlineMedium?.copyWith(
              color: colorScheme.onSurface,
              fontFamily: 'Georgia',
              fontFamilyFallback: const ['Times New Roman', 'serif'],
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
              height: 0.98,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'CLEAR READING',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.35,
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
    final tintAlpha = colorScheme.brightness == Brightness.dark ? 0.16 : 0.08;
    return Color.alphaBlend(
      colorScheme.primary.withValues(alpha: tintAlpha),
      colorScheme.surface,
    );
  }

  Color _desktopDividerColor(ColorScheme colorScheme) {
    return colorScheme.outlineVariant.withValues(alpha: 0.3);
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
                const AppProgressIndicator(
                  size: 22,
                  strokeWidth: 2,
                  semanticLabel: '退出登录中',
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
              // UI-GOV-EXEMPT: box-shadow tokenized-component
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

class _DesktopBookshelfToolbarOptionsPanel extends StatefulWidget {
  const _DesktopBookshelfToolbarOptionsPanel({
    required this.actions,
    required this.onClose,
  });

  final DesktopBookshelfToolbarActions actions;
  final VoidCallback onClose;

  @override
  State<_DesktopBookshelfToolbarOptionsPanel> createState() =>
      _DesktopBookshelfToolbarOptionsPanelState();
}

class _DesktopBookshelfToolbarOptionsPanelState
    extends State<_DesktopBookshelfToolbarOptionsPanel> {
  bool _sortExpanded = false;
  bool _settingsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final actions = widget.actions;
    final onClose = widget.onClose;
    final settings =
        actions.useGridView
            ? actions.gridSettingOptions
            : actions.listSettingOptions;
    final panelWidth =
        (MediaQuery.sizeOf(context).width - 48).clamp(320.0, 360.0).toDouble();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return SizedBox(
      key: const ValueKey<String>('desktop_bookshelf_view_options_panel'),
      width: panelWidth,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.62,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 17,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '视图选项',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '排序、布局和书架操作',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DesktopBookshelfCollapsibleOptionsSection(
                        title: '排序方式',
                        summary: _selectedSortLabel(actions),
                        expanded: _sortExpanded,
                        onToggle: () {
                          setState(() {
                            _sortExpanded = !_sortExpanded;
                          });
                        },
                        child:
                            actions.hasBooks
                                ? Column(
                                  children: [
                                    for (final option
                                        in actions.sortOptions) ...[
                                      _DesktopBookshelfSortOptionTile(
                                        option: option,
                                        onSelected:
                                            option.selected
                                                ? null
                                                : () {
                                                  onClose();
                                                  actions.onSortModeSelected(
                                                    option.mode,
                                                  );
                                                },
                                      ),
                                      if (option != actions.sortOptions.last)
                                        const SizedBox(height: 8),
                                    ],
                                  ],
                                )
                                : const _DesktopBookshelfPanelEmpty(
                                  label: '暂无书籍可排序',
                                ),
                      ),
                      _DesktopBookshelfOptionsSection(
                        title: '显示模式',
                        child: Row(
                          children: [
                            Expanded(
                              child: _DesktopBookshelfModeButton(
                                icon: Icons.view_list_rounded,
                                label: '列表',
                                selected:
                                    !actions.useGridView &&
                                    !actions.useListTwoColumnMode,
                                onTap:
                                    !actions.useGridView &&
                                            !actions.useListTwoColumnMode
                                        ? null
                                        : () {
                                          onClose();
                                          actions.onViewModeSelected(false);
                                        },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _DesktopBookshelfModeButton(
                                icon: Icons.view_week_rounded,
                                label: '双列',
                                selected:
                                    !actions.useGridView &&
                                    actions.useListTwoColumnMode,
                                onTap:
                                    !actions.useGridView &&
                                            actions.useListTwoColumnMode
                                        ? null
                                        : () {
                                          onClose();
                                          actions.onListTwoColumnModeSelected(
                                            true,
                                          );
                                        },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _DesktopBookshelfModeButton(
                                icon: Icons.grid_view_rounded,
                                label: '网格',
                                selected: actions.useGridView,
                                onTap:
                                    actions.useGridView
                                        ? null
                                        : () {
                                          onClose();
                                          actions.onViewModeSelected(true);
                                        },
                              ),
                            ),
                          ],
                        ),
                      ),
                      _DesktopBookshelfOptionsSection(
                        title: '书架操作',
                        child: Row(
                          children: [
                            Expanded(
                              child: _DesktopBookshelfCommandButton(
                                icon: Icons.checklist_rounded,
                                label: '选择书籍',
                                enabled: actions.hasFilteredBooks,
                                onTap: () {
                                  onClose();
                                  actions.onSelectBooks();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _DesktopBookshelfCommandButton(
                                icon: Icons.library_add_rounded,
                                label: '导入图书',
                                primary: true,
                                onTap: () {
                                  onClose();
                                  actions.onImportLocal();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      _DesktopBookshelfCollapsibleOptionsSection(
                        title: actions.useGridView ? '网格设置' : '列表设置',
                        summary: _settingsSummary(settings),
                        expanded: _settingsExpanded,
                        onToggle: () {
                          setState(() {
                            _settingsExpanded = !_settingsExpanded;
                          });
                        },
                        bottomPadding: 0,
                        child:
                            settings.isEmpty
                                ? const _DesktopBookshelfPanelEmpty(
                                  label: '暂无可用设置',
                                )
                                : Column(
                                  children: [
                                    for (final option in settings) ...[
                                      _DesktopBookshelfSettingOptionTile(
                                        option: option,
                                      ),
                                      if (option != settings.last)
                                        const SizedBox(height: 6),
                                    ],
                                  ],
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _selectedSortLabel(DesktopBookshelfToolbarActions actions) {
    if (!actions.hasBooks) {
      return '暂无书籍';
    }
    for (final option in actions.sortOptions) {
      if (option.selected) {
        return option.label;
      }
    }
    return '未选择';
  }

  String _settingsSummary(List<DesktopBookshelfDisplaySettingOption> settings) {
    if (settings.isEmpty) {
      return '暂无设置';
    }
    final enabledCount = settings.where((option) => option.selected).length;
    if (enabledCount == 0) {
      return '全部停用';
    }
    return '$enabledCount 项启用';
  }
}

class _DesktopBookshelfOptionsSection extends StatelessWidget {
  const _DesktopBookshelfOptionsSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _DesktopBookshelfCollapsibleOptionsSection extends StatelessWidget {
  const _DesktopBookshelfCollapsibleOptionsSection({
    required this.title,
    required this.summary,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.bottomPadding = 16,
  });

  final String title;
  final String summary;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderColor =
        expanded
            ? colorScheme.primary.withValues(alpha: 0.28)
            : colorScheme.outlineVariant.withValues(alpha: 0.28);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color:
                expanded
                    ? colorScheme.primaryContainer.withValues(alpha: 0.28)
                    : colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onToggle,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Row(
                    children: [
                      Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 20,
                        color:
                            expanded
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: expanded ? colorScheme.primary : null,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              summary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
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
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: child,
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 160),
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

class _DesktopBookshelfSortOptionTile extends StatelessWidget {
  const _DesktopBookshelfSortOptionTile({
    required this.option,
    required this.onSelected,
  });

  final DesktopBookshelfSortOption option;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = option.selected;
    final foreground =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final background =
        selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
            : colorScheme.surface;
    final borderColor =
        selected
            ? colorScheme.primary.withValues(alpha: 0.36)
            : colorScheme.outlineVariant.withValues(alpha: 0.34);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onSelected,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.sort_rounded,
                  size: 19,
                  color: foreground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: selected ? colorScheme.primary : null,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
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
  }
}

class _DesktopBookshelfModeButton extends StatelessWidget {
  const _DesktopBookshelfModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final background =
        selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.56)
            : colorScheme.surface;
    final borderColor =
        selected
            ? colorScheme.primary.withValues(alpha: 0.38)
            : colorScheme.outlineVariant.withValues(alpha: 0.34);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: SizedBox(
            height: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: foreground),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected ? colorScheme.primary : foreground,
                    fontWeight: FontWeight.w800,
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

class _DesktopBookshelfCommandButton extends StatelessWidget {
  const _DesktopBookshelfCommandButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground =
        primary ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final disabledForeground = colorScheme.onSurfaceVariant.withValues(
      alpha: 0.38,
    );
    final background =
        primary
            ? colorScheme.primaryContainer.withValues(alpha: 0.48)
            : colorScheme.surface;
    final borderColor =
        primary
            ? colorScheme.primary.withValues(alpha: 0.28)
            : colorScheme.outlineVariant.withValues(alpha: 0.34);

    return Material(
      color: enabled ? background : colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  enabled
                      ? borderColor
                      : colorScheme.outlineVariant.withValues(alpha: 0.22),
            ),
          ),
          child: SizedBox(
            height: 42,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: enabled ? foreground : disabledForeground,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: enabled ? foreground : disabledForeground,
                      fontWeight: FontWeight.w800,
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
}

class _DesktopBookshelfSettingOptionTile extends StatelessWidget {
  const _DesktopBookshelfSettingOptionTile({required this.option});

  final DesktopBookshelfDisplaySettingOption option;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = option.selected;
    final isModeOption = option.modeGroup != null;
    final foreground =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final statusLabel = selected ? '启用' : '停用';
    void handleChanged(bool value) {
      if (isModeOption) {
        if (value || !selected) {
          option.onChanged(true);
        }
        return;
      }
      option.onChanged(value);
    }

    return Material(
      color:
          selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.36)
              : colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => handleChanged(isModeOption ? true : !selected),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected
                      ? colorScheme.primary.withValues(alpha: 0.3)
                      : colorScheme.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          child: SizedBox(
            height: 42,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
              child: Row(
                children: [
                  Icon(
                    option.icon ??
                        (isModeOption
                            ? Icons.swap_horiz_rounded
                            : Icons.tune_rounded),
                    size: 18,
                    color: foreground,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: selected ? colorScheme.primary : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:
                          selected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Switch(
                    value: selected,
                    onChanged: handleChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    trackOutlineWidth: const WidgetStatePropertyAll<double>(0),
                    trackOutlineColor: const WidgetStatePropertyAll<Color>(
                      Colors.transparent,
                    ),
                    activeThumbColor: colorScheme.primary,
                    activeTrackColor: colorScheme.primary.withValues(
                      alpha: 0.22,
                    ),
                    inactiveThumbColor: colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.74,
                    ),
                    inactiveTrackColor: colorScheme.outlineVariant.withValues(
                      alpha: 0.34,
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
}

class _DesktopBookshelfPanelEmpty extends StatelessWidget {
  const _DesktopBookshelfPanelEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DesktopBookshelfLibraryPicker extends StatefulWidget {
  const _DesktopBookshelfLibraryPicker({
    required this.actions,
    required this.onClose,
  });

  final DesktopBookshelfLibraryActions actions;
  final VoidCallback onClose;

  @override
  State<_DesktopBookshelfLibraryPicker> createState() =>
      _DesktopBookshelfLibraryPickerState();
}

class _DesktopBookshelfLibraryPickerState
    extends State<_DesktopBookshelfLibraryPicker> {
  late final TextEditingController _searchController;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final groups =
        widget.actions.filterGroups.isNotEmpty
            ? widget.actions.filterGroups
            : <DesktopBookshelfLibraryFilterGroup>[
              DesktopBookshelfLibraryFilterGroup(
                title: '阅读状态',
                actions: [
                  for (final action in widget.actions.statusActions)
                    DesktopBookshelfLibraryFilterAction(
                      label: action.label,
                      count: action.count,
                      selected: action.selected,
                      icon: action.icon,
                      enabled: action.enabled,
                      onSelected: action.onSelected,
                    ),
                ],
              ),
            ];
    final maxHeight = MediaQuery.sizeOf(context).height * 0.68;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 460, maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.filter_alt_outlined,
                    size: 17,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '筛选书架',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '状态、分类和标签',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索分类或标签',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon:
                    _keyword.isEmpty
                        ? null
                        : IconButton(
                          tooltip: '清空',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _keyword = '';
                            });
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _keyword = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                primary: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final group in groups)
                      _DesktopBookshelfLibraryFilterSection(
                        group: group,
                        keyword: _keyword,
                        onSelected: (action) {
                          widget.onClose();
                          action.onSelected();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopBookshelfLibraryFilterSection extends StatelessWidget {
  const _DesktopBookshelfLibraryFilterSection({
    required this.group,
    required this.keyword,
    required this.onSelected,
  });

  final DesktopBookshelfLibraryFilterGroup group;
  final String keyword;
  final ValueChanged<DesktopBookshelfLibraryFilterAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final normalizedKeyword = keyword.trim().toLowerCase();
    final visibleActions =
        normalizedKeyword.isEmpty
            ? group.actions
            : group.actions
                .where(
                  (action) =>
                      action.label.toLowerCase().contains(normalizedKeyword),
                )
                .toList(growable: false);

    if (visibleActions.isEmpty && group.emptyLabel == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (visibleActions.isEmpty)
            Text(
              normalizedKeyword.isEmpty ? group.emptyLabel! : '没有匹配项',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final action in visibleActions)
                  _DesktopBookshelfLibraryFilterChip(
                    action: action,
                    onSelected: onSelected,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DesktopBookshelfLibraryFilterChip extends StatelessWidget {
  const _DesktopBookshelfLibraryFilterChip({
    required this.action,
    required this.onSelected,
  });

  final DesktopBookshelfLibraryFilterAction action;
  final ValueChanged<DesktopBookshelfLibraryFilterAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = action.accentColor ?? colorScheme.primary;
    final selected = action.selected;
    return FilterChip(
      selected: selected,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        selected ? Icons.check_rounded : action.icon,
        size: 16,
        color: selected ? accentColor : colorScheme.onSurfaceVariant,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 132),
            child: Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${action.count}',
            style: theme.textTheme.labelSmall?.copyWith(
              color:
                  selected
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      selectedColor: accentColor.withValues(alpha: 0.16),
      checkmarkColor: accentColor,
      side: BorderSide(
        color:
            selected
                ? accentColor.withValues(alpha: 0.72)
                : colorScheme.outlineVariant.withValues(alpha: 0.38),
      ),
      onSelected:
          action.enabled && !selected ? (_) => onSelected(action) : null,
    );
  }
}
