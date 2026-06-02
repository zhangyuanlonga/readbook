import 'dart:io';

import 'package:path/path.dart' as p;

final RegExp _toJsonPattern = RegExp(r'\btoJson\s*\(');
final RegExp _fromJsonPattern = RegExp(r'\bfromJson\s*\(');
final RegExp _copyWithPattern = RegExp(r'\bcopyWith\s*\(');
final RegExp _equalityPattern = RegExp(r'operator\s*==|hashCode\b');
final RegExp _sharedPreferencesPattern = RegExp(
  r'\bSharedPreferences\b|shared_preferences|prefs\.(?:get|set|remove|containsKey)',
);
final RegExp _jsonPattern = RegExp(r'\bjson(?:Decode|Encode)\s*\(');
final RegExp _adaptivePattern = RegExp(
  r'\bAppLayout\b|\bAppAdaptiveMetrics\b|Adaptive(?:SplitBody|OverflowToolbar|ContentContainer|ActionSurface|Dialog|Card|SearchBar)',
);
final RegExp _platformPattern = RegExp(
  r'\bkIsWeb\b|\bdefaultTargetPlatform\b|\bTargetPlatform\b|\bPlatform\.',
);

const List<String> _allowedSharedPreferencesImportPrefixes = <String>[
  'lib/app/',
  'lib/core/',
  'lib/features/mine/providers.dart',
  'lib/features/announcement/application/',
  'lib/features/bookshelf/application/',
  'lib/features/home/application/',
  'lib/features/mine/application/',
  'lib/features/reader/application/',
  'lib/features/search/application/',
  'lib/features/source/application/',
];

