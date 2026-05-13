import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'composition/app_providers.dart';
import 'preferences/app_preferences_service.dart';

enum AppShellTab { home, bookshelf, discover, stats, mine }

class AppShellDestination {
  const AppShellDestination({
    required this.tab,
    required this.location,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final AppShellTab tab;
  final String location;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const List<AppShellDestination> appShellDestinations = [
  AppShellDestination(
    tab: AppShellTab.home,
    location: '/home',
    label: '首页',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  AppShellDestination(
    tab: AppShellTab.bookshelf,
    location: '/bookshelf',
    label: '书架',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book_rounded,
  ),
  AppShellDestination(
    tab: AppShellTab.discover,
    location: '/discover',
    label: '发现',
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore,
  ),
  AppShellDestination(
    tab: AppShellTab.stats,
    location: '/stats',
    label: '统计',
    icon: Icons.insert_chart_outlined_rounded,
    selectedIcon: Icons.insert_chart_rounded,
  ),
  AppShellDestination(
    tab: AppShellTab.mine,
    location: '/mine',
    label: '我的',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  ),
];

class AppShellNavigationState {
  const AppShellNavigationState({
    this.showHome = true,
    this.showBookshelf = true,
    this.showDiscover = false,
    this.showStats = true,
  });

  final bool showHome;
  final bool showBookshelf;
  final bool showDiscover;
  final bool showStats;

  int get configurableVisibleCount {
    var count = 0;
    if (showHome) {
      count += 1;
    }
    if (showBookshelf) {
      count += 1;
    }
    if (showDiscover) {
      count += 1;
    }
    if (showStats) {
      count += 1;
    }
    return count;
  }

  bool isTabVisible(AppShellTab tab) {
    return switch (tab) {
      AppShellTab.home => showHome,
      AppShellTab.bookshelf => showBookshelf,
      AppShellTab.discover => showDiscover,
      AppShellTab.stats => showStats,
      AppShellTab.mine => true,
    };
  }

  int get visibleTabCount {
    return configurableVisibleCount + 1;
  }

  AppShellNavigationState copyWith({
    bool? showHome,
    bool? showBookshelf,
    bool? showDiscover,
    bool? showStats,
  }) {
    return AppShellNavigationState(
      showHome: showHome ?? this.showHome,
      showBookshelf: showBookshelf ?? this.showBookshelf,
      showDiscover: showDiscover ?? this.showDiscover,
      showStats: showStats ?? this.showStats,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppShellNavigationState &&
        other.showHome == showHome &&
        other.showBookshelf == showBookshelf &&
        other.showDiscover == showDiscover &&
        other.showStats == showStats;
  }

  @override
  int get hashCode =>
      Object.hash(showHome, showBookshelf, showDiscover, showStats);
}

List<AppShellDestination> visibleAppShellDestinations(
  AppShellNavigationState state,
) {
  return appShellDestinations
      .where((destination) => state.isTabVisible(destination.tab))
      .toList(growable: false);
}

final appShellNavigationProvider =
    NotifierProvider<AppShellNavigationNotifier, AppShellNavigationState>(
      AppShellNavigationNotifier.new,
    );

class AppShellNavigationNotifier extends Notifier<AppShellNavigationState> {
  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  @override
  AppShellNavigationState build() {
    if (!_loadTriggered) {
      _loadTriggered = true;
      _load();
    }

    return const AppShellNavigationState();
  }

  Future<void> _load() async {
    final snapshot =
        await ref
            .read(appShellNavigationPreferencesServiceProvider)
            .loadShellNavigation();
    final loaded = AppShellNavigationState(
      showHome: snapshot.showHome,
      showBookshelf: snapshot.showBookshelf,
      showDiscover: snapshot.showDiscover,
      showStats: snapshot.showStats,
    );
    final normalized = _normalizeState(loaded);

    if (_hasExplicitSet) {
      return;
    }

    if (normalized != state) {
      state = normalized;
    }

    if (normalized != loaded) {
      await _persistState(normalized);
    }
  }

  Future<void> setTabVisible(AppShellTab tab, bool visible) async {
    if (tab == AppShellTab.mine ||
        (tab == AppShellTab.discover && !_isDiscoverEnabled)) {
      return;
    }

    final previous = state;
    final changed = switch (tab) {
      AppShellTab.home => state.copyWith(showHome: visible),
      AppShellTab.bookshelf => state.copyWith(showBookshelf: visible),
      AppShellTab.discover => state.copyWith(showDiscover: visible),
      AppShellTab.stats => state.copyWith(showStats: visible),
      AppShellTab.mine => state,
    };
    final next = _normalizeState(changed);

    if (next == state) {
      await _persistState(next);
      return;
    }

    _hasExplicitSet = true;
    state = next;

    try {
      await _persistState(next);
    } catch (_) {
      if (state != previous) {
        state = previous;
      }
      rethrow;
    }
  }

  AppShellNavigationState _normalizeState(AppShellNavigationState input) {
    var normalized = input;
    if (!_isDiscoverEnabled && normalized.showDiscover) {
      normalized = normalized.copyWith(showDiscover: false);
    }
    if (normalized.configurableVisibleCount > 0) {
      return normalized;
    }
    return normalized.copyWith(showHome: true);
  }

  bool get _isDiscoverEnabled {
    return ref.read(appCapabilitiesProvider).sourceRuntime.canShowEntry;
  }

  Future<void> _persistState(AppShellNavigationState state) async {
    await ref
        .read(appShellNavigationPreferencesServiceProvider)
        .saveShellNavigation(
          AppShellNavigationSnapshot(
            showHome: state.showHome,
            showBookshelf: state.showBookshelf,
            showDiscover: state.showDiscover,
            showStats: state.showStats,
          ),
        );
  }
}
