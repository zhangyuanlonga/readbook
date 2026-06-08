import 'package:flutter/material.dart';

import '../../application/bookshelf_page_state.dart';
import '../../providers.dart';

class BookshelfLibrarySidebarActionInput {
  const BookshelfLibrarySidebarActionInput({
    required this.filter,
    required this.label,
    required this.count,
    required this.selected,
    required this.icon,
    required this.onSelected,
  });

  final BookshelfFilter filter;
  final String label;
  final int count;
  final bool selected;
  final IconData icon;
  final VoidCallback onSelected;
}

DesktopBookshelfLibraryActions? buildDesktopBookshelfLibraryActions({
  required bool enabled,
  required String activeLabel,
  required Iterable<BookshelfLibrarySidebarActionInput> statusActions,
  List<DesktopBookshelfLibraryFilterGroup> filterGroups =
      const <DesktopBookshelfLibraryFilterGroup>[],
}) {
  if (!enabled) {
    return null;
  }
  return DesktopBookshelfLibraryActions(
    activeLabel: activeLabel,
    statusActions: [
      for (final action in statusActions)
        DesktopBookshelfLibraryStatusAction(
          label: action.label,
          count: action.count,
          selected: action.selected,
          icon: action.icon,
          onSelected: action.onSelected,
        ),
    ],
    filterGroups: filterGroups,
  );
}
