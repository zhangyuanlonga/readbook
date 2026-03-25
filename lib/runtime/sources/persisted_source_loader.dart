import 'source_file_store.dart';
import 'source_registry.dart';
import 'source_script_compiler.dart';

class PersistedSourceLoadResult {
  const PersistedSourceLoadResult({
    required this.sourceFile,
    required this.registeredSource,
  });

  final StoredSourceFile sourceFile;
  final RegisteredSource registeredSource;
}

class PersistedSourceLoadFailure {
  const PersistedSourceLoadFailure({
    required this.sourceFile,
    required this.error,
  });

  final StoredSourceFile sourceFile;
  final Object error;
}

class PersistedSourceLoadReport {
  const PersistedSourceLoadReport({
    required this.loaded,
    required this.failures,
  });

  final List<PersistedSourceLoadResult> loaded;
  final List<PersistedSourceLoadFailure> failures;
}

class PersistedSourceLoader {
  PersistedSourceLoader({
    required SourceFileStore sourceFileStore,
    required SourceScriptCompiler sourceScriptCompiler,
    this.revisionPrefix = 'file',
  }) : _sourceFileStore = sourceFileStore,
       _sourceScriptCompiler = sourceScriptCompiler;

  final SourceFileStore _sourceFileStore;
  final SourceScriptCompiler _sourceScriptCompiler;
  final String revisionPrefix;

  Future<PersistedSourceLoadReport> loadInto(SourceRegistry registry) async {
    final files = await _sourceFileStore.listSourceFiles();
    final loaded = <PersistedSourceLoadResult>[];
    final failures = <PersistedSourceLoadFailure>[];

    for (var index = 0; index < files.length; index += 1) {
      final sourceFile = files[index];
      try {
        final contents = await _sourceFileStore.readSource(sourceFile.filePath);
        final definition = await _sourceScriptCompiler.compile(contents);
        final registered = registry.register(
          definition,
          revision: '$revisionPrefix:${sourceFile.fileName}:${index + 1}',
        );
        loaded.add(
          PersistedSourceLoadResult(
            sourceFile: sourceFile,
            registeredSource: registered,
          ),
        );
      } catch (error) {
        failures.add(
          PersistedSourceLoadFailure(sourceFile: sourceFile, error: error),
        );
      }
    }

    return PersistedSourceLoadReport(loaded: loaded, failures: failures);
  }
}
