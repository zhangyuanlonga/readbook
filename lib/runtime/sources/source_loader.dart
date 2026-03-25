import 'source_contract.dart';
import 'source_registry.dart';

abstract class SourceLoader {
  Future<List<RegisteredSource>> loadInto(SourceRegistry registry);
}

class InMemorySourceLoader implements SourceLoader {
  const InMemorySourceLoader({
    required List<RuntimeSourceDefinition> definitions,
    this.revisionPrefix = 'builtin',
  }) : _definitions = definitions;

  final List<RuntimeSourceDefinition> _definitions;
  final String revisionPrefix;

  @override
  Future<List<RegisteredSource>> loadInto(SourceRegistry registry) async {
    final loaded = <RegisteredSource>[];
    for (var index = 0; index < _definitions.length; index += 1) {
      loaded.add(
        registry.register(
          _definitions[index],
          revision: '$revisionPrefix-${index + 1}',
        ),
      );
    }
    return loaded;
  }
}
