import 'dart:io';

const _pubspecPath = 'pubspec.yaml';
const _matrixPath = 'docs/dependency_override_governance_matrix_2026-06-04.md';

void main() {
  final pubspecFile = File(_pubspecPath);
  final matrixFile = File(_matrixPath);
  final violations = <String>[];

  if (!pubspecFile.existsSync()) {
    violations.add('Missing $_pubspecPath');
  }
  if (!matrixFile.existsSync()) {
    violations.add('Missing $_matrixPath');
  }

  if (violations.isEmpty) {
    final overrides = _readDependencyOverrides(pubspecFile);
    final documented = _readDocumentedOverrides(matrixFile);
    final missingDocs = overrides.difference(documented).toList()..sort();
    final staleDocs = documented.difference(overrides).toList()..sort();

    for (final name in missingDocs) {
      violations.add('dependency_overrides.$name is missing from $_matrixPath');
    }
    for (final name in staleDocs) {
      violations.add('$_matrixPath documents $name, but pubspec override is gone');
    }
  }

  stdout.writeln('==> Dependency override governance');
  stdout.writeln('Pubspec : $_pubspecPath');
  stdout.writeln('Matrix  : $_matrixPath');

  if (violations.isEmpty) {
    stdout.writeln('');
    stdout.writeln('All dependency_overrides are documented.');
    return;
  }

  stdout.writeln('');
  stdout.writeln('Violations');
  for (final violation in violations) {
    stdout.writeln('- $violation');
  }
  exitCode = 1;
}

Set<String> _readDependencyOverrides(File pubspecFile) {
  final result = <String>{};
  final lines = pubspecFile.readAsLinesSync();
  var insideOverrides = false;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    if (!insideOverrides) {
      if (trimmed == 'dependency_overrides:') {
        insideOverrides = true;
      }
      continue;
    }

    if (!line.startsWith(' ')) {
      break;
    }

    final match = RegExp(r'^\s{2}([A-Za-z0-9_]+):').firstMatch(line);
    if (match != null) {
      result.add(match.group(1)!);
    }
  }

  return result;
}

Set<String> _readDocumentedOverrides(File matrixFile) {
  final result = <String>{};
  final rowPattern = RegExp(r'^\|\s*([A-Za-z0-9_]+)\s*\|');
  for (final line in matrixFile.readAsLinesSync()) {
    final match = rowPattern.firstMatch(line);
    if (match == null) {
      continue;
    }
    final name = match.group(1)!;
    if (name == '包名') {
      continue;
    }
    result.add(name);
  }
  return result;
}
