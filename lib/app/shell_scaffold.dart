import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/entities/bottom_nav_icon_gallery.dart';
import '../features/mine/application/advanced_theme_provider.dart';
import 'theme/app_advanced_theme_tokens.dart';
import 'theme/app_border_tokens.dart';
import 'layout/app_layout.dart';
import 'navigation/bottom_nav_icon_gallery_provider.dart';
import 'navigation/bottom_nav_icon_resolver.dart';
import 'navigation/app_navigation_style_provider.dart';
import 'shell_navigation_provider.dart';
import 'widgets/bottom_nav_icon_view.dart';
import 'widgets/cupertino_dock_navigation_bar.dart';

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
  static const bool _kEnableMobileTabSwitchAnimation = false;
  static const Duration _kTabSwitchDuration = Duration(milliseconds: 320);

  late int _currentOrderIndex;
  bool _isForward = true;
  String? _pendingRedirectLocation;
  late final AnimationController _tabSwitchController;
  late final Animation<double> _tabSlideCurve;
  late final Animation<double> _tabFadeCurve;
  late final Animation<double> _tabScaleCurve;

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
    final useNavigationRail = AppLayout.isMediumUp(context);
    final enableTabSwipe =
        !kIsWeb && _isMobilePlatform(platform) && !useNavigationRail;
    final navigationStylePreference = ref.watch(
      appNavigationStylePreferenceProvider,
    );
    final showNavigationLabels = ref.watch(
      appNavigationLabelVisibilityProvider,
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
                final dx = (_isForward ? 28.0 : -28.0) * (1 - slideProgress);
                final opacity = lerpDouble(0.78, 1.0, fadeProgress)!;
                final scale = lerpDouble(0.985, 1.0, scaleProgress)!;
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

    final body =
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

    if (!canShowNavigation) {
      return Scaffold(body: body);
    }

    if (useNavigationRail) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                selectedIndex: effectiveSelectedIndex,
                onDestinationSelected:
                    (index) =>
                        _goToDestination(context, visibleDestinations[index]),
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final destination in visibleDestinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      label: Text(destination.label),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
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
      ),
    );
  }

  bool _isMobilePlatform(TargetPlatform platform) {
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  Widget _buildMobileBottomNavigationBar(
    BuildContext context, {
    required List<AppShellDestination> destinations,
    required int selectedIndex,
    required AppNavigationStyle style,
    required bool showNavigationLabels,
    required BottomNavIconGallery? activeIconGallery,
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
    final hasWallpaper =
        backdrop.wallpaperPath != null && backdrop.wallpaperPath!.isNotEmpty;

    switch (style) {
      case AppNavigationStyle.standard:
        return DecoratedBox(
          decoration: BoxDecoration(
            color:
                hasWallpaper
                    ? advancedPalette.cardColor.withValues(alpha: 0.48)
                    : advancedPalette.cardColor.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(
                color: resolveAppBorderColor(
                  Theme.of(context).colorScheme,
                  baseColor: advancedPalette.cardBorderColor,
                  containerColor: advancedPalette.cardColor,
                ),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              indicatorColor: Colors.transparent,
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
          ),
        );
      case AppNavigationStyle.cupertinoDock:
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: CupertinoDockNavigationBar(
              destinations: destinations,
              selectedIndex: selectedIndex,
              showLabels: showNavigationLabels,
              activeIconGallery: activeIconGallery,
              themePalette: DockThemePalette(
                containerColor:
                    hasWallpaper
                        ? advancedPalette.cardColor.withValues(alpha: 0.68)
                        : advancedPalette.cardColor,
                borderColor: advancedPalette.cardBorderColor.withValues(
                  alpha: 0.92,
                ),
                selectedIconColor: advancedPalette.textPrimaryColor,
                unselectedIconColor: advancedPalette.textSecondaryColor,
                selectedLabelColor: advancedPalette.textPrimaryColor,
                unselectedLabelColor: advancedPalette.textSecondaryColor,
              ),
              onDestinationSelected:
                  (index) => _goToDestination(context, destinations[index]),
              onSearchPressed: () {
                context.push('/search?entry=dock');
              },
            ),
          ),
        );
    }
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
