import 'source_result_models.dart' as runtime_models;

class SourceRuntimeInfo {
  const SourceRuntimeInfo({
    required this.id,
    required this.name,
    this.group = '',
    this.revision = '',
  });

  final String id;
  final String name;
  final String group;
  final String revision;
}

class RuntimeSourceManifest {
  const RuntimeSourceManifest({
    this.name = '',
    this.group = '',
    this.author = '',
    this.description = '',
    this.homepage,
    this.domains = const <String>[],
    this.capabilities = const <String>[],
  });

  final String name;
  final String group;
  final String author;
  final String description;
  final String? homepage;
  final List<String> domains;
  final List<String> capabilities;

  bool supportsCapability(String value) {
    final normalized = value.trim().toLowerCase();
    return capabilities.any(
      (item) => item.trim().toLowerCase() == normalized,
    );
  }
}

typedef SourceDiscoverCategoriesHandler =
    Future<List<runtime_models.DiscoverCategory>> Function(Object context);
typedef SourceDiscoverBooksHandler =
    Future<List<runtime_models.Book>> Function(
      Object context,
      runtime_models.DiscoverCategory category,
      int page,
      int pageSize,
    );
typedef SourceSearchHandler =
    Future<List<runtime_models.Book>> Function(Object context, String keyword);
typedef SourceDetailHandler =
    Future<runtime_models.Book> Function(
      Object context,
      runtime_models.Book book,
    );
typedef SourceChaptersHandler =
    Future<List<runtime_models.Chapter>> Function(
      Object context,
      runtime_models.Book book,
    );
typedef SourceContentHandler =
    Future<runtime_models.Content> Function(
      Object context,
      runtime_models.Book book,
      runtime_models.Chapter chapter,
    );

class RuntimeSourceDefinition {
  const RuntimeSourceDefinition({
    this.manifest = const RuntimeSourceManifest(),
    this.discoverCategories,
    this.discoverBooks,
    this.search,
    this.detail,
    this.chapters,
    this.content,
    this.dispose,
  });

  final RuntimeSourceManifest manifest;
  final SourceDiscoverCategoriesHandler? discoverCategories;
  final SourceDiscoverBooksHandler? discoverBooks;
  final SourceSearchHandler? search;
  final SourceDetailHandler? detail;
  final SourceChaptersHandler? chapters;
  final SourceContentHandler? content;
  final void Function()? dispose;
}

class RegisteredSource {
  const RegisteredSource({required this.runtime, required this.definition});

  final SourceRuntimeInfo runtime;
  final RuntimeSourceDefinition definition;
}

class SourceRegistry {
  const SourceRegistry();

  RegisteredSource? getById(String sourceId) => null;

  List<RegisteredSource> all({bool enabledOnly = true}) {
    return const <RegisteredSource>[];
  }

  void remove(String sourceId) {}

  void clear() {}
}
