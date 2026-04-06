import '../../../runtime/sources/source_executor.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../../runtime/sources/source_result_models.dart' as runtime_models;
import 'source_runtime_request_execution_container.dart';

abstract class SourceRuntimeDiagnosticExecutionContainer {
  String get sourceId;
  String get sourceName;

  Future<List<runtime_models.Book>> search(String keyword);

  Future<runtime_models.Book> detail(runtime_models.Book book);

  Future<List<runtime_models.Chapter>> chapters(runtime_models.Book book);

  Future<runtime_models.Content> content(
    runtime_models.Book book,
    runtime_models.Chapter chapter,
  );

  void dispose();
}

class DefaultSourceRuntimeDiagnosticExecutionContainer
    implements SourceRuntimeDiagnosticExecutionContainer {
  const DefaultSourceRuntimeDiagnosticExecutionContainer({
    required this.source,
    required this.requestContainer,
  });

  final RegisteredSource source;
  final SourceRuntimeRequestExecutionContainer requestContainer;

  SourceExecutor get _executor => requestContainer.executor;

  @override
  String get sourceId => source.runtime.id;

  @override
  String get sourceName => source.runtime.name;

  @override
  Future<List<runtime_models.Book>> search(String keyword) {
    return _executor.search(source, keyword);
  }

  @override
  Future<runtime_models.Book> detail(runtime_models.Book book) {
    return _executor.detail(source, book);
  }

  @override
  Future<List<runtime_models.Chapter>> chapters(runtime_models.Book book) {
    return _executor.chapters(source, book);
  }

  @override
  Future<runtime_models.Content> content(
    runtime_models.Book book,
    runtime_models.Chapter chapter,
  ) {
    return _executor.content(source, book, chapter);
  }

  @override
  void dispose() {
    source.definition.dispose?.call();
    requestContainer.dispose();
  }
}
