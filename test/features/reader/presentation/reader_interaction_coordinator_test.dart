import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_navigation_command_dispatcher.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_interaction_coordinator.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_touch_navigation_controller.dart';

void main() {
  group('ReaderInteractionCoordinator', () {
    const coordinator = ReaderInteractionCoordinator();

    test('maps touch intents before tap-zone fallback', () {
      expect(
        coordinator
            .resolveTouchIntent(const ReaderTouchNavigationIntent.ignore())
            .type,
        ReaderInteractionCommandType.ignore,
      );
      expect(
        coordinator
            .resolveTouchIntent(
              const ReaderTouchNavigationIntent.showAutoReadControl(),
            )
            .type,
        ReaderInteractionCommandType.showAutoReadControl,
      );
      expect(
        coordinator
            .resolveTouchIntent(
              const ReaderTouchNavigationIntent.openAutoReadOverlay(),
            )
            .type,
        ReaderInteractionCommandType.openAutoReadOverlay,
      );
      expect(
        coordinator
            .resolveTouchIntent(const ReaderTouchNavigationIntent.hideOverlay())
            .type,
        ReaderInteractionCommandType.hideOverlay,
      );
      expect(
        coordinator
            .resolveTouchIntent(
              const ReaderTouchNavigationIntent.resolveTapZone(),
            )
            .type,
        ReaderInteractionCommandType.ignore,
      );
    });

    test('maps tap-zone page actions to navigation commands', () {
      final previous = coordinator.resolveTapZoneAction(
        ReaderTapZoneAction.previousPage,
      );
      final next = coordinator.resolveTapZoneAction(
        ReaderTapZoneAction.nextPage,
      );

      expect(previous.type, ReaderInteractionCommandType.navigation);
      expect(
        previous.navigationCommand?.type,
        ReaderNavigationCommandType.previousPage,
      );
      expect(
        previous.navigationCommand?.source,
        ReaderNavigationCommandSource.tapZone,
      );
      expect(next.type, ReaderInteractionCommandType.navigation);
      expect(
        next.navigationCommand?.type,
        ReaderNavigationCommandType.nextPage,
      );
      expect(
        next.navigationCommand?.source,
        ReaderNavigationCommandSource.tapZone,
      );
    });

    test('maps tap-zone chrome actions without executing side effects', () {
      expect(
        coordinator.resolveTapZoneAction(null).type,
        ReaderInteractionCommandType.ignore,
      );
      expect(
        coordinator
            .resolveTapZoneAction(ReaderTapZoneAction.toggleToolbar)
            .type,
        ReaderInteractionCommandType.toggleToolbar,
      );
      expect(
        coordinator.resolveTapZoneAction(ReaderTapZoneAction.catalog).type,
        ReaderInteractionCommandType.openCatalog,
      );
      expect(
        coordinator.resolveTapZoneAction(ReaderTapZoneAction.autoRead).type,
        ReaderInteractionCommandType.openAutoRead,
      );
      expect(
        coordinator.resolveTapZoneAction(ReaderTapZoneAction.bookmark).type,
        ReaderInteractionCommandType.openBookmarkCatalog,
      );
      expect(
        coordinator.resolveTapZoneAction(ReaderTapZoneAction.nightMode).type,
        ReaderInteractionCommandType.toggleNightMode,
      );
    });

    test('tap-zone intent is normalized through the same command path', () {
      final command = coordinator.resolveTouchIntent(
        const ReaderTouchNavigationIntent.performTapZoneAction(
          ReaderTapZoneAction.nextPage,
        ),
      );

      expect(command.type, ReaderInteractionCommandType.navigation);
      expect(
        command.navigationCommand?.type,
        ReaderNavigationCommandType.nextPage,
      );
      expect(
        command.navigationCommand?.source,
        ReaderNavigationCommandSource.tapZone,
      );
    });
  });
}
