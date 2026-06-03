import 'dart:io';

import 'package:path/path.dart' as p;

const Set<String> _approvedJsonBackedPreferenceWrites = <String>{
  'lib/app/navigation/bottom_nav_icon_gallery_service.dart|_galleriesKey',
  'lib/features/mine/application/advanced_theme_service.dart|_activeThemeAppearanceSnapshotKey',
  'lib/features/reader/application/local/txt_chapter_rule_service.dart|_ruleStorageKey',
  'lib/features/reader/application/reader_preferences_service.dart|_customBackgroundImagesKey',
  'lib/features/reader/application/reader_preferences_service.dart|_recentBodyTextColorsKey',
  'lib/features/reader/application/reader_visual_overrides_service.dart|_visualOverridesKey',
  'lib/features/search/application/search_history_service.dart|_storageKey',
};

const Set<String> _approvedTemporaryDirectoryUsages = <String>{
  'lib/core/logging/diagnostic_log_export_service_io.dart|getTemporaryDirectory',
  'lib/data/datasources/local/app_database_connection_native.dart|Directory.systemTemp',
  'lib/features/mine/application/advanced_theme_service.dart|Directory.systemTemp.createTemp',
  'lib/features/mine/presentation/advanced_theme_list_page.dart|getTemporaryDirectory',
};

const Set<String> _approvedStartupCleanupUsages = <String>{};

const Set<String> _approvedManagedDirectoryUsages = <String>{
  'lib/features/mine/application/advanced_theme_service.dart|advanced_themes',
  'lib/features/mine/application/mine_page_session_service.dart|profile_avatars',
};

final RegExp _dartImportSharedPreferencesPattern = RegExp(
  "package:shared_preferences/shared_preferences.dart",
);

final RegExp _temporaryDirectoryPattern = RegExp(
  r'\b(getTemporaryDirectory|Directory\.systemTemp(?:\.createTemp)?)\b',
);

final RegExp _startupCleanupPattern = RegExp(
  r'\b(clearAllCaches|clearPersistedChapterLayouts|prunePersistedChapterLayouts(?:ByBudget)?|compact|clearAll)\s*\(',
);

final RegExp _managedDirectoryPattern = RegExp(
  r'''['"]([^'"]*(advanced_themes|profile_avatars)[^'"]*)['"]''',
);

final class _StorageIssue {
  const _StorageIssue({
    required this.kind,
    required this.path,
    required this.line,
    required this.id,
    required this.message,
  });

  final String kind;
  final String path;
  final int line;
  final String id;
  final String message;
}

final class _JsonPreferenceWrite {
  const _JsonPreferenceWrite({
    required this.path,
    required this.line,
    required this.keyExpression,
    required this.valueExpression,
  });

  final String path;
  final int line;
  final String keyExpression;
  final String valueExpression;

  String get id => '$path|$keyExpression';
}

void main(List<String> args) {
  final root = _parseRoot(args);
  final jsonWrites = _findJsonBackedPreferenceWrites(root);
  final tempUsages = _findTemporaryDirectoryUsages(root);
  final startupCleanups = _findStartupCleanupUsages(root);
  final managedDirectoryUsages = _findManagedDirectoryUsages(root);

  final violations = <_StorageIssue>[
    ...jsonWrites
        .where((item) => !_approvedJsonBackedPreferenceWrites.contains(item.id))
        .map(
          (item) => _StorageIssue(
            kind: 'prefs-json',
            path: item.path,
            line: item.line,
            id: item.id,
            message: 'key=${item.keyExpression} value=${item.valueExpression}',
          ),
        ),
    ...tempUsages.where(
      (item) => !_approvedTemporaryDirectoryUsages.contains(item.id),
    ),
    ...startupCleanups.where(
      (item) => !_approvedStartupCleanupUsages.contains(item.id),
    ),
    ...managedDirectoryUsages.where(
      (item) => !_approvedManagedDirectoryUsages.contains(item.id),
    ),
  ]..sort(_compareIssues);

  final warnings = <String>[
    ..._staleBaselineWarnings(
      approved: _approvedJsonBackedPreferenceWrites,
      detected: jsonWrites.map((item) => item.id).toSet(),
      label: 'prefs json baseline',
    ),
    ..._staleBaselineWarnings(
      approved: _approvedTemporaryDirectoryUsages,
      detected: tempUsages.map((item) => item.id).toSet(),
      label: 'temporary directory baseline',
    ),
    ..._staleBaselineWarnings(
      approved: _approvedStartupCleanupUsages,
      detected: startupCleanups.map((item) => item.id).toSet(),
      label: 'startup cleanup baseline',
    ),
    ..._staleBaselineWarnings(
      approved: _approvedManagedDirectoryUsages,
      detected: managedDirectoryUsages.map((item) => item.id).toSet(),
      label: 'managed directory baseline',
    ),
  ]..sort();

  stdout.writeln('==> Storage governance guard');
  stdout.writeln('Root : ${root.path}');
  stdout.writeln('JSON-backed SharedPreferences writes: ${jsonWrites.length}');
  stdout.writeln('Temporary/cache directory usages: ${tempUsages.length}');
  stdout.writeln('Startup cleanup call sites: ${startupCleanups.length}');
  stdout.writeln(
    'Managed directory direct usages: ${managedDirectoryUsages.length}',
  );

  if (warnings.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('Warnings');
    for (final item in warnings) {
      stdout.writeln('- $item');
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('');
    stdout.writeln('No new storage governance violations found.');
    return;
  }

  stdout.writeln('');
  stdout.writeln('Violations');
  for (final item in violations) {
    stdout.writeln(
      '- [${item.kind}] ${item.path}:${item.line} ${item.message}',
    );
  }
  stdout.writeln('');
  stdout.writeln(
    'New storage persistence, temporary-directory, or startup-cleanup patterns must be reviewed before merge.',
  );
  stdout.writeln(
    'Prefer managed assets / support-documents directories / explicit cache services, and update the baseline only with storage rationale.',
  );
  exitCode = 1;
}

Directory _parseRoot(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--root=')) {
      return Directory(arg.substring('--root='.length).trim());
    }
  }
  return Directory.current;
}

