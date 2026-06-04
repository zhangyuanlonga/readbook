import 'dart:io';

const _storageGuardPath = 'tool/check_storage_governance_guard.dart';
const _matrixPath = 'docs/storage_governance_baseline_matrix_2026-06-04.md';

const _baselineSets = <String, String>{
  'prefs-json': '_approvedJsonBackedPreferenceWrites',
  'temp-dir': '_approvedTemporaryDirectoryUsages',
  'startup-cleanup': '_approvedStartupCleanupUsages',
  'managed-dir': '_approvedManagedDirectoryUsages',
};

void main() {
  final guardFile = File(_storageGuardPath);
  final matrixFile = File(_matrixPath);
  final violations = <String>[];

  if (!guardFile.existsSync()) {
    violations.add('Missing $_storageGuardPath');
  }
  if (!matrixFile.existsSync()) {
    violations.add('Missing $_matrixPath');
  }

  if (violations.isEmpty) {
    final approved = _readApprovedBaselines(guardFile);
    final documented = _readDocumentedBaselines(matrixFile);

    for (final entry in _baselineSets.entries) {
      final kind = entry.key;
      final approvedIds = approved[kind] ?? const <String>{};
      final documentedIds = documented[kind] ?? const <String>{};
      final missingDocs = approvedIds.difference(documentedIds).toList()
        ..sort();
      final staleDocs = documentedIds.difference(approvedIds).toList()..sort();

      for (final id in missingDocs) {
        violations.add('Approved $kind baseline is missing docs: $id');
      }
      for (final id in staleDocs) {
        violations.add('Documented $kind baseline is not approved anymore: $id');
      }
    }
  }

  stdout.writeln('==> Storage baseline governance');
  stdout.writeln('Guard  : $_storageGuardPath');
  stdout.writeln('Matrix : $_matrixPath');

  if (violations.isEmpty) {
    stdout.writeln('');
    stdout.writeln('All approved storage baselines are documented.');
    return;
  }

  stdout.writeln('');
  stdout.writeln('Violations');
  for (final violation in violations) {
    stdout.writeln('- $violation');
  }
  exitCode = 1;
}

Map<String, Set<String>> _readApprovedBaselines(File guardFile) {
  final content = guardFile.readAsStringSync();
  return <String, Set<String>>{
    for (final entry in _baselineSets.entries)
      entry.key: _readConstStringSet(content, entry.value),
  };
}

Set<String> _readConstStringSet(String content, String name) {
  final pattern = RegExp(
    'const Set<String>\\s+$name\\s*=\\s*<String>\\{([\\s\\S]*?)\\};',
  );
  final match = pattern.firstMatch(content);
  if (match == null) {
    return const <String>{};
  }
  return RegExp("'([^']+)'")
      .allMatches(match.group(1)!)
      .map((item) => item.group(1)!)
      .toSet();
}

Map<String, Set<String>> _readDocumentedBaselines(File matrixFile) {
  final result = <String, Set<String>>{
    for (final kind in _baselineSets.keys) kind: <String>{},
  };
  final rowPattern = RegExp(r'^\|\s*([a-z-]+)\s*\|\s*`([^`]+)`\s*\|');
  for (final line in matrixFile.readAsLinesSync()) {
    final match = rowPattern.firstMatch(line);
    if (match == null) {
      continue;
    }
    final kind = match.group(1)!;
    final id = match.group(2)!;
    if (!result.containsKey(kind)) {
      continue;
    }
    result[kind]!.add(id);
  }
  return result;
}
