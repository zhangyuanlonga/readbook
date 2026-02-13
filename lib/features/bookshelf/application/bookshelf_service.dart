import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/bookshelf_book.dart';

class BookshelfService {
  BookshelfService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  final Future<SharedPreferences> _preferencesFuture;

  static const String _storageKey = 'bookshelf.books';

  Future<List<BookshelfBook>> getAll() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <BookshelfBook>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <BookshelfBook>[];
      }

      final items = decoded
          .whereType<Map>()
          .map(
            (item) => BookshelfBook.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false);

      return items.reversed.toList(growable: false);
    } on FormatException {
      return const <BookshelfBook>[];
    }
  }

  Future<void> upsert(BookshelfBook item) async {
    final all = (await getAll()).toList(growable: true);
    final index = all.indexWhere(
      (entry) =>
          entry.sourceId == item.sourceId && entry.detailUrl == item.detailUrl,
    );

    final value = item.copyWith(addedAt: DateTime.now());
    if (index >= 0) {
      all.removeAt(index);
    }
    all.insert(0, value);

    await _save(all);
  }

  Future<void> remove({
    required String sourceId,
    required String detailUrl,
  }) async {
    final all = (await getAll())
        .where(
          (item) => !(item.sourceId == sourceId && item.detailUrl == detailUrl),
        )
        .toList(growable: false);
    await _save(all);
  }

  Future<bool> contains({
    required String sourceId,
    required String detailUrl,
  }) async {
    final all = await getAll();
    return all.any(
      (item) => item.sourceId == sourceId && item.detailUrl == detailUrl,
    );
  }

  Future<void> _save(List<BookshelfBook> books) async {
    final prefs = await _preferencesFuture;
    final encoded = jsonEncode(books.map((item) => item.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
