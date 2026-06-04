enum BookshelfTaxonomyKind { tag, category }

enum BookshelfCollectionAction { upsert, replace, remove }

enum BookshelfTaxonomyAction {
  create,
  rename,
  delete,
  metadataChanged,
  orderChanged,
  assignmentChanged,
}

class BookshelfTaxonomyChange {
  const BookshelfTaxonomyChange({
    required this.kind,
    required this.action,
    this.previousName,
    this.currentName,
  });

  final BookshelfTaxonomyKind kind;
  final BookshelfTaxonomyAction action;
  final String? previousName;
  final String? currentName;
}

class BookshelfCollectionChange {
  const BookshelfCollectionChange({
    required this.action,
    required this.sourceId,
    required this.detailUrl,
    this.bookId,
  });

  final BookshelfCollectionAction action;
  final String sourceId;
  final String detailUrl;
  final String? bookId;
}
