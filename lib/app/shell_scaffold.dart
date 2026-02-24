import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellScaffold extends StatefulWidget {
  const ShellScaffold({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<ShellScaffold> {
  static const double _kSwipeVelocityThreshold = 420;
  static const bool _kEnableMobileTabSwitchAnimation = false;

  late int _currentIndex;
  bool _isForward = true;
  bool _hasTabSwitched = false;

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
    _currentIndex = _locationIndex(widget.location);
  }

  @override
  void didUpdateWidget(covariant ShellScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextIndex = _locationIndex(widget.location);
    if (nextIndex == _currentIndex) {
      return;
    }

    _isForward = nextIndex > _currentIndex;
    _currentIndex = nextIndex;
    _hasTabSwitched = true;
  }

  @override
  Widget build(BuildContext context) {
    final shouldAnimateSwitch =
        _enableMobileTabSwipe &&
        _hasTabSwitched &&
        _kEnableMobileTabSwitchAnimation;

    final switchedChild =
        shouldAnimateSwitch
            ? AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final isIncoming = child.key == ValueKey<int>(_currentIndex);
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
                key: ValueKey<int>(_currentIndex),
                child: widget.child,
              ),
            )
            : KeyedSubtree(
              key: ValueKey<int>(_currentIndex),
              child: widget.child,
            );

    final body =
        _enableMobileTabSwipe
            ? GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd:
                  (details) => _onHorizontalDragEnd(
                    context,
                    currentIndex: _currentIndex,
                    details: details,
                  ),
              child: switchedChild,
            )
            : switchedChild;

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          _goToIndex(context, index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bookmarks_outlined),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(Icons.storage_outlined),
            label: '书源',
          ),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '我的'),
        ],
      ),
    );
  }

  void _onHorizontalDragEnd(
    BuildContext context, {
    required int currentIndex,
    required DragEndDetails details,
  }) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < _kSwipeVelocityThreshold) {
      return;
    }

    if (velocity < 0) {
      final next = currentIndex + 1;
      if (next <= 2) {
        _goToIndex(context, next);
      }
      return;
    }

    final previous = currentIndex - 1;
    if (previous >= 0) {
      _goToIndex(context, previous);
    }
  }

  void _goToIndex(BuildContext context, int index) {
    if (index == _currentIndex) {
      return;
    }

    switch (index) {
      case 0:
        context.go('/bookshelf');
        return;
      case 1:
        context.go('/source');
        return;
      case 2:
        context.go('/mine');
        return;
    }
  }

  int _locationIndex(String currentLocation) {
    if (currentLocation.startsWith('/source')) {
      return 1;
    }
    if (currentLocation.startsWith('/mine')) {
      return 2;
    }
    return 0;
  }
}
