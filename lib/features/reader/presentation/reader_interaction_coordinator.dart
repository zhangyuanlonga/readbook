import '../../../domain/entities/reader_settings.dart';
import '../application/reader_navigation_command_dispatcher.dart';
import 'reader_touch_navigation_controller.dart';

enum ReaderInteractionCommandType {
  ignore,
  showAutoReadControl,
  openAutoReadOverlay,
  hideOverlay,
  navigation,
  toggleToolbar,
  openCatalog,
  openAutoRead,
  openBookmarkCatalog,
  toggleNightMode,
}

class ReaderInteractionCommand {
  const ReaderInteractionCommand._(this.type, {this.navigationCommand});

  const ReaderInteractionCommand.ignore()
    : this._(ReaderInteractionCommandType.ignore);

  const ReaderInteractionCommand.showAutoReadControl()
    : this._(ReaderInteractionCommandType.showAutoReadControl);

  const ReaderInteractionCommand.openAutoReadOverlay()
    : this._(ReaderInteractionCommandType.openAutoReadOverlay);

  const ReaderInteractionCommand.hideOverlay()
    : this._(ReaderInteractionCommandType.hideOverlay);

  const ReaderInteractionCommand.navigation(
    ReaderNavigationCommand navigationCommand,
  ) : this._(
        ReaderInteractionCommandType.navigation,
        navigationCommand: navigationCommand,
      );

  const ReaderInteractionCommand.toggleToolbar()
    : this._(ReaderInteractionCommandType.toggleToolbar);

  const ReaderInteractionCommand.openCatalog()
    : this._(ReaderInteractionCommandType.openCatalog);

  const ReaderInteractionCommand.openAutoRead()
    : this._(ReaderInteractionCommandType.openAutoRead);

  const ReaderInteractionCommand.openBookmarkCatalog()
    : this._(ReaderInteractionCommandType.openBookmarkCatalog);

  const ReaderInteractionCommand.toggleNightMode()
    : this._(ReaderInteractionCommandType.toggleNightMode);

  final ReaderInteractionCommandType type;
  final ReaderNavigationCommand? navigationCommand;
}

class ReaderInteractionCoordinator {
  const ReaderInteractionCoordinator();

  ReaderInteractionCommand resolveTouchIntent(
    ReaderTouchNavigationIntent intent,
  ) {
    return switch (intent.type) {
      ReaderTouchNavigationIntentType.ignore ||
      ReaderTouchNavigationIntentType.resolveTapZone =>
        const ReaderInteractionCommand.ignore(),
      ReaderTouchNavigationIntentType.showAutoReadControl =>
        const ReaderInteractionCommand.showAutoReadControl(),
      ReaderTouchNavigationIntentType.openAutoReadOverlay =>
        const ReaderInteractionCommand.openAutoReadOverlay(),
      ReaderTouchNavigationIntentType.hideOverlay =>
        const ReaderInteractionCommand.hideOverlay(),
      ReaderTouchNavigationIntentType.performTapZoneAction =>
        resolveTapZoneAction(intent.tapZoneAction),
    };
  }

  ReaderInteractionCommand resolveTapZoneAction(ReaderTapZoneAction? action) {
    return switch (action) {
      null || ReaderTapZoneAction.none => const ReaderInteractionCommand.ignore(),
      ReaderTapZoneAction.previousPage =>
        const ReaderInteractionCommand.navigation(
          ReaderNavigationCommand.previousPage(
            source: ReaderNavigationCommandSource.tapZone,
          ),
        ),
      ReaderTapZoneAction.nextPage => const ReaderInteractionCommand.navigation(
        ReaderNavigationCommand.nextPage(
          source: ReaderNavigationCommandSource.tapZone,
        ),
      ),
      ReaderTapZoneAction.toggleToolbar =>
        const ReaderInteractionCommand.toggleToolbar(),
      ReaderTapZoneAction.catalog => const ReaderInteractionCommand.openCatalog(),
      ReaderTapZoneAction.autoRead =>
        const ReaderInteractionCommand.openAutoRead(),
      ReaderTapZoneAction.bookmark =>
        const ReaderInteractionCommand.openBookmarkCatalog(),
      ReaderTapZoneAction.nightMode =>
        const ReaderInteractionCommand.toggleNightMode(),
    };
  }
}
