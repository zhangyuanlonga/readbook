import 'dart:async';

import 'bookshelf_events.dart';

/// 书架集合与分类变更事件总线。
///
/// 事件总线只负责广播内存事件，不负责持久化、业务判断或 UI 状态。
/// 这样 `BookshelfService` 后续继续拆 taxonomy / collection 逻辑时，可以保留
/// 现有 `watchTaxonomyChanges` 和 `watchCollectionChanges` 对外协议，不让页面层跟着改。
final class BookshelfEventBus {
  BookshelfEventBus();

  final StreamController<BookshelfTaxonomyChange> _taxonomyChangeController =
      StreamController<BookshelfTaxonomyChange>.broadcast();
  final StreamController<BookshelfCollectionChange>
  _collectionChangeController =
      StreamController<BookshelfCollectionChange>.broadcast();

  Stream<BookshelfTaxonomyChange> get watchTaxonomyChanges =>
      _taxonomyChangeController.stream;

  Stream<BookshelfCollectionChange> get watchCollectionChanges =>
      _collectionChangeController.stream;

  void emitTaxonomyChange(BookshelfTaxonomyChange change) {
    if (_taxonomyChangeController.isClosed) {
      return;
    }
    _taxonomyChangeController.add(change);
  }

  void emitCollectionChange(BookshelfCollectionChange change) {
    if (_collectionChangeController.isClosed) {
      return;
    }
    _collectionChangeController.add(change);
  }
}
