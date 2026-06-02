import 'dart:async';
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:circular_theme_reveal/circular_theme_reveal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/entities/bottom_nav_icon_gallery.dart';
import '../features/mine/application/advanced_theme_provider.dart';
import 'layout/app_adaptive.dart';
import 'theme/app_advanced_theme_tokens.dart';
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
    _tabSwitchController.dispose();
    super.dispose();
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
        width >= AppLayout.expandedBreakpointWidth ? 280.0 : 240.0;

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
    final contentMaxWidth = _desktopTopBarContentMaxWidthForTab(currentTab);

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
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  metrics.pagePadding,
                  12,
                  metrics.pagePadding,
                  12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child:
                          currentTab == AppShellTab.bookshelf
                              ? _buildDesktopTopBarSearchTrigger(context)
                              : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 18),
                    _buildDesktopTopBarNotificationButton(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _desktopTopBarContentMaxWidthForTab(AppShellTab tab) {
    return switch (tab) {
      AppShellTab.home => 980,
      AppShellTab.bookshelf => AppLayout.bookshelfContentMaxWidth,
      AppShellTab.discover => AppLayout.discoverExpandedContentMaxWidth,
      AppShellTab.stats => 1120,
      AppShellTab.mine => AppLayout.mineContentMaxWidth,
    };
  }

  Widget _buildDesktopTopBarNotificationButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          unawaited(context.push('/announcements'));
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.78),
            ),
          ),
          child: Icon(
            Icons.notifications_none_outlined,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTopBarSearchTrigger(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Material(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap:
                () => unawaited(
                  _openSearchWithReveal(
                    context,
                    route: '/search?entry=bookshelf_top',
                  ),
                ),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.72),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '搜索书架中的书名、作者或备注...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
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

  Widget _buildDesktopSidebar(
    BuildContext context, {
    required double width,
    required List<AppShellDestination> destinations,
    required int selectedIndex,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
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
            padding: const EdgeInsets.fromLTRB(14, 24, 14, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDesktopSidebarHeader(context),
                const SizedBox(height: 34),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final destination = destinations[index];
                      return _buildDesktopNavItem(
                        context,
                        destination: destination,
                        selected: index == selectedIndex,
                        onTap: () => _goToDestination(context, destination),
                      );
                    },
                    separatorBuilder:
                        (context, index) => const SizedBox(height: 8),
                    itemCount: destinations.length,
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

  Widget _buildDesktopSidebarHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
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

  Color _desktopUserCardBackground(ColorScheme colorScheme) {
    return Color.alphaBlend(
      colorScheme.onSurface.withValues(alpha: 0.04),
      colorScheme.surfaceContainerLow,
    );
  }

  Color _desktopAvatarBackground(ColorScheme colorScheme) {
    return Color.alphaBlend(
      colorScheme.onSurface.withValues(alpha: 0.02),
      colorScheme.surfaceContainerLowest,
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
                    const SizedBox(width: 18),
                    Icon(
                      icon,
                      color: foreground,
                      size: _desktopShellIconSizeFor(destination),
                    ),
                    const SizedBox(width: 18),
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
    final textTheme = Theme.of(context).textTheme;
    final dividerColor = _desktopDividerColor(colorScheme);
    final userCardColor = _desktopUserCardBackground(colorScheme);
    final avatarColor = _desktopAvatarBackground(colorScheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: dividerColor),
        const SizedBox(height: 28),
        _buildDesktopFooterAction(
          context,
          icon: Icons.settings_outlined,
          label: '设置',
          onTap: () {
            unawaited(context.push('/system-settings'));
          },
        ),
        const SizedBox(height: 14),
        Material(
          color: Colors.transparent,
          child: _desktopInkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              unawaited(context.push('/profile'));
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 68),
              padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
              decoration: BoxDecoration(
                color: userCardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: avatarColor,
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 22,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.52,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '林静深',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '已读 124 本',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.logout_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopFooterAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          _desktopInkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 18),
                  Icon(icon, color: colorScheme.onSurfaceVariant, size: 22),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      label,
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
        ],
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
      AppShellTab.home => 0,
      AppShellTab.bookshelf => 1,
      AppShellTab.discover => 2,
      AppShellTab.stats => 3,
      AppShellTab.mine => 4,
    };
  }

  AppShellTab _locationTab(String currentLocation) {
    if (currentLocation.startsWith('/home')) {
      return AppShellTab.home;
    }
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
