import 'package:flutter/material.dart';

import '../application/book_reading_status_service.dart';

class BookReadingStatusPresentation {
  const BookReadingStatusPresentation({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}

/// 阅读状态展示语义 mapper。
///
/// 未读 / 阅读中 / 已读完的业务判断由 `BookReadingStatusService` 负责；
/// UI 层统一从这里拿文案和图标，避免书架、详情页、后续编辑页各自维护一份。
class BookReadingStatusPresentationMapper {
  const BookReadingStatusPresentationMapper();

  BookReadingStatusPresentation resolve(BookReadingStatus status) {
    return switch (status) {
      BookReadingStatus.unread => const BookReadingStatusPresentation(
        label: '未读',
        icon: Icons.markunread_outlined,
      ),
      BookReadingStatus.reading => const BookReadingStatusPresentation(
        label: '阅读中',
        icon: Icons.menu_book_outlined,
      ),
      BookReadingStatus.finished => const BookReadingStatusPresentation(
        label: '已读完',
        icon: Icons.task_alt_rounded,
      ),
    };
  }
}
