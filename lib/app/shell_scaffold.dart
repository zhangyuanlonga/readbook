import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'layout/app_layout.dart';
import 'shell_navigation_provider.dart';

class ShellScaffold extends ConsumerStatefulWidget {
  const ShellScaffold({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  ConsumerState<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<ShellScaffold> {
  static const double _kSwipeVelocityThreshold = 420;
  static const bool _kEnableMobileTabSwitchAnimation = false;

  late int _currentOrderIndex;
  bool _isForward = true;
  bool _hasTabSwitched = false;
  String? _pendingRedirectLocation;

  bool get _enableMobileTabSwipe {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    _currentOrderIndex = _locationOrderIndex(widget.location);
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
    _hasTabSwitched = true;
  }

  @override
  Widget build(BuildContext context) {
    final useNavigationRail = AppLayout.isMediumUp(context);
    final enableTabSwipe = _enableMobileTabSwipe && !useNavigationRail;
    final navigationState = ref.watch(appShellNavigationProvider);
    final visibleDestinations = visibleAppShellDestinations(navigationState);
    final currentTab = _locationTab(widget.location);
    final selectedIndex = visibleDestinations.indexWhere(
      (destination) => destination.tab == currentTab,
    );
    final effectiveSelectedIndex = selectedIndex >= 0 ? selectedIndex : 0;
    final canShowNavigation = visibleDestinations.length >= 2;

    if (selectedIndex < 0 && visibleDestinations.isNotEmpty) {
      _scheduleRedirectToVisibleTab(context, visibleDestinations.first.location);
    } else {
      _pendingRedirectLocation = null;
    }

    final shouldAnimateSwitch =
        enableTabSwipe && _hasTabSwitched && _kEnableMobileTabSwitchAnimation;

    final switchedChild =
        shouldAnimateSwitch
            ? AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final isIncoming = child.key == ValueKey<int>(_currentOrderIndex);
                final beginX =
                    isIncoming
                        ? (_isForward ? 0.16 : -0.16)
                        : (_isForward ? -0.1 : 0.1);
                final position = Tween<Offset>(
                  begin: Offset(beginX, 0),
                  end: Offset.zero,
                ).animate(animation);

                return ClipRect(
                  child: SlideTransition(
                    position: position,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_currentOrderIndex),
                child: widget.child,
              ),
            )
            : KeyedSubtree(
              key: ValueKey<int>(_currentOrderIndex),
              child: widget.child,
            );

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
              child: switchedChild,
            )
            : switchedChild;

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
                    (index) => _goToDestination(
                      context,
                      visibleDestinations[index],
                    ),
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
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: effectiveSelectedIndex,
        onDestinationSelected: (index) {
          _goToDestination(context, visibleDestinations[index]);
        },
        destinations: [
          for (final destination in visibleDestinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.label,
            ),
        ],
      ),
    );
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
      AppShellTab.source => 2,
      AppShellTab.mine => 3,
    };
  }

  AppShellTab _locationTab(String currentLocation) {
    if (currentLocation.startsWith('/discover')) {
      return AppShellTab.discover;
    }
    if (currentLocation.startsWith('/source')) {
      return AppShellTab.source;
    }
    if (currentLocation.startsWith('/mine')) {
      return AppShellTab.mine;
    }
    return AppShellTab.bookshelf;
  }
}
