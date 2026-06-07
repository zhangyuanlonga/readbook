import '../../source/application/remote_content_task_conflict_service.dart';

class BookshelfLatestInfoRefreshController {
  BookshelfLatestInfoRefreshController(this._taskConflictService);

  final RemoteContentTaskConflictService _taskConflictService;

  int _refreshEpoch = 0;

  int startRefresh() {
    _refreshEpoch += 1;
    return _refreshEpoch;
  }

  void cancel() {
    _refreshEpoch += 1;
  }

  bool isCancelled({
    required int ticket,
    required int loadTicket,
    required int refreshEpoch,
    required bool mounted,
    required bool isBookshelfRoute,
  }) {
    return !mounted ||
        ticket != loadTicket ||
        refreshEpoch != _refreshEpoch ||
        !isBookshelfRoute;
  }

  String bookConflictKey({
    required String sourceId,
    required String detailUrl,
    required String bookId,
  }) {
    return _taskConflictService.conflictKeyForBook(
      sourceId: sourceId,
      detailUrl: detailUrl,
      bookId: bookId,
    );
  }

  void cancelBackgroundRefreshForBook({
    required String sourceId,
    required String detailUrl,
    required String bookId,
    required RemoteContentConflictScene byScene,
  }) {
    final conflictKey = bookConflictKey(
      sourceId: sourceId,
      detailUrl: detailUrl,
      bookId: bookId,
    );
    if (conflictKey.isEmpty) {
      return;
    }
    _taskConflictService.cancelBackgroundWorkFor(
      conflictKey: conflictKey,
      byScene: byScene,
    );
  }
}
