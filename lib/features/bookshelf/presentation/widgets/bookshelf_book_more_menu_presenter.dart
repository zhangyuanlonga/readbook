import 'package:flutter/material.dart';

import '../../../../domain/entities/bookshelf_book.dart';
import '../../../book/application/book_reading_status_service.dart';
import '../../../book/presentation/book_reading_status_presentation.dart';
import '../bookshelf_page_models.dart';
import '../bookshelf_reading_queue_presentation.dart';
import 'bookshelf_book_more_menu.dart';

class BookshelfBookMoreMenuPresenter extends StatelessWidget {
  const BookshelfBookMoreMenuPresenter({
    super.key,
    required this.book,
    required this.compact,
    required this.currentReadingStatus,
    required this.onAction,
    required this.onReadingStatusSelected,
    this.readingStatusValues = BookReadingStatus.values,
    this.readingQueuePresentationMapper =
        const BookshelfReadingQueuePresentationMapper(),
    this.readingStatusPresentationMapper =
        const BookReadingStatusPresentationMapper(),
  });

  final BookshelfBook book;
  final bool compact;
  final BookReadingStatus currentReadingStatus;
  final ValueChanged<BookshelfBookMoreAction> onAction;
  final ValueChanged<BookReadingStatus> onReadingStatusSelected;
  final List<BookReadingStatus> readingStatusValues;
  final BookshelfReadingQueuePresentationMapper readingQueuePresentationMapper;
  final BookReadingStatusPresentationMapper readingStatusPresentationMapper;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final queuePresentation = readingQueuePresentationMapper.resolve(
      inReadingQueue: book.inReadingQueue,
    );
    return BookshelfBookMoreMenu(
      compact: compact,
      menuChildren: <Widget>[
        BookshelfBookMenuItem(
          icon: Icons.info_outline_rounded,
          label: '查看详情',
          onPressed: () => onAction(BookshelfBookMoreAction.detail),
        ),
        BookshelfBookMenuItem(
          icon: Icons.edit_outlined,
          label: '编辑',
          onPressed: () => onAction(BookshelfBookMoreAction.edit),
        ),
        const Divider(height: 1),
        BookshelfBookMenuItem(
          icon: Icons.sell_outlined,
          label: '标签',
          onPressed: () => onAction(BookshelfBookMoreAction.tags),
        ),
        BookshelfBookMenuItem(
          icon: Icons.folder_outlined,
          label: '分类',
          onPressed: () => onAction(BookshelfBookMoreAction.category),
        ),
        BookshelfBookMenuItem(
          icon: queuePresentation.menuIcon,
          label: queuePresentation.menuLabel,
          onPressed: () => onAction(BookshelfBookMoreAction.readingQueue),
        ),
        SubmenuButton(
          leadingIcon: const Icon(Icons.flag_outlined, size: 18),
          menuChildren: [
            for (final status in readingStatusValues)
              _ReadingStatusMenuItem(
                status: status,
                selected: currentReadingStatus == status,
                presentationMapper: readingStatusPresentationMapper,
                onSelected: onReadingStatusSelected,
              ),
          ],
          child: const Text('标记'),
        ),
        const Divider(height: 1),
        BookshelfBookMenuItem(
          icon: Icons.checklist_rounded,
          label: '选择书籍',
          onPressed: () => onAction(BookshelfBookMoreAction.select),
        ),
        BookshelfBookMenuItem(
          icon: Icons.delete_outline_rounded,
          label: '删除',
          foregroundColor: colorScheme.error,
          onPressed: () => onAction(BookshelfBookMoreAction.delete),
        ),
      ],
    );
  }
}

class _ReadingStatusMenuItem extends StatelessWidget {
  const _ReadingStatusMenuItem({
    required this.status,
    required this.selected,
    required this.presentationMapper,
    required this.onSelected,
  });

  final BookReadingStatus status;
  final bool selected;
  final BookReadingStatusPresentationMapper presentationMapper;
  final ValueChanged<BookReadingStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    final presentation = presentationMapper.resolve(status);
    return MenuItemButton(
      leadingIcon: Icon(presentation.icon, size: 18),
      trailingIcon: selected ? const Icon(Icons.check_rounded, size: 18) : null,
      onPressed: () => onSelected(status),
      child: Text(presentation.label),
    );
  }
}
