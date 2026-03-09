import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppShellTab { bookshelf, discover, source, mine }

class AppShellDestination {
  const AppShellDestination({
    required this.tab,
    required this.location,
    required this.label,
    required this.icon,
  });

  final AppShellTab tab;
  final String location;
  final String label;
  final IconData icon;
}

const List<AppShellDestination> appShellDestinations = [
  AppShellDestination(
    tab: AppShellTab.bookshelf,
    location: '/bookshelf',
    label: '书架',
    icon: Icons.bookmarks_outlined,
  ),
  AppShellDestination(
    tab: AppShellTab.discover,
    location: '/discover',
    label: '发现',
    icon: Icons.travel_explore_outlined,
  ),
  AppShellDestination(
    tab: AppShellTab.source,
    location: '/source',
    label: '书源',
    icon: Icons.storage_outlined,
  ),
  AppShellDestination(
    tab: AppShellTab.mine,
    location: '/mine',
    label: '我的',
    icon: Icons.person_outline,
  ),
];

class AppShellNavigationState {
  const AppShellNavigationState({
    this.showBookshelf = true,
    this.showDiscover = true,
    this.showSource = true,
  });

  final bool showBookshelf;
  final bool showDiscover;
  final bool showSource;

  int get configurableVisibleCount {
    var count = 0;
    if (showBookshelf) {
      count += 1;
    }
    if (showDiscover) {
      count += 1;
    }
    if (showSource) {
      count += 1;
    }
    return count;
  }

  bool isTabVisible(AppShellTab tab) {
    return switch (tab) {
      AppShellTab.bookshelf => showBookshelf,
      AppShellTab.discover => showDiscover,
      AppShellTab.source => showSource,
      AppShellTab.mine => true,
    };
  }

  int get visibleTabCount {
    return configurableVisibleCount + 1;
  }

  AppShellNavigationState copyWith({
    bool? showBookshelf,
    bool? showDiscover,
    bool? showSource,
  }) {
    return AppShellNavigationState(
      showBookshelf: showBookshelf ?? this.showBookshelf,
      showDiscover: showDiscover ?? this.showDiscover,
      showSource: showSource ?? this.showSource,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppShellNavigationState &&
        other.showBookshelf == showBookshelf &&
        other.showDiscover == showDiscover &&
        other.showSource == showSource;
  }

  @override
  int get hashCode => Object.hash(showBookshelf, showDiscover, showSource);
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
  static const String _bookshelfVisibleKey = 'app.shell.navigation.bookshelf';
  static const String _discoverVisibleKey = 'app.shell.navigation.discover';
  static const String _sourceVisibleKey = 'app.shell.navigation.source';

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
    final prefs = await SharedPreferences.getInstance();
    final loaded = AppShellNavigationState(
      showBookshelf: prefs.getBool(_bookshelfVisibleKey) ?? true,
      showDiscover: prefs.getBool(_discoverVisibleKey) ?? true,
      showSource: prefs.getBool(_sourceVisibleKey) ?? true,
    );
    final normalized = _normalizeState(loaded);

    if (_hasExplicitSet) {
      return;
    }

    if (normalized != state) {
      state = normalized;
    }

    if (normalized != loaded) {
      await _persistState(prefs, normalized);
    }
  }

  Future<void> setTabVisible(AppShellTab tab, bool visible) async {
    if (tab == AppShellTab.mine) {
      return;
    }

    final previous = state;
    final changed = switch (tab) {
      AppShellTab.bookshelf => state.copyWith(showBookshelf: visible),
      AppShellTab.discover => state.copyWith(showDiscover: visible),
      AppShellTab.source => state.copyWith(showSource: visible),
      AppShellTab.mine => state,
    };
    final next = _normalizeState(changed);

    if (next == state) {
      return;
    }

    _hasExplicitSet = true;
    state = next;

    try {
      final prefs = await SharedPreferences.getInstance();
      await _persistState(prefs, next);
    } catch (_) {
      if (state != previous) {
        state = previous;
      }
      rethrow;
    }
  }

  AppShellNavigationState _normalizeState(AppShellNavigationState input) {
    if (input.configurableVisibleCount > 0) {
      return input;
    }
    return input.copyWith(showBookshelf: true);
  }

  Future<void> _persistState(
    SharedPreferences prefs,
    AppShellNavigationState state,
  ) async {
    await prefs.setBool(_bookshelfVisibleKey, state.showBookshelf);
    await prefs.setBool(_discoverVisibleKey, state.showDiscover);
    await prefs.setBool(_sourceVisibleKey, state.showSource);
  }
}
