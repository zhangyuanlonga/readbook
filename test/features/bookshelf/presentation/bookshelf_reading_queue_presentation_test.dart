import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_reading_queue_presentation.dart';

void main() {
  const mapper = BookshelfReadingQueuePresentationMapper();

  test('keeps reading queue wording separate from reading status', () {
    final queued = mapper.resolve(inReadingQueue: true);
    final notQueued = mapper.resolve(inReadingQueue: false);

    expect(mapper.filterLabel, '待读清单');
    expect(mapper.failureMessage, '待读清单更新失败，请重试。');
    expect(queued.menuLabel, '移出待读清单');
    expect(queued.menuIcon, Icons.playlist_remove_rounded);
    expect(queued.successMessage, '已加入待读清单。');
    expect(notQueued.menuLabel, '添加待读清单');
    expect(notQueued.menuIcon, Icons.playlist_add_rounded);
    expect(notQueued.successMessage, '已移出待读清单。');
  });
}
