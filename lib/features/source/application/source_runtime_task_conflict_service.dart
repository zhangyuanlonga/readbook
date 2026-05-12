import '../../../core/logging/app_logger.dart';
import 'source_runtime_scheduler_service.dart';

enum SourceRuntimeConflictScene {
  bookshelfBackground,
  detail,
  reader,
  discover,
  search,
  sourceCheck,
}

class SourceRuntimeTaskConflictService {
  SourceRuntimeTaskConflictService({AppLogger? logger})
    : _scheduler = SourceRuntimeSchedulerService(logger: logger);

  static final SourceRuntimeTaskConflictService instance =
      SourceRuntimeTaskConflictService();

  final SourceRuntimeSchedulerService _scheduler;

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
    required SourceRuntimeConflictScene byScene,
  }) {
    _scheduler.cancelLowerPriorityWorkFor(
      conflictKey: conflictKey,
      byScene: _toSchedulerScene(byScene),
    );
  }

  void clearAll() {
    _scheduler.clearAll();
  }

  SourceRuntimeSchedulerScene _toSchedulerScene(
    SourceRuntimeConflictScene scene,
  ) {
    return switch (scene) {
      SourceRuntimeConflictScene.bookshelfBackground =>
        SourceRuntimeSchedulerScene.bookshelfBackground,
      SourceRuntimeConflictScene.detail => SourceRuntimeSchedulerScene.detail,
      SourceRuntimeConflictScene.reader => SourceRuntimeSchedulerScene.reader,
      SourceRuntimeConflictScene.discover =>
        SourceRuntimeSchedulerScene.discover,
      SourceRuntimeConflictScene.search => SourceRuntimeSchedulerScene.search,
      SourceRuntimeConflictScene.sourceCheck =>
        SourceRuntimeSchedulerScene.sourceCheck,
    };
  }
}
