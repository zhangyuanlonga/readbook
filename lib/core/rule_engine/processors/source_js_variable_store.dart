import '../../../domain/entities/source_definition.dart';

class SourceJsVariableStore {
  const SourceJsVariableStore._();

  static const String storageKey = '_appread_js_variables';
  static const String bookStorageKey = '_appread_js_book_variables';

  static Map<String, String> load(SourceDefinition source) {
    final persisted = _readPersistedVariables(source);
    if (persisted.isEmpty) {
      return const <String, String>{};
    }
    return toRuntimeVariables(persisted);
  }

  static Map<String, String> toRuntimeVariables(Map<String, String> source) {
    final normalized = _normalizeVariables(source);
    if (normalized.isEmpty) {
      return const <String, String>{};
    }

    final output = <String, String>{};
    for (final entry in normalized.entries) {
      output[entry.key] = entry.value;
      output['\$.${entry.key}'] = entry.value;
    }
    return output;
  }

  static SourceDefinition merge({
    required SourceDefinition source,
    required Map<String, String> updates,
  }) {
    final normalizedUpdates = _normalizeVariables(updates);
    if (normalizedUpdates.isEmpty) {
      return source;
    }

    final merged = _readPersistedVariables(source)..addAll(normalizedUpdates);
    final nextOriginalSource = <String, dynamic>{...?source.originalSource};
    nextOriginalSource[storageKey] = <String, String>{...merged};
    return source.copyWith(originalSource: nextOriginalSource);
  }

  static Map<String, String> loadBook(
    SourceDefinition source, {
    required String bookId,
  }) {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return const <String, String>{};
    }

    final allBooks = _readAllBookVariables(source);
    final persisted = allBooks[normalizedBookId];
    if (persisted == null || persisted.isEmpty) {
      return const <String, String>{};
    }
    return toRuntimeVariables(persisted);
  }

  static SourceDefinition mergeBook({
    required SourceDefinition source,
    required String bookId,
    required Map<String, String> updates,
  }) {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return source;
    }

    final normalizedUpdates = _normalizeVariables(updates);
    if (normalizedUpdates.isEmpty) {
      return source;
    }

    final allBooks = _readAllBookVariables(source);
    final mergedBook = <String, String>{
      ...?allBooks[normalizedBookId],
      ...normalizedUpdates,
    };
    allBooks[normalizedBookId] = mergedBook;

    final nextOriginalSource = <String, dynamic>{...?source.originalSource};
    nextOriginalSource[bookStorageKey] = allBooks.map(
      (key, value) => MapEntry(key, <String, String>{...value}),
    );
    return source.copyWith(originalSource: nextOriginalSource);
  }

  static Map<String, String> _readPersistedVariables(SourceDefinition source) {
    final rawSource = source.originalSource;
    if (rawSource == null) {
      return <String, String>{};
    }

    final rawVariables = rawSource[storageKey];
    if (rawVariables is! Map) {
      return <String, String>{};
    }

    final output = <String, String>{};
    for (final entry in rawVariables.entries) {
      final key = _normalizeKey(entry.key.toString());
      if (key == null) {
        continue;
      }
      output[key] = entry.value?.toString() ?? '';
    }
    return output;
  }

  static Map<String, Map<String, String>> _readAllBookVariables(
    SourceDefinition source,
  ) {
    final rawSource = source.originalSource;
    if (rawSource == null) {
      return <String, Map<String, String>>{};
    }

    final rawBooks = rawSource[bookStorageKey];
    if (rawBooks is! Map) {
      return <String, Map<String, String>>{};
    }

    final output = <String, Map<String, String>>{};
    for (final entry in rawBooks.entries) {
      final normalizedBookId = entry.key.toString().trim();
      if (normalizedBookId.isEmpty) {
        continue;
      }
      final value = entry.value;
      if (value is! Map) {
        continue;
      }

      final variables = <String, String>{};
      for (final variableEntry in value.entries) {
        final key = _normalizeKey(variableEntry.key.toString());
        if (key == null) {
          continue;
        }
        variables[key] = variableEntry.value?.toString() ?? '';
      }

      if (variables.isNotEmpty) {
        output[normalizedBookId] = variables;
      }
    }
    return output;
  }

  static Map<String, String> _normalizeVariables(Map<String, String> source) {
    final output = <String, String>{};
    for (final entry in source.entries) {
      final key = _normalizeKey(entry.key);
      if (key == null) {
        continue;
      }
      output[key] = entry.value;
    }
    return output;
  }

  static String? _normalizeKey(String key) {
    final text = key.trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.startsWith(r'$.') && text.length > 2) {
      final stripped = text.substring(2).trim();
      return stripped.isEmpty ? null : stripped;
    }
    return text;
  }
}
