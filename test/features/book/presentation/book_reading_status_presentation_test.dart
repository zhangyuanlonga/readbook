import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/book/application/book_reading_status_service.dart';
import 'package:shuxiang_reading_next/features/book/presentation/book_reading_status_presentation.dart';

void main() {
  const mapper = BookReadingStatusPresentationMapper();

  test('maps reading status labels and icons consistently', () {
    expect(mapper.resolve(BookReadingStatus.unread).label, '未读');
    expect(
      mapper.resolve(BookReadingStatus.unread).icon,
      Icons.markunread_outlined,
    );
    expect(mapper.resolve(BookReadingStatus.reading).label, '阅读中');
    expect(
      mapper.resolve(BookReadingStatus.reading).icon,
      Icons.menu_book_outlined,
    );
    expect(mapper.resolve(BookReadingStatus.finished).label, '已读完');
    expect(
      mapper.resolve(BookReadingStatus.finished).icon,
      Icons.task_alt_rounded,
    );
  });
}
