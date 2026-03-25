import 'source_contract.dart';
import 'source_manifest.dart';

class RegisteredSource {
  const RegisteredSource({required this.runtime, required this.definition});

  final SourceRuntimeInfo runtime;
  final RuntimeSourceDefinition definition;
}

class SourceRegistry {
  final Map<String, RegisteredSource> _sources = <String, RegisteredSource>{};
  final Map<String, int> _slugCounts = <String, int>{};

  RegisteredSource register(
    RuntimeSourceDefinition definition, {
    String revision = 'local-1',
  }) {
    final slug = _slugify(definition.manifest.name);
    final count = (_slugCounts[slug] ?? 0) + 1;
    _slugCounts[slug] = count;
    final runtimeId = count == 1 ? slug : '$slug-$count';

    final registered = RegisteredSource(
      runtime: SourceRuntimeInfo(
        id: runtimeId,
        name: definition.manifest.name,
        group: definition.manifest.group,
        revision: revision,
      ),
      definition: definition,
    );
    _sources[runtimeId] = registered;
    return registered;
  }

  RegisteredSource upsert(
    String runtimeId,
    RuntimeSourceDefinition definition, {
    String revision = 'local-1',
  }) {
    final registered = RegisteredSource(
      runtime: SourceRuntimeInfo(
        id: runtimeId,
        name: definition.manifest.name,
        group: definition.manifest.group,
        revision: revision,
      ),
      definition: definition,
    );
    _sources[runtimeId] = registered;
    return registered;
  }

  RegisteredSource? getById(String sourceId) => _sources[sourceId];

  List<RegisteredSource> all({bool enabledOnly = true}) {
    final values = _sources.values;
    if (!enabledOnly) {
      return values.toList(growable: false);
    }
    return values
        .where((RegisteredSource source) => source.definition.manifest.enabled)
        .toList(growable: false);
  }

  void remove(String sourceId) {
    _sources.remove(sourceId);
  }

  void clear() {
    _sources.clear();
    _slugCounts.clear();
  }

  String _slugify(String input) {
    final normalized = input.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
    final trimmed = normalized.replaceAll(RegExp(r'^-+|-+$'), '');
    if (trimmed.isEmpty) {
      return 'source';
    }
    return trimmed;
  }
}
