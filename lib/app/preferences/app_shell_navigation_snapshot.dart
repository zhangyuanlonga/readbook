import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_shell_navigation_snapshot.freezed.dart';

@freezed
abstract class AppShellNavigationSnapshot with _$AppShellNavigationSnapshot {
  const factory AppShellNavigationSnapshot({
    required bool showBookshelf,
    required bool showDiscover,
    required bool showStats,
  }) = _AppShellNavigationSnapshot;
}
