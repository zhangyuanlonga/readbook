import 'dart:io';

import 'package:path/path.dart' as p;

const _warningThreshold = 2500;
const _requiresExplanationThreshold = 4000;

const _largeFileExplanations = <String, String>{
  'lib/features/bookshelf/presentation/bookshelf_page.dart':
      'Legacy Bookshelf page split debt; Phase 4 has already moved UI slices '
      'and migration work continues through focused follow-up commits.',
  'lib/features/reader/presentation/reader_page.dart':
      'Reader core shell debt; core reading flow is intentionally frozen while '
      'non-core helpers migrate out.',
  'lib/data/datasources/local/app_database.dart':
      'Drift database aggregate file; splitting requires an explicit schema '
      'and migration plan.',
};

final class _FileSizeFinding {
  const _FileSizeFinding({
    required this.path,
    required this.lineCount,
    required this.requiresExplanation,
    this.explanation,
  });

  final String path;
  final int lineCount;
  final bool requiresExplanation;
  final String? explanation;
}

Future<void> main(List<String> args) async {
  final root = _parseRoot(args);
  final strict = args.contains('--strict');
  final findings = _findLargeFiles(root).toList(growable: false);
  final missingExplanations = findings
      .where(
        (finding) => finding.requiresExplanation && finding.explanation == null,
      )
      .toList(growable: false);

  stdout.writeln('==> File size audit');
  stdout.writeln('Root : ${root.path}');
  stdout.writeln('Mode : ${strict ? 'strict' : 'report'}');
  stdout.writeln('Warn : > $_warningThreshold lines');
  stdout.writeln('Require explanation: > $_requiresExplanationThreshold lines');

  if (findings.isEmpty) {
    stdout.writeln('');
    stdout.writeln('No files exceed $_warningThreshold lines.');
    return;
  }

  stdout.writeln('');
  stdout.writeln('Findings');
  for (final finding in findings) {
    final status =
        finding.requiresExplanation
            ? finding.explanation == null
                ? 'requires explanation'
                : 'explained'
            : 'warning';
    stdout.writeln('- [$status] ${finding.path}: ${finding.lineCount} lines');
    if (finding.explanation case final explanation?) {
      stdout.writeln('  reason: $explanation');
    }
  }

  if (missingExplanations.isNotEmpty && strict) {
    exitCode = 1;
  } else if (missingExplanations.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln(
      'Report mode only: rerun with --strict to fail on files '
      'missing > $_requiresExplanationThreshold-line explanations.',
    );
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

Iterable<_FileSizeFinding> _findLargeFiles(Directory root) sync* {
  final libDirectory = Directory(p.join(root.path, 'lib'));
  if (!libDirectory.existsSync()) {
    return;
  }

  final files = libDirectory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => !_isGeneratedDart(file.path))
      .toList(growable: false)
    ..sort((left, right) => left.path.compareTo(right.path));

  for (final file in files) {
    final relativePath = p.relative(file.path, from: root.path);
    final lineCount = file.readAsLinesSync().length;
    if (lineCount <= _warningThreshold) {
      continue;
    }
    yield _FileSizeFinding(
      path: relativePath,
      lineCount: lineCount,
      requiresExplanation: lineCount > _requiresExplanationThreshold,
      explanation: _largeFileExplanations[relativePath],
    );
  }
}

bool _isGeneratedDart(String path) {
  return path.endsWith('.g.dart') ||
      path.endsWith('.freezed.dart') ||
      path.endsWith('.mocks.dart') ||
      path.endsWith('.gr.dart');
}
