import 'dart:io';

import 'package:path/path.dart' as p;

final class _CatchFinding {
  const _CatchFinding({
    required this.path,
    required this.line,
    required this.kind,
  });

  final String path;
  final int line;
  final String kind;
}

Future<void> main(List<String> args) async {
  final root = _parseRoot(args);
  final strict = args.contains('--strict');
  final findings = _findCatchFindings(root).toList(growable: false);
  final catchUnderscoreCount =
      findings.where((finding) => finding.kind == 'catch (_)').length;
  final emptyCatchCount =
      findings.where((finding) => finding.kind == 'empty catch').length;
  final returnFalseOnlyCount =
      findings.where((finding) => finding.kind == 'return false only').length;

  stdout.writeln('==> Catch audit');
  stdout.writeln('Root : ${root.path}');
  stdout.writeln('Mode : ${strict ? 'strict' : 'report'}');
  stdout.writeln('Scope: lib/**/*.dart');
  stdout.writeln('');
  stdout.writeln('Summary');
  stdout.writeln('- catch (_)          : $catchUnderscoreCount');
  stdout.writeln('- empty catch        : $emptyCatchCount');
  stdout.writeln('- return false only  : $returnFalseOnlyCount');

  if (findings.isEmpty) {
    stdout.writeln('');
    stdout.writeln('No audited catch patterns found.');
    return;
  }

  stdout.writeln('');
  stdout.writeln('Findings');
  for (final finding in findings) {
    stdout.writeln('- [${finding.kind}] ${finding.path}:${finding.line}');
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

Iterable<_CatchFinding> _findCatchFindings(Directory root) sync* {
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

  final catchPattern = RegExp(
    r'\b(?:on\s+[A-Za-z0-9_$.<>?,\s]+\s+)?catch\s*\(([^)]*)\)\s*\{',
    multiLine: true,
  );

  for (final file in files) {
    final relativePath = p.relative(file.path, from: root.path);
    final content = file.readAsStringSync();
    for (final match in catchPattern.allMatches(content)) {
      final params = match.group(1)!.split(',').map((item) => item.trim());
      final line = _lineNumber(content, match.start);
      if (params.isNotEmpty && params.first == '_') {
        yield _CatchFinding(path: relativePath, line: line, kind: 'catch (_)');
      }

      final block = _extractBlock(content, match.end - 1);
      if (block == null) {
        continue;
      }
      final normalized = _normalizeBlockBody(block);
      if (normalized.isEmpty) {
        yield _CatchFinding(
          path: relativePath,
          line: line,
          kind: 'empty catch',
        );
      } else if (normalized == 'returnfalse;') {
        yield _CatchFinding(
          path: relativePath,
          line: line,
          kind: 'return false only',
        );
      }
    }
  }
}

String? _extractBlock(String content, int openingBraceIndex) {
  var depth = 0;
  for (var index = openingBraceIndex; index < content.length; index++) {
    final char = content.codeUnitAt(index);
    if (char == 123) {
      depth++;
    } else if (char == 125) {
      depth--;
      if (depth == 0) {
        return content.substring(openingBraceIndex + 1, index);
      }
    }
  }
  return null;
}

String _normalizeBlockBody(String body) {
  final withoutBlockComments = body.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  final withoutLineComments = withoutBlockComments.replaceAll(
    RegExp(r'//.*', multiLine: true),
    '',
  );
  return withoutLineComments.replaceAll(RegExp(r'\s+'), '');
}

bool _isGeneratedDart(String path) {
  return path.endsWith('.g.dart') ||
      path.endsWith('.freezed.dart') ||
      path.endsWith('.mocks.dart') ||
      path.endsWith('.gr.dart');
}

int _lineNumber(String content, int offset) {
  return '\n'.allMatches(content.substring(0, offset)).length + 1;
}
