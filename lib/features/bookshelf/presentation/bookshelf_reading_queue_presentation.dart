import 'package:flutter/material.dart';

class BookshelfReadingQueuePresentation {
  const BookshelfReadingQueuePresentation({
    required this.filterLabel,
    required this.menuLabel,
    required this.successMessage,
    required this.failureMessage,
    required this.menuIcon,
  });

  final String filterLabel;
  final String menuLabel;
  final String successMessage;
  final String failureMessage;
  final IconData menuIcon;
}

/// 待读清单展示语义 mapper。
///
/// 待读清单是“书架收藏/排队阅读状态”，不是未读、阅读中、已读完这类
/// 阅读状态。书架筛选、更多菜单和 toast 都从这里取文案，避免混入阅读状态枚举。
class BookshelfReadingQueuePresentationMapper {
  const BookshelfReadingQueuePresentationMapper();

  String get filterLabel => '待读清单';

  String get failureMessage => '待读清单更新失败，请重试。';

  BookshelfReadingQueuePresentation resolve({required bool inReadingQueue}) {
    return BookshelfReadingQueuePresentation(
      filterLabel: filterLabel,
      menuLabel: inReadingQueue ? '移出待读清单' : '添加待读清单',
      successMessage: inReadingQueue ? '已加入待读清单。' : '已移出待读清单。',
      failureMessage: failureMessage,
      menuIcon:
          inReadingQueue
              ? Icons.playlist_remove_rounded
              : Icons.playlist_add_rounded,
    );
  }
}
