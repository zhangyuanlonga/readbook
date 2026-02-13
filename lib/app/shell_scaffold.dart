import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/bookshelf');
              break;
            case 1:
              context.go('/source');
              break;
            case 2:
              context.go('/mine');
              break;
          }
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
