import '../../../core/logging/app_logger.dart';
import 'remote_content_task_scheduler_service.dart';

enum RemoteContentConflictScene {
  bookshelfBackground,
  detail,
  reader,
  discover,
  search,
  sourceCheck,
}

class RemoteContentTaskConflictService {
  RemoteContentTaskConflictService({AppLogger? logger})
    : _scheduler = RemoteContentTaskSchedulerService(logger: logger);

  static final RemoteContentTaskConflictService instance =
      RemoteContentTaskConflictService();

  final RemoteContentTaskSchedulerService _scheduler;

  String conflictKeyForSource(String sourceId) {
    return _scheduler.conflictKeyForSource(sourceId);
  }

  String conflictKeyForBook({
    required String sourceId,
    required String detailUrl,
    required String bookId,
  }) {
    return _scheduler.conflictKeyForBook(
      sourceId: sourceId,
      detailUrl: detailUrl,
      bookId: bookId,
    );
  }

  int captureBackgroundEpoch(String conflictKey) {
    return _scheduler.captureBackgroundEpoch(conflictKey);
  }

  bool hasBackgroundConflictAdvanced({
    required String conflictKey,
    required int capturedEpoch,
  }) {
    return _scheduler.hasBackgroundConflictAdvanced(
      conflictKey: conflictKey,
      capturedEpoch: capturedEpoch,
    );
  }

  void cancelBackgroundWorkFor({
    required String conflictKey,
    required RemoteContentConflictScene byScene,
  }) {
    _scheduler.cancelLowerPriorityWorkFor(
      conflictKey: conflictKey,
      byScene: _toSchedulerScene(byScene),
    );
  }

  void clearAll() {
    _scheduler.clearAll();
  }

  RemoteContentTaskScene _toSchedulerScene(RemoteContentConflictScene scene) {
    return switch (scene) {
      RemoteContentConflictScene.bookshelfBackground =>
        RemoteContentTaskScene.bookshelfBackground,
      RemoteContentConflictScene.detail => RemoteContentTaskScene.detail,
      RemoteContentConflictScene.reader => RemoteContentTaskScene.reader,
      RemoteContentConflictScene.discover => RemoteContentTaskScene.discover,
      RemoteContentConflictScene.search => RemoteContentTaskScene.search,
      RemoteContentConflictScene.sourceCheck =>
        RemoteContentTaskScene.sourceCheck,
    };
  }
}
