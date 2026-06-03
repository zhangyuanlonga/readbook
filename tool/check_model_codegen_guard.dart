import 'dart:io';

import 'package:path/path.dart' as p;

final RegExp _toJsonMethodPattern = RegExp(
  r'^\s*Map<[^>]+>\s+toJson\s*\(',
  multiLine: true,
);
final RegExp _fromJsonFactoryPattern = RegExp(
  r'^\s*factory\s+[A-Za-z0-9_<>, ?]+\s+fromJson\s*\(',
  multiLine: true,
);
final RegExp _copyWithMethodPattern = RegExp(
  r'^\s*[A-Za-z0-9_<>, ?]+\s+copyWith\s*\(',
  multiLine: true,
);
final RegExp _equalityPattern = RegExp(
  r'^\s*(?:@override\s+)?bool\s+operator\s*==|^\s*(?:@override\s+)?int\s+get\s+hashCode',
  multiLine: true,
);
final RegExp _classPattern = RegExp(
  r'^\s*(?:abstract\s+)?(?:final\s+)?class\s+[A-Za-z0-9_]+',
  multiLine: true,
);
final RegExp _freezedAnnotationPattern = RegExp(r'@\s*freezed\b');
final RegExp _freezedPartPattern = RegExp(
  r'''part\s+['"][^'"]+\.freezed\.dart['"]''',
);
final RegExp _jsonSerializablePattern = RegExp(r'@\s*JsonSerializable\b');
final RegExp _jsonPartPattern = RegExp(r'''part\s+['"][^'"]+\.g\.dart['"]''');

const Set<String> _legacyHandwrittenModelDebt = <String>{};

final class _Issue {
  const _Issue({required this.path, required this.message});

  final String path;
  final String message;
}

final class _ModelSignals {
  const _ModelSignals({
    required this.hasClass,
    required this.hasToJson,
    required this.hasFromJson,
    required this.hasCopyWith,
    required this.hasEquality,
    required this.usesFreezed,
    required this.usesJsonSerializable,
  });

  final bool hasClass;
  final bool hasToJson;
  final bool hasFromJson;
  final bool hasCopyWith;
  final bool hasEquality;
  final bool usesFreezed;
  final bool usesJsonSerializable;

  bool get hasHandwrittenJson => hasToJson && hasFromJson;
  bool get hasHandwrittenStateModel => hasCopyWith || hasEquality;
  bool get usesCodegen => usesFreezed || usesJsonSerializable;
}

Future<void> main(List<String> args) async {
  final root = _parseRoot(args);
  final verbose = args.contains('--verbose');
  final findings = <_Issue>[];
  var trackedDebtCount = 0;

  for (final file in _dartFiles(root)) {
    final relativePath = p.relative(file.path, from: root.path);
    final source = file.readAsStringSync();
    final signals = _collectSignals(source);
    if (!signals.hasClass) {
      continue;
    }

    if (!_isCandidateFile(relativePath, signals)) {
      continue;
    }

    if (signals.usesCodegen) {
      continue;
    }

    if (_legacyHandwrittenModelDebt.contains(relativePath)) {
      trackedDebtCount += 1;
      continue;
    }

    if (signals.hasHandwrittenJson) {
      findings.add(
        _Issue(
          path: relativePath,
          message:
              'new JSON model still handwrites toJson/fromJson; use json_serializable or document debt before landing',
        ),
      );
    }

    if (_isStateModelCandidate(relativePath, signals) &&
        signals.hasHandwrittenStateModel) {
      findings.add(
        _Issue(
          path: relativePath,
          message:
              'new complex state model still handwrites copyWith/equality; use freezed or document debt before landing',
        ),
      );
    }
  }

  stdout.writeln('==> Model codegen guard');
  stdout.writeln('Root                : ${root.path}');
  stdout.writeln('Tracked legacy debt : $trackedDebtCount file(s)');

  if (verbose && _legacyHandwrittenModelDebt.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('Tracked legacy debt list');
    final sortedDebt = _legacyHandwrittenModelDebt.toList()..sort();
    for (final path in sortedDebt) {
      stdout.writeln('- $path');
    }
  }

  if (findings.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('Violations');
    for (final finding in findings) {
      stdout.writeln('- ${finding.path}: ${finding.message}');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('');
  stdout.writeln('No violations found.');
}

Directory _parseRoot(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--root=')) {
      return Directory(arg.substring('--root='.length).trim());
    }
  }
  return Directory.current;
}

List<File> _dartFiles(Directory root) {
  final libDirectory = Directory(p.join(root.path, 'lib'));
  if (!libDirectory.existsSync()) {
    return const <File>[];
  }

  final files =
      libDirectory
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where(_isNotGenerated)
          .toList();
  files.sort((left, right) => left.path.compareTo(right.path));
  return files;
}

bool _isNotGenerated(File file) {
  final basename = p.basename(file.path);
  return !basename.endsWith('.g.dart') && !basename.endsWith('.freezed.dart');
}

_ModelSignals _collectSignals(String source) {
  return _ModelSignals(
    hasClass: _classPattern.hasMatch(source),
    hasToJson: _toJsonMethodPattern.hasMatch(source),
    hasFromJson: _fromJsonFactoryPattern.hasMatch(source),
    hasCopyWith: _copyWithMethodPattern.hasMatch(source),
    hasEquality: _equalityPattern.hasMatch(source),
    usesFreezed:
        _freezedAnnotationPattern.hasMatch(source) ||
        _freezedPartPattern.hasMatch(source),
    usesJsonSerializable:
        _jsonSerializablePattern.hasMatch(source) &&
        _jsonPartPattern.hasMatch(source),
  );
}

bool _isCandidateFile(String relativePath, _ModelSignals signals) {
  if (_isJsonCandidate(relativePath) && signals.hasHandwrittenJson) {
    return true;
  }
  if (_isStateModelCandidate(relativePath, signals) &&
      signals.hasHandwrittenStateModel) {
    return true;
  }
  return false;
}

bool _isJsonCandidate(String relativePath) {
  final normalized = relativePath.replaceAll('\\', '/');
  if (normalized.startsWith('lib/domain/entities/')) {
    return true;
  }
  return normalized.endsWith('_dto.dart') ||
      normalized.endsWith('_payload.dart') ||
      normalized.endsWith('_snapshot.dart') ||
      normalized.endsWith('_models.dart');
}

bool _isStateModelCandidate(String relativePath, _ModelSignals signals) {
  if (!signals.hasHandwrittenStateModel) {
    return false;
  }

  final normalized = relativePath.replaceAll('\\', '/');
  if (normalized.startsWith('lib/domain/entities/')) {
    return true;
  }
  return normalized.endsWith('_state.dart') ||
      normalized.endsWith('_snapshot.dart') ||
      normalized.endsWith('_models.dart');
}