List<String> _staleBaselineWarnings({
  required Set<String> approved,
  required Set<String> detected,
  required String label,
}) {
  final stale = approved.difference(detected).toList(growable: false)..sort();
  return stale
      .map((item) => '$label entry no longer detected, consider cleanup: $item')
      .toList(growable: false);
}

int _compareIssues(_StorageIssue left, _StorageIssue right) {
  final kindCompare = left.kind.compareTo(right.kind);
  if (kindCompare != 0) {
    return kindCompare;
  }
  final pathCompare = left.path.compareTo(right.path);
  if (pathCompare != 0) {
    return pathCompare;
  }
  return left.line.compareTo(right.line);
}

List<_JsonPreferenceWrite> _findJsonBackedPreferenceWrites(Directory root) {
  final writes = <_JsonPreferenceWrite>[];
  for (final file in _dartFilesUnder(root, 'lib')) {
    final relativePath = p.relative(file.path, from: root.path);
    final content = file.readAsStringSync();
    if (!_dartImportSharedPreferencesPattern.hasMatch(content)) {
      continue;
    }
    final lines = content.split('\n');
    for (var index = 0; index < lines.length; index++) {
      if (!lines[index].contains('.setString(')) {
        continue;
      }
      final invocation = _collectInvocation(lines, index);
      if (invocation == null) {
        continue;
      }
      final arguments = _extractInvocationArguments(invocation);
      if (arguments == null || arguments.length < 2) {
        continue;
      }
      final keyExpression = arguments.first.trim();
      final valueExpression = arguments[1].trim();
      if (!_isJsonBackedValue(valueExpression, lines, index)) {
        continue;
      }
      writes.add(
        _JsonPreferenceWrite(
          path: relativePath,
          line: index + 1,
          keyExpression: keyExpression,
          valueExpression: valueExpression.replaceAll(RegExp(r'\s+'), ' '),
        ),
      );
    }
  }
  writes.sort((left, right) {
    final pathCompare = left.path.compareTo(right.path);
    if (pathCompare != 0) {
      return pathCompare;
    }
    return left.line.compareTo(right.line);
  });
  return writes;
}

List<_StorageIssue> _findTemporaryDirectoryUsages(Directory root) {
  return _scanPatternUsages(
    root: root,
    relativePath: 'lib',
    pattern: _temporaryDirectoryPattern,
    kind: 'temp-dir',
    idBuilder: (path, match) => '$path|${match.group(1)!}',
    messageBuilder:
        (path, match) =>
            'temporary/cache directory usage detected: ${match.group(1)!}',
  );
}

List<_StorageIssue> _findStartupCleanupUsages(Directory root) {
  return _scanPatternUsages(
    root: root,
    relativePath: 'lib/app',
    pattern: _startupCleanupPattern,
    kind: 'startup-cleanup',
    idBuilder: (path, match) => '$path|${match.group(1)!}',
    messageBuilder:
        (path, match) => 'startup cleanup call detected: ${match.group(1)!}()',
  );
}

List<_StorageIssue> _findManagedDirectoryUsages(Directory root) {
  final issues = _scanPatternUsages(
    root: root,
    relativePath: 'lib',
    pattern: _managedDirectoryPattern,
    kind: 'managed-dir',
    idBuilder: (path, match) => '$path|${match.group(2)!}',
    messageBuilder:
        (path, match) =>
            'direct managed directory path usage detected: ${match.group(1)!}',
  );
  return issues
      .where((item) => !_looksLikeManagedDirectoryFalsePositive(item.message))
      .toList(growable: false);
}