void main(List<String> args) {
  final root = _parseRoot(args);
  final libFiles = _dartFiles(root, 'lib');
  final testFiles = _dartFiles(root, 'test');
  final allProductionFiles = libFiles.where(_isNotGenerated).toList();
  final allTestFiles = testFiles.where(_isNotGenerated).toList();
  final productionStats = _collectStats(allProductionFiles);
  final testStats = _collectStats(allTestFiles);
  final largeFiles = _largeFiles(allProductionFiles, root.path);
  final sharedPreferencesImportFiles =
      allProductionFiles
          .where(
            (file) => file.readAsStringSync().contains(
              "package:shared_preferences/shared_preferences.dart",
            ),
          )
          .map((file) => p.relative(file.path, from: root.path))
          .toList()
        ..sort();
  final oversizedPresentationFiles =
      allProductionFiles
          .map((file) {
            final relativePath = p.relative(file.path, from: root.path);
            return _LargeFile(
              path: relativePath,
              lines: file.readAsLinesSync().length,
            );
          })
          .where(
            (item) => item.path.contains('/presentation/') && item.lines > 1500,
          )
          .toList()
        ..sort((left, right) => right.lines.compareTo(left.lines));
  final unclassifiedSharedPreferencesImports = sharedPreferencesImportFiles
      .where(
        (path) => !_allowedSharedPreferencesImportPrefixes.any(path.startsWith),
      )
      .toList(growable: false);
  final presentationPlatformBranches = _presentationPlatformBranches(
    allProductionFiles,
    root.path,
  );

  stdout.writeln('==> Codebase engineering baseline');
  stdout.writeln('Root : ${root.path}');
  stdout.writeln('');
  stdout.writeln('Files');
  stdout.writeln('- lib Dart files: ${allProductionFiles.length}');
  stdout.writeln('- test Dart files: ${allTestFiles.length}');
  stdout.writeln('- lib lines: ${productionStats.lines}');
  stdout.writeln('- test lines: ${testStats.lines}');
  stdout.writeln('- lib files >= 1000 lines: ${largeFiles.length}');
  stdout.writeln('');
  stdout.writeln('Signals');
  stdout.writeln('- toJson matches: ${productionStats.toJsonMatches}');
  stdout.writeln('- fromJson matches: ${productionStats.fromJsonMatches}');
  stdout.writeln('- copyWith matches: ${productionStats.copyWithMatches}');
  stdout.writeln('- equality/hash matches: ${productionStats.equalityMatches}');
  stdout.writeln(
    '- SharedPreferences related matches: ${productionStats.sharedPreferencesMatches}',
  );
  stdout.writeln(
    '- jsonEncode/jsonDecode matches: ${productionStats.jsonMatches}',
  );
  stdout.writeln(
    '- adaptive layout matches: ${productionStats.adaptiveMatches}',
  );
  stdout.writeln(
    '- platform branch matches: ${productionStats.platformMatches}',
  );
  stdout.writeln(
    '- lib files importing shared_preferences: ${sharedPreferencesImportFiles.length}',
  );
  stdout.writeln('');
  stdout.writeln('Largest lib Dart files');
  for (final item in largeFiles.take(10)) {
    stdout.writeln('- ${item.path}: ${item.lines}');
  }
  stdout.writeln('');
  stdout.writeln('Rule report');
  stdout.writeln(
    '- presentation files > 1500 lines: ${oversizedPresentationFiles.length}',
  );
  for (final item in oversizedPresentationFiles.take(10)) {
    stdout.writeln('  - ${item.path}: ${item.lines}');
  }
  stdout.writeln(
    '- unclassified shared_preferences imports: ${unclassifiedSharedPreferencesImports.length}',
  );
  for (final path in unclassifiedSharedPreferencesImports.take(10)) {
    stdout.writeln('  - $path');
  }
  stdout.writeln(
    '- presentation platform branch call sites: ${presentationPlatformBranches.length}',
  );
  for (final item in presentationPlatformBranches.take(10)) {
    stdout.writeln('  - ${item.path}:${item.line} ${item.snippet}');
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

List<File> _dartFiles(Directory root, String relativePath) {
  final directory = Directory(p.join(root.path, relativePath));
  if (!directory.existsSync()) {
    return const <File>[];
  }
  return directory
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList()
    ..sort((left, right) => left.path.compareTo(right.path));
}

bool _isNotGenerated(File file) {
  final name = p.basename(file.path);
  return !name.endsWith('.g.dart') &&
      !name.endsWith('.freezed.dart') &&
      !name.endsWith('.types.temp.dart');
}

_CodebaseStats _collectStats(List<File> files) {
  var lines = 0;
  var toJsonMatches = 0;
  var fromJsonMatches = 0;
  var copyWithMatches = 0;
  var equalityMatches = 0;
  var sharedPreferencesMatches = 0;
  var jsonMatches = 0;
  var adaptiveMatches = 0;
  var platformMatches = 0;

  for (final file in files) {
    final content = file.readAsStringSync();
    lines += content.isEmpty ? 0 : content.split('\n').length;
    toJsonMatches += _toJsonPattern.allMatches(content).length;
    fromJsonMatches += _fromJsonPattern.allMatches(content).length;
    copyWithMatches += _copyWithPattern.allMatches(content).length;
    equalityMatches += _equalityPattern.allMatches(content).length;
    sharedPreferencesMatches +=
        _sharedPreferencesPattern.allMatches(content).length;
    jsonMatches += _jsonPattern.allMatches(content).length;
    adaptiveMatches += _adaptivePattern.allMatches(content).length;
    platformMatches += _platformPattern.allMatches(content).length;
  }

  return _CodebaseStats(
    lines: lines,
    toJsonMatches: toJsonMatches,
    fromJsonMatches: fromJsonMatches,
    copyWithMatches: copyWithMatches,
    equalityMatches: equalityMatches,
    sharedPreferencesMatches: sharedPreferencesMatches,
    jsonMatches: jsonMatches,
    adaptiveMatches: adaptiveMatches,
    platformMatches: platformMatches,
  );
}

List<_LargeFile> _largeFiles(List<File> files, String rootPath) {
  final items = <_LargeFile>[];
  for (final file in files) {
    final lines = file.readAsLinesSync().length;
    if (lines >= 1000) {
      items.add(
        _LargeFile(path: p.relative(file.path, from: rootPath), lines: lines),
      );
    }
  }
  items.sort((left, right) {
    final lineCompare = right.lines.compareTo(left.lines);
    if (lineCompare != 0) {
      return lineCompare;
    }
    return left.path.compareTo(right.path);
  });
  return items;
}

List<_LineFinding> _presentationPlatformBranches(
  List<File> files,
  String rootPath,
) {
  final findings = <_LineFinding>[];
  for (final file in files) {
    final relativePath = p.relative(file.path, from: rootPath);
    if (!relativePath.contains('/presentation/')) {
      continue;
    }
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      if (!_platformPattern.hasMatch(line)) {
        continue;
      }
      findings.add(
        _LineFinding(path: relativePath, line: index + 1, snippet: line.trim()),
      );
    }
  }
  findings.sort((left, right) {
    final pathCompare = left.path.compareTo(right.path);
    if (pathCompare != 0) {
      return pathCompare;
    }
    return left.line.compareTo(right.line);
  });
  return findings;
}

final class _CodebaseStats {
  const _CodebaseStats({
    required this.lines,
    required this.toJsonMatches,
    required this.fromJsonMatches,
    required this.copyWithMatches,
    required this.equalityMatches,
    required this.sharedPreferencesMatches,
    required this.jsonMatches,
    required this.adaptiveMatches,
    required this.platformMatches,
  });

  final int lines;
  final int toJsonMatches;
  final int fromJsonMatches;
  final int copyWithMatches;
  final int equalityMatches;
  final int sharedPreferencesMatches;
  final int jsonMatches;
  final int adaptiveMatches;
  final int platformMatches;
}

final class _LargeFile {
  const _LargeFile({required this.path, required this.lines});

  final String path;
  final int lines;
}

final class _LineFinding {
  const _LineFinding({
    required this.path,
    required this.line,
    required this.snippet,
  });

  final String path;
  final int line;
  final String snippet;
}
