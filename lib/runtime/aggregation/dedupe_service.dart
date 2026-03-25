import '../sources/source_result_models.dart';
import 'aggregation_models.dart';

class DedupeService {
  const DedupeService();

  List<AggregatedBook> dedupe(List<Book> books) {
    final buckets = <String, List<Book>>{};

    for (final book in books) {
      final key = buildBookKey(book);
      buckets.putIfAbsent(key, () => <Book>[]).add(book);
    }

    return buckets.entries
        .map(
          (MapEntry<String, List<Book>> entry) => AggregatedBook(
            key: entry.key,
            primary: entry.value.first,
            sourceBooks: List<Book>.unmodifiable(entry.value),
          ),
        )
        .toList(growable: false);
  }

  String buildBookKey(Book book) {
    final normalizedTitle = _normalize(book.title);
    final normalizedAuthor = _normalize(book.author);
    return '$normalizedTitle::$normalizedAuthor';
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }
}