bool _looksLikeManagedDirectoryFalsePositive(String message) {
  return message.contains('advanced_themes_batch_');
}

List<_StorageIssue> _scanPatternUsages({
  required Directory root,
  required String relativePath,
  required RegExp pattern,
  required String kind,
  required String Function(String path, RegExpMatch match) idBuilder,
  required String Function(String path, RegExpMatch match) messageBuilder,
}) {
  final issues = <_StorageIssue>[];
  for (final file in _dartFilesUnder(root, relativePath)) {
    final relativeFilePath = p.relative(file.path, from: root.path);
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final match = pattern.firstMatch(line);
      if (match == null) {
        continue;
      }
      issues.add(
        _StorageIssue(
          kind: kind,
          path: relativeFilePath,
          line: index + 1,
          id: idBuilder(relativeFilePath, match),
          message: messageBuilder(relativeFilePath, match),
        ),
      );
    }
  }
  issues.sort(_compareIssues);
  return issues;
}

String? _collectInvocation(List<String> lines, int startIndex) {
  final buffer = StringBuffer();
  var balance = 0;
  var foundOpen = false;

  for (
    var index = startIndex;
    index < lines.length && index < startIndex + 20;
    index++
  ) {
    final line = lines[index];
    buffer.writeln(line);

    for (var charIndex = 0; charIndex < line.length; charIndex++) {
      final char = line[charIndex];
      if (char == '(') {
        balance++;
        foundOpen = true;
      } else if (char == ')') {
        balance--;
      }
    }

    if (foundOpen && balance <= 0 && line.contains(');')) {
      return buffer.toString();
    }
  }

  return null;
}

List<String>? _extractInvocationArguments(String invocation) {
  final marker = '.setString(';
  final markerIndex = invocation.indexOf(marker);
  if (markerIndex == -1) {
    return null;
  }
  final openIndex = invocation.indexOf('(', markerIndex);
  if (openIndex == -1) {
    return null;
  }
  final closeIndex = _findMatchingParen(invocation, openIndex);
  if (closeIndex == -1) {
    return null;
  }
  final argsSource = invocation.substring(openIndex + 1, closeIndex);
  return _splitTopLevelArgs(argsSource);
}

int _findMatchingParen(String source, int openIndex) {
  var depth = 0;
  for (var index = openIndex; index < source.length; index++) {
    final char = source[index];
    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
      if (depth == 0) {
        return index;
      }
    }
  }
  return -1;
}

List<String> _splitTopLevelArgs(String source) {
  final args = <String>[];
  final buffer = StringBuffer();
  var parenDepth = 0;
  var bracketDepth = 0;
  var braceDepth = 0;
  String? quote;

  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    if (quote != null) {
      buffer.write(char);
      if (char == quote && !_isEscaped(source, index)) {
        quote = null;
      }
      continue;
    }

    if (char == '\'' || char == '"') {
      quote = char;
      buffer.write(char);
      continue;
    }

    if (char == '(') {
      parenDepth++;
    } else if (char == ')') {
      parenDepth--;
    } else if (char == '[') {
      bracketDepth++;
    } else if (char == ']') {
      bracketDepth--;
    } else if (char == '{') {
      braceDepth++;
    } else if (char == '}') {
      braceDepth--;
    }

    if (char == ',' &&
        parenDepth == 0 &&
        bracketDepth == 0 &&
        braceDepth == 0) {
      args.add(buffer.toString());
      buffer.clear();
      continue;
    }

    buffer.write(char);
  }

  if (buffer.isNotEmpty) {
    args.add(buffer.toString());
  }
  return args;
}

bool _isEscaped(String source, int index) {
  var slashCount = 0;
  for (var cursor = index - 1; cursor >= 0; cursor--) {
    if (source[cursor] != r'\') {
      break;
    }
    slashCount++;
  }
  return slashCount.isOdd;
}

bool _isJsonBackedValue(
  String valueExpression,
  List<String> lines,
  int invocationLineIndex,
) {
  if (valueExpression.contains('jsonEncode(')) {
    return true;
  }

  final simpleIdentifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
  if (!simpleIdentifier.hasMatch(valueExpression)) {
    return false;
  }

  final escapedIdentifier = RegExp.escape(valueExpression);
  final assignmentPattern = RegExp(
    '\\b$escapedIdentifier\\s*=\\s*jsonEncode\\(',
  );
  final start = invocationLineIndex - 20 < 0 ? 0 : invocationLineIndex - 20;
  for (var index = start; index <= invocationLineIndex; index++) {
    if (assignmentPattern.hasMatch(lines[index])) {
      return true;
    }
  }

  return false;
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
