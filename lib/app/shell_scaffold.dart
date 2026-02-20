import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const double _kSwipeVelocityThreshold = 420;

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(location);

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd:
            (details) => _onHorizontalDragEnd(
              context,
              currentIndex: currentIndex,
              details: details,
            ),
        child: child,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
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

  int _currentIndex(String currentLocation) {
    if (currentLocation.startsWith('/source')) {
      return 1;
    }
    if (currentLocation.startsWith('/mine')) {
      return 2;
    }
    return 0;
  }
}
