import 'dart:io';

import 'package:path/path.dart' as p;

const _packagePrefix = 'package:shuxiang_reading_next/';
const _allChecks = <String>{'imports', 'large-files', 'docs'};
const _registeredLargeFileDebt = <String, int>{
  'lib/features/reader/presentation/reader_page.dart': 6012,
  'lib/features/mine/application/advanced_theme_service.dart': 3550,
};

final class _Issue {
  const _Issue({required this.kind, required this.path, required this.message});

  final String kind;
  final String path;
  final String message;
}

Future<void> main(List<String> args) async {
  final root = _parseRoot(args);
  final checks = _parseChecks(args);

  final violations = <_Issue>[];
  final warnings = <_Issue>[];

  if (checks.contains('imports')) {
    final result = _checkImports(root);
    violations.addAll(result.$1);
    warnings.addAll(result.$2);
  }

  if (checks.contains('large-files')) {
    final result = _checkLargeFiles(root);
    violations.addAll(result.$1);
    warnings.addAll(result.$2);
  }

  if (checks.contains('docs')) {
    final result = _checkProjectPlan(root);
    violations.addAll(result.$1);
    warnings.addAll(result.$2);
  }

  stdout.writeln('==> Architecture guardrail checks');
  stdout.writeln('Root   : ${root.path}');
  stdout.writeln('Checks : ${checks.join(', ')}');

  if (warnings.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('Warnings');
    for (final issue in warnings) {
      stdout.writeln('- [${issue.kind}] ${issue.path}: ${issue.message}');
    }
  }

  if (violations.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('Violations');
    for (final issue in violations) {
      stdout.writeln('- [${issue.kind}] ${issue.path}: ${issue.message}');
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

Set<String> _parseChecks(List<String> args) {
  for (final arg in args) {
    if (!arg.startsWith('--check=')) {
      continue;
    }
    final requested =
        arg
            .substring('--check='.length)
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet();
    final invalid = requested.difference(_allChecks);
    if (invalid.isNotEmpty) {
      stderr.writeln('Unknown checks: ${invalid.join(', ')}');
      exit(64);
    }
    return requested;
  }
  return _allChecks;
}

(List<_Issue>, List<_Issue>) _checkImports(Directory root) {
  final violations = <_Issue>[];
  final warnings = <_Issue>[];
  final files = _dartFilesUnder(root, 'lib');
  final importPattern = RegExp(
    r'''^\s*import\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  for (final file in files) {
    final sourcePath = p.relative(file.path, from: root.path);
    final content = file.readAsStringSync();
    final imports = importPattern
        .allMatches(content)
        .map((match) => match.group(1)!)
        .map((target) => _resolveImportTarget(sourcePath, target))
        .toList(growable: false);

    if (_isFeaturePresentationFile(sourcePath)) {
      for (final target in imports) {
        if (_isFeatureDataImport(target)) {
          violations.add(
            _Issue(
              kind: 'imports',
              path: sourcePath,
              message: 'presentation layer must not import data layer: $target',
            ),
          );
        }
        if (_isForbiddenPresentationTarget(target)) {
          violations.add(
            _Issue(
              kind: 'imports',
              path: sourcePath,
              message: 'presentation layer must not import $target directly',
            ),
          );
        }
      }

      if (RegExp(r'\b(MethodChannel|EventChannel)\s*\(').hasMatch(content)) {
        violations.add(
          _Issue(
            kind: 'imports',
            path: sourcePath,
            message:
                'presentation layer must not instantiate platform channels',
          ),
        );
      }
      if (content.contains('AppDatabase.instance')) {
        violations.add(
          _Issue(
            kind: 'imports',
            path: sourcePath,
            message: 'presentation layer must not touch AppDatabase.instance',
          ),
        );
      }
    }

    if (sourcePath.startsWith('lib/domain/')) {
      for (final target in imports) {
        if (target.startsWith('package:flutter')) {
          violations.add(
            _Issue(
              kind: 'imports',
              path: sourcePath,
              message: 'domain layer must remain pure Dart: $target',
            ),
          );
        }
        if (target.contains('/data/') || target.contains('/features/')) {
          violations.add(
            _Issue(
              kind: 'imports',
              path: sourcePath,
              message:
                  'domain layer must not depend on feature/data layer: $target',
            ),
          );
        }
      }
    }

    if (sourcePath.startsWith('lib/core/')) {
      for (final target in imports) {
        if (target.contains('/features/')) {
          violations.add(
            _Issue(
              kind: 'imports',
              path: sourcePath,
              message: 'core layer must not depend on features: $target',
            ),
          );
        }
      }
    }

    if (sourcePath.startsWith('lib/runtime/')) {
      for (final target in imports) {
        if (target.contains('/features/') &&
            target.contains('/presentation/')) {
          violations.add(
            _Issue(
              kind: 'imports',
              path: sourcePath,
              message:
                  'runtime layer must not depend on feature presentation: $target',
            ),
          );
        }
      }
    }
  }

  return (violations, warnings);
}

(List<_Issue>, List<_Issue>) _checkLargeFiles(Directory root) {
  final violations = <_Issue>[];
  final warnings = <_Issue>[];

  for (final file in _dartFilesUnder(root, 'lib/features')) {
    final relativePath = p.relative(file.path, from: root.path);
    final lineCount = file.readAsLinesSync().length;

    if (relativePath.contains('/presentation/')) {
      if (lineCount > 6000) {
        if (_isRegisteredLargeFileDebt(relativePath, lineCount)) {
          warnings.add(
            _Issue(
              kind: 'large-files',
              path: relativePath,
              message:
                  'presentation file has $lineCount lines, exceeds hard limit 6000 but is registered as split debt',
            ),
          );
        } else {
          violations.add(
            _Issue(
              kind: 'large-files',
              path: relativePath,
              message:
                  'presentation file has $lineCount lines, exceeds hard limit 6000',
            ),
          );
        }
      } else if (lineCount >= 4500) {
        warnings.add(
          _Issue(
            kind: 'large-files',
            path: relativePath,
            message:
                'presentation file has $lineCount lines, reached warning threshold 4500',
          ),
        );
      }
      continue;
    }

    if (relativePath.contains('/application/')) {
      if (lineCount > 2500) {
        if (_isRegisteredLargeFileDebt(relativePath, lineCount)) {
          warnings.add(
            _Issue(
              kind: 'large-files',
              path: relativePath,
              message:
                  'application file has $lineCount lines, exceeds hard limit 2500 but is registered as split debt',
            ),
          );
        } else {
          violations.add(
            _Issue(
              kind: 'large-files',
              path: relativePath,
              message:
                  'application file has $lineCount lines, exceeds hard limit 2500',
            ),
          );
        }
      } else if (lineCount >= 2000) {
        warnings.add(
          _Issue(
            kind: 'large-files',
            path: relativePath,
            message:
                'application file has $lineCount lines, reached warning threshold 2000',
          ),
        );
      }
    }
  }

  return (violations, warnings);
}

bool _isRegisteredLargeFileDebt(String relativePath, int lineCount) {
  final registeredLineLimit = _registeredLargeFileDebt[relativePath];
  return registeredLineLimit != null && lineCount <= registeredLineLimit;
}

(List<_Issue>, List<_Issue>) _checkProjectPlan(Directory root) {
  final planFile = File(
    p.join(root.path, 'docs', 'project_architecture_unification_plan.md'),
  );
  final violations = <_Issue>[];
  final warnings = <_Issue>[];

  if (!planFile.existsSync()) {
    violations.add(
      const _Issue(
        kind: 'docs',
        path: 'docs/project_architecture_unification_plan.md',
        message: 'project architecture unification plan is missing',
      ),
    );
    return (violations, warnings);
  }

  final relativePath = p.relative(planFile.path, from: root.path);
  final content = planFile.readAsStringSync();
  final lines = content.split('\n');
  final summaryStatuses = <String, String>{};
  var insideSummary = false;

  for (final line in lines) {
    if (line.trim() == '### 4.1 阶段状态') {
      insideSummary = true;
      continue;
    }
    if (insideSummary && line.startsWith('### ')) {
      insideSummary = false;
    }
    if (!insideSummary) {
      continue;
    }
    final match = RegExp(r'^- 阶段 (\d+)：(.+)$').firstMatch(line.trim());
    if (match != null) {
      summaryStatuses[match.group(1)!] = match.group(2)!.trim();
    }
  }

  final stagePattern = RegExp(r'^## (\d+)\. 阶段 (\d+)：', multiLine: true);
  final matches = stagePattern.allMatches(content).toList(growable: false);
  for (var index = 0; index < matches.length; index++) {
    final match = matches[index];
    final stageNumber = match.group(2)!;
    if (int.parse(stageNumber) > 6) {
      continue;
    }
    final start = match.start;
    final end =
        index + 1 < matches.length ? matches[index + 1].start : content.length;
    final section = content.substring(start, end);
    final statusMatch = RegExp(r'状态：`([^`]+)`').firstMatch(section);
    final status = statusMatch?.group(1)?.trim();
    if (status == null) {
      violations.add(
        _Issue(
          kind: 'docs',
          path: relativePath,
          message: '阶段 $stageNumber 缺少状态字段',
        ),
      );
      continue;
    }

    final summaryStatus = summaryStatuses[stageNumber];
    if (summaryStatus != null && summaryStatus != status) {
      violations.add(
        _Issue(
          kind: 'docs',
          path: relativePath,
          message: '阶段 $stageNumber 总看板状态为 $summaryStatus，但正文为 $status',
        ),
      );
    }

    if (status == '已完成') {
      if (!section.contains('完成日期：')) {
        violations.add(
          _Issue(
            kind: 'docs',
            path: relativePath,
            message: '阶段 $stageNumber 标记为已完成，但缺少完成日期',
          ),
        );
      }
      if (section.contains('- [ ]')) {
        violations.add(
          _Issue(
            kind: 'docs',
            path: relativePath,
            message: '阶段 $stageNumber 标记为已完成，但仍有未勾选任务',
          ),
        );
      }
    }

    if (status == '进行中') {
      if (!section.contains('当前剩余项：')) {
        violations.add(
          _Issue(
            kind: 'docs',
            path: relativePath,
            message: '阶段 $stageNumber 标记为进行中，但缺少当前剩余项',
          ),
        );
      } else if (!section.contains('- [ ]')) {
        warnings.add(
          _Issue(
            kind: 'docs',
            path: relativePath,
            message: '阶段 $stageNumber 标记为进行中，但当前剩余项中没有未勾选任务',
          ),
        );
      }
    }
  }

  return (violations, warnings);
}

Iterable<File> _dartFilesUnder(Directory root, String relativePath) sync* {
  final directory = Directory(p.join(root.path, relativePath));
  if (!directory.existsSync()) {
    return;
  }
  final entities = directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList(growable: false)
    ..sort((left, right) => left.path.compareTo(right.path));
  yield* entities;
}

bool _isFeaturePresentationFile(String relativePath) {
  return relativePath.startsWith('lib/features/') &&
      relativePath.contains('/presentation/') &&
      relativePath.endsWith('.dart');
}

bool _isFeatureDataImport(String target) {
  return target.startsWith('lib/') && target.contains('/data/');
}

bool _isForbiddenPresentationTarget(String target) {
  if (!target.startsWith('lib/')) {
    return false;
  }
  return target.endsWith('/app_database.dart') ||
      target.endsWith('app_database.dart') ||
      target.endsWith('_impl.dart');
}

String _resolveImportTarget(String sourcePath, String target) {
  if (target.startsWith('dart:') || target.startsWith('package:')) {
    if (target.startsWith(_packagePrefix)) {
      return 'lib/${target.substring(_packagePrefix.length)}';
    }
    return target;
  }
  return p.normalize(p.join(p.dirname(sourcePath), target));
}
