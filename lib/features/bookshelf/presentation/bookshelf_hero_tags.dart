import '../../../domain/entities/bookshelf_book.dart';

class BookshelfHeroTagResolver {
  const BookshelfHeroTagResolver();

  String cover(BookshelfBook book) => _bookTag('book_cover', book);

  String title(BookshelfBook book) => _bookTag('book_title', book);

  String meta(BookshelfBook book) => _bookTag('book_meta', book);

  String _bookTag(String prefix, BookshelfBook book) {
    return '${prefix}_${book.sourceId.trim()}_${book.bookId.trim()}_${book.detailUrl.hashCode}';
  }
}
