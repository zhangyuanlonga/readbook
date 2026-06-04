import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'preferences/app_shell_navigation_snapshot.dart';
import 'preferences/app_preferences_service.dart';

part 'shell_navigation_provider.freezed.dart';

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
    tab: AppShellTab.bookshelf,
    location: '/bookshelf',
    label: '书架',
    icon: Icons.library_books_outlined,
    selectedIcon: Icons.library_books_rounded,
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

@freezed
abstract class AppShellNavigationState with _$AppShellNavigationState {
  const AppShellNavigationState._();

  const factory AppShellNavigationState({
    @Default(true) bool showHome,
    @Default(true) bool showBookshelf,
    @Default(true) bool showDiscover,
    @Default(true) bool showStats,
  }) = _AppShellNavigationState;

  int get configurableVisibleCount {
    var count = 0;
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
      AppShellTab.home => false,
      AppShellTab.bookshelf => showBookshelf,
      AppShellTab.discover => showDiscover,
      AppShellTab.stats => showStats,
      AppShellTab.mine => true,
    };
  }

  int get visibleTabCount {
    return configurableVisibleCount + 1;
  }
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
  bool _disposed = false;

  @override
  AppShellNavigationState build() {
    ref.onDispose(() {
      _disposed = true;
    });
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
    if (_disposed) {
      return;
    }
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
    if (tab == AppShellTab.home ||
        tab == AppShellTab.mine ||
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
    // 首页已经从主导航和路由中移除。这里统一压掉旧偏好里的 showHome，
    // 防止历史配置在后续保存时又把首页入口带回外观设置或导航状态里。
    var normalized = input.copyWith(showHome: false);
    if (!_isDiscoverEnabled && normalized.showDiscover) {
      normalized = normalized.copyWith(showDiscover: false);
    }
    if (normalized.configurableVisibleCount > 0) {
      return normalized;
    }
    return normalized.copyWith(showBookshelf: true);
  }

  bool get _isDiscoverEnabled {
    return true;
  }

  Future<void> _persistState(AppShellNavigationState state) async {
    if (_disposed) {
      return;
    }
    await ref
        .read(appShellNavigationPreferencesServiceProvider)
        .saveShellNavigation(
          AppShellNavigationSnapshot(
            showHome: false,
            showBookshelf: state.showBookshelf,
            showDiscover: state.showDiscover,
            showStats: state.showStats,
          ),
        );
  }
}
