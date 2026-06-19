import 'dart:io';

import 'package:path/path.dart' as p;

const _packagePrefix = 'package:shuxiang_reading_next/';

// Keep this map intentionally small. Each whitelist entry must be tied to a
// tracked migration note before it is added.
const _allowedCoreFeatureImports = <String, Set<String>>{};

final class _ImportViolation {
  const _ImportViolation({
    required this.sourcePath,
    required this.targetPath,
    required this.line,
  });

  final String sourcePath;
  final String targetPath;
  final int line;
}

Future<void> main(List<String> args) async {
  final root = _parseRoot(args);
  final strict = args.contains('--strict');
  final violations = _findCoreFeatureImports(root).toList(growable: false);

  stdout.writeln('==> Core feature import guard');
  stdout.writeln('Root : ${root.path}');
  stdout.writeln('Mode : ${strict ? 'strict' : 'report'}');
  stdout.writeln('Rule : lib/core/** must not import lib/features/**');
  stdout.writeln('Whitelist entries: ${_allowedCoreFeatureImports.length}');

  if (violations.isEmpty) {
    stdout.writeln('');
    stdout.writeln('No core -> features imports found.');
    return;
  }

  stdout.writeln('');
  stdout.writeln('Violations');
  for (final violation in violations) {
    stdout.writeln(
      '- ${violation.sourcePath}:${violation.line} imports '
      '${violation.targetPath}',
    );
  }

  if (strict) {
    exitCode = 1;
  } else {
    stdout.writeln('');
    stdout.writeln('Report mode only: rerun with --strict to fail on these.');
  }
}

Directory _parseRoot(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--root=')) {
      return Directory(arg.substring('--root='.length).trim());
    }
  }
  return Directory.current;
}

Iterable<_ImportViolation> _findCoreFeatureImports(Directory root) sync* {
  final coreDirectory = Directory(p.join(root.path, 'lib', 'core'));
  if (!coreDirectory.existsSync()) {
    return;
  }

  final files = coreDirectory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList(growable: false)
    ..sort((left, right) => left.path.compareTo(right.path));

  final directivePattern = RegExp(
    r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  for (final file in files) {
    final sourcePath = p.relative(file.path, from: root.path);
    final content = file.readAsStringSync();
    for (final match in directivePattern.allMatches(content)) {
      final target = match.group(1)!;
      final resolvedTarget = _resolveImportTarget(sourcePath, target);
      if (!resolvedTarget.startsWith('lib/features/')) {
        continue;
      }
      if (_isAllowed(sourcePath, resolvedTarget)) {
        continue;
      }
      yield _ImportViolation(
        sourcePath: sourcePath,
        targetPath: resolvedTarget,
        line: _lineNumber(content, match.start),
      );
    }
  }
}

bool _isAllowed(String sourcePath, String targetPath) {
  final allowedTargets = _allowedCoreFeatureImports[sourcePath];
  if (allowedTargets == null) {
    return false;
  }
  return allowedTargets.contains(targetPath) || allowedTargets.contains('*');
}

String _resolveImportTarget(String sourcePath, String target) {
  if (target.startsWith('dart:')) {
    return target;
  }
  if (target.startsWith('package:')) {
    if (target.startsWith(_packagePrefix)) {
      return 'lib/${target.substring(_packagePrefix.length)}';
    }
    return target;
  }
  return p.normalize(p.join(p.dirname(sourcePath), target));
}

int _lineNumber(String content, int offset) {
  return '\n'.allMatches(content.substring(0, offset)).length + 1;
}
