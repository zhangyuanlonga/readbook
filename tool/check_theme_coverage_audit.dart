import 'dart:io';

import 'package:path/path.dart' as p;

const _defaultScanRoots = <String>['lib/app', 'lib/features'];

const _ignoredPathFragments = <String>[
  '/application/',
  '/domain/',
  '/data/',
  '/repositories/',
  '/providers.dart',
  '/routes.dart',
  '/app/theme/',
];

const _keyLabels = <String, String>{
  'hardcoded-color': '硬编码颜色',
  'material-color': 'Material 固定色',
  'local-alpha': '本地透明度',
  'border-radius': '本地圆角',
  'rounded-shape': '圆角形状',
  'box-shadow': '本地阴影',
  'box-decoration': '本地装饰容器',
  'shape-property': '本地形状属性',
  'card': '卡片组件',
  'button': '按钮组件',
  'input': '输入/搜索组件',
  'surface': '弹层/表面组件',
  'selection': '选择控件',
  'navigation': '导航组件',
  'theme-of': '读取 Theme',
  'color-scheme': '颜色体系',
  'component-tokens': '组件 token',
  'border-tokens': '边框 token',
  'advanced-backdrop': '高级主题背景',
  'advanced-theme': '高级主题',
};

const _kindLabels = <String, String>{
  'page': '页面',
  'widget': '组件',
  'shell': '应用壳',
  'presentation': '展示层',
};

const _riskLabels = <String, String>{
  'high': '高风险',
  'medium': '中风险',
  'low': '低风险',
};

final _patterns = <_AuditPattern>[
  _AuditPattern(
    key: 'hardcoded-color',
    regex: RegExp(r'\b(?:const\s+)?Color\s*\(\s*0x[0-9A-Fa-f]{6,8}\s*\)'),
    message: '直接 Color(0x...)；确认是否应来自主题或资源色板。',
  ),
  _AuditPattern(
    key: 'material-color',
    regex: RegExp(r'\bColors\.(?!transparent\b)[A-Za-z0-9_]+'),
    message: '直接 Colors.*；确认是否为语义色或固定视觉。',
  ),
  _AuditPattern(
    key: 'local-alpha',
    regex: RegExp(r'\.withValues\s*\(\s*alpha\s*:'),
    message: '本地透明度调整；确认是否应由语义 token 驱动。',
  ),
  _AuditPattern(
    key: 'border-radius',
    regex: RegExp(
      r'\bBorderRadius\.(?:circular|only|vertical|horizontal)\s*\(',
    ),
    message: '本地 BorderRadius；优先考虑 AppComponentThemeTokens。',
  ),
  _AuditPattern(
    key: 'rounded-shape',
    regex: RegExp(r'\bRoundedRectangleBorder\s*\('),
    message: '本地圆角形状；优先考虑组件 token。',
  ),
  _AuditPattern(
    key: 'box-shadow',
    regex: RegExp(r'\bBoxShadow\s*\('),
    message: '本地 BoxShadow；优先考虑组件阴影 token 或固定视觉豁免。',
  ),
  _AuditPattern(
    key: 'box-decoration',
    regex: RegExp(r'\bBoxDecoration\s*\('),
    message: '本地 BoxDecoration；检查背景、边框、圆角、阴影是否应组件化。',
  ),
  _AuditPattern(
    key: 'shape-property',
    regex: RegExp(r'\bshape\s*:'),
    message: '本地 shape 属性；确认是否已有 token 覆盖。',
  ),
];

final _componentPatterns = <_AuditPattern>[
  _AuditPattern(key: 'card', regex: RegExp(r'\b(?:Card|AdaptiveCard)\s*\(')),
  _AuditPattern(
    key: 'button',
    regex: RegExp(r'\b(?:FilledButton|OutlinedButton|TextButton)\s*\.'),
  ),
  _AuditPattern(
    key: 'input',
    regex: RegExp(r'\b(?:TextField|TextFormField|AdaptiveSearchBar)\s*\('),
  ),
  _AuditPattern(
    key: 'surface',
    regex: RegExp(
      r'\b(?:showAdaptiveActionSurface|showModalBottomSheet|showDialog|PopupMenuButton)\b',
    ),
  ),
  _AuditPattern(
    key: 'selection',
    regex: RegExp(r'\b(?:TabBar|SegmentedButton|Chip|Switch)\s*\('),
  ),
  _AuditPattern(
    key: 'navigation',
    regex: RegExp(r'\b(?:NavigationBar|BottomNavigationBar|CupertinoDock)\b'),
  ),
];

final _themeHookPatterns = <_AuditPattern>[
  _AuditPattern(key: 'theme-of', regex: RegExp(r'\bTheme\.of\s*\(')),
  _AuditPattern(key: 'color-scheme', regex: RegExp(r'\bcolorScheme\.')),
  _AuditPattern(
    key: 'component-tokens',
    regex: RegExp(r'\bappComponentThemeTokensOf\s*\('),
  ),
  _AuditPattern(
    key: 'border-tokens',
    regex: RegExp(r'\bresolveAppBorder(?:Color|Side)\s*\('),
  ),
  _AuditPattern(
    key: 'advanced-backdrop',
    regex: RegExp(r'\bbuildAdvancedThemeBackdropDecoration\s*\('),
  ),
  _AuditPattern(
    key: 'advanced-theme',
    regex: RegExp(r'\b(?:activeAdvancedThemeProvider|resolveAdvancedTheme)'),
  ),
];

void main(List<String> args) {
  final root = _parseRoot(args);
  final verbose = args.contains('--verbose');
  final strictNew = args.contains('--strict-new');
  final diffOnly =
      args.contains('--diff-only') || args.contains('--changed') || strictNew;
  final failOnHighRisk = args.contains('--fail-on-high-risk') || strictNew;
  final top = _parseTop(args);
  final changedLines =
      diffOnly ? _changedDartLines(root) : <String, Set<int>>{};
  final files = _dartFiles(root).toList(growable: false);
  final reports = files
    .where((file) {
      if (!diffOnly) {
        return true;
      }
      final relativePath = p.relative(file.path, from: root.path);
      return changedLines.containsKey(relativePath);
    })
    .map(
      (file) => _auditFile(
        root,
        file,
        changedLines: changedLines,
        diffOnly: diffOnly,
      ),
    )
    .where((report) => report.relevant)
    .toList(growable: false)..sort((a, b) {
    final riskCompare = b.riskScore.compareTo(a.riskScore);
    if (riskCompare != 0) {
      return riskCompare;
    }
    return a.path.compareTo(b.path);
  });

  final totals = <String, int>{};
  final exemptedTotals = <String, int>{};
  for (final report in reports) {
    for (final entry in report.findingCounts.entries) {
      totals.update(
        entry.key,
        (value) => value + entry.value,
        ifAbsent: () {
          return entry.value;
        },
      );
    }
    for (final entry in report.exemptedFindingCounts.entries) {
      exemptedTotals.update(
        entry.key,
        (value) => value + entry.value,
        ifAbsent: () {
          return entry.value;
        },
      );
    }
  }

  final highRiskReports = reports.where((item) => item.riskLevel == 'high');

  stdout.writeln('==> Theme coverage audit');
  stdout.writeln('Root       : ${root.path}');
  stdout.writeln(
    'Mode       : ${strictNew
        ? 'strict-new gate'
        : diffOnly
        ? 'diff-only report'
        : 'full report'}',
  );
  stdout.writeln('Files      : ${reports.length}');
  stdout.writeln('High risk  : ${highRiskReports.length}');
  stdout.writeln('');
  stdout.writeln('Finding totals (问题汇总)');
  for (final entry
      in totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value))) {
    stdout.writeln('- ${_formatKey(entry.key)}: ${entry.value}');
  }
  if (exemptedTotals.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('Exempted finding totals (已豁免问题汇总)');
    for (final entry
        in exemptedTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value))) {
      stdout.writeln('- ${_formatKey(entry.key)}: ${entry.value}');
    }
  }

  stdout.writeln('');
  stdout.writeln(
    verbose ? 'All audited files (全部文件)' : 'Top risk files (高风险优先)',
  );
  final visibleReports = verbose ? reports : reports.take(top);
  for (final report in visibleReports) {
    stdout.writeln(_formatReport(report));
  }
  if (!verbose && reports.length > top) {
    stdout.writeln('- ... ${reports.length - top} more file(s) hidden');
  }

  if (failOnHighRisk && highRiskReports.isNotEmpty) {
    exitCode = 1;
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

int _parseTop(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--top=')) {
      return int.tryParse(arg.substring('--top='.length).trim()) ?? 25;
    }
  }
  return 25;
}

Iterable<File> _dartFiles(Directory root) sync* {
  for (final scanRoot in _defaultScanRoots) {
    final target = Directory(p.join(root.path, scanRoot));
    if (!target.existsSync()) {
      continue;
    }
    yield* target
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) {
          final relative = p.relative(file.path, from: root.path);
          return !_ignoredPathFragments.any(relative.contains);
        });
  }
}

_FileThemeReport _auditFile(
  Directory root,
  File file, {
  required Map<String, Set<int>> changedLines,
  required bool diffOnly,
}) {
  final relativePath = p.relative(file.path, from: root.path);
  final lines = file.readAsLinesSync();
  final findingCounts = <String, int>{};
  final exemptedFindingCounts = <String, int>{};
  final componentCounts = <String, int>{};
  final themeHookCounts = <String, int>{};
  final sampleFindings = <_AuditFinding>[];

  for (var index = 0; index < lines.length; index += 1) {
    final lineNumber = index + 1;
    if (!_shouldScanLine(relativePath, lineNumber, changedLines, diffOnly)) {
      continue;
    }
    final line = lines[index];
    if (_isCommentOnly(line)) {
      continue;
    }
    for (final pattern in _patterns) {
      if (!pattern.regex.hasMatch(line)) {
        continue;
      }
      final count = pattern.regex.allMatches(line).length;
      if (_isExempted(lines, index, pattern.key)) {
        exemptedFindingCounts.update(
          pattern.key,
          (value) => value + count,
          ifAbsent: () {
            return count;
          },
        );
        continue;
      }
      findingCounts.update(
        pattern.key,
        (value) => value + count,
        ifAbsent: () {
          return count;
        },
      );
      if (sampleFindings.length < 8) {
        sampleFindings.add(
          _AuditFinding(
            key: pattern.key,
            line: lineNumber,
            message: pattern.message,
          ),
        );
      }
    }
    for (final pattern in _componentPatterns) {
      if (pattern.regex.hasMatch(line)) {
        componentCounts.update(
          pattern.key,
          (value) => value + 1,
          ifAbsent: () {
            return 1;
          },
        );
      }
    }
    for (final pattern in _themeHookPatterns) {
      if (pattern.regex.hasMatch(line)) {
        themeHookCounts.update(
          pattern.key,
          (value) => value + 1,
          ifAbsent: () {
            return 1;
          },
        );
      }
    }
  }

  return _FileThemeReport(
    path: relativePath,
    kind: _classifyFile(relativePath),
    findingCounts: findingCounts,
    exemptedFindingCounts: exemptedFindingCounts,
    componentCounts: componentCounts,
    themeHookCounts: themeHookCounts,
    sampleFindings: sampleFindings,
  );
}

bool _isExempted(List<String> lines, int index, String key) {
  if (_hasFileExemption(lines, key)) {
    return true;
  }
  final start = (index - 4).clamp(0, lines.length).toInt();
  final end = (index + 1).clamp(0, lines.length).toInt();
  for (final line in lines.sublist(start, end)) {
    if (!_isExemptionLineForKey(line, key)) {
      continue;
    }
    return true;
  }
  return false;
}

bool _hasFileExemption(List<String> lines, String key) {
  final headerEnd = lines.length < 24 ? lines.length : 24;
  for (final line in lines.take(headerEnd)) {
    if (!line.contains('UI-GOV-EXEMPT-FILE')) {
      continue;
    }
    if (_isExemptionLineForKey(line, key)) {
      return true;
    }
  }
  return false;
}

bool _isExemptionLineForKey(String line, String key) {
  if (!line.contains('UI-GOV-EXEMPT')) {
    return false;
  }
  return line.contains(key) ||
      line.contains('all') ||
      line.contains('theme-asset') ||
      line.contains('fixed-visual');
}

bool _shouldScanLine(
  String path,
  int line,
  Map<String, Set<int>> changedLines,
  bool diffOnly,
) {
  if (!diffOnly) {
    return true;
  }
  return changedLines[path]?.contains(line) ?? false;
}

Map<String, Set<int>> _changedDartLines(Directory root) {
  final changed = <String, Set<int>>{};
  _collectChangedLinesFromDiff(root, changed, const [
    'diff',
    '--unified=0',
    '--no-ext-diff',
    '--',
    '*.dart',
  ]);
  _collectChangedLinesFromDiff(root, changed, const [
    'diff',
    '--cached',
    '--unified=0',
    '--no-ext-diff',
    '--',
    '*.dart',
  ]);

  final untracked = Process.runSync(
    'git',
    const ['ls-files', '--others', '--exclude-standard', '--', '*.dart'],
    runInShell: false,
    workingDirectory: root.path,
  );
  if (untracked.exitCode == 0) {
    for (final rawPath in '${untracked.stdout}'.split('\n')) {
      final path = rawPath.trim();
      if (path.isEmpty) {
        continue;
      }
      final file = File(p.join(root.path, path));
      if (!file.existsSync()) {
        continue;
      }
      final lineCount = file.readAsLinesSync().length;
      changed[path] = <int>{for (var line = 1; line <= lineCount; line++) line};
    }
  }
  return changed;
}

void _collectChangedLinesFromDiff(
  Directory root,
  Map<String, Set<int>> changed,
  List<String> arguments,
) {
  final result = Process.runSync(
    'git',
    arguments,
    runInShell: false,
    workingDirectory: root.path,
  );
  if (result.exitCode != 0) {
    return;
  }
  String? currentPath;
  var nextLine = 0;
  for (final line in '${result.stdout}'.split('\n')) {
    if (line.startsWith('+++ b/')) {
      currentPath = line.substring('+++ b/'.length);
      changed.putIfAbsent(currentPath, () => <int>{});
      continue;
    }
    final hunk = RegExp(
      r'^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@',
    ).firstMatch(line);
    if (hunk != null) {
      nextLine = int.parse(hunk.group(1)!);
      continue;
    }
    if (currentPath == null || nextLine <= 0) {
      continue;
    }
    if (line.startsWith('+++') || line.startsWith('---')) {
      continue;
    }
    if (line.startsWith('+')) {
      changed[currentPath]!.add(nextLine);
      nextLine += 1;
      continue;
    }
    if (line.startsWith('-') || line.startsWith(r'\')) {
      continue;
    }
    nextLine += 1;
  }
}

bool _isCommentOnly(String line) {
  final trimmed = line.trimLeft();
  return trimmed.startsWith('//') ||
      trimmed.startsWith('*') ||
      trimmed.startsWith('/*');
}

String _classifyFile(String path) {
  if (path.endsWith('_page.dart') || path.endsWith('page.dart')) {
    return 'page';
  }
  if (path.contains('/widgets/') || path.contains('/presentation/widgets/')) {
    return 'widget';
  }
  if (path.endsWith('shell_scaffold.dart')) {
    return 'shell';
  }
  return 'presentation';
}

String _formatReport(_FileThemeReport report) {
  final risk = _formatRisk(report.riskLevel);
  final kind = _formatKind(report.kind);
  final buffer =
      StringBuffer()..writeln(
        '- [$risk] ${report.path} '
        '(score ${report.riskScore}, $kind)',
      );
  buffer.writeln('  findings (未处理): ${_formatCounts(report.findingCounts)}');
  if (report.exemptedFindingCounts.isNotEmpty) {
    buffer.writeln(
      '  exempted findings (已豁免): '
      '${_formatCounts(report.exemptedFindingCounts)}',
    );
  }
  buffer.writeln(
    '  components (涉及组件): ${_formatCounts(report.componentCounts)}',
  );
  buffer.writeln(
    '  theme hooks (主题接入): ${_formatCounts(report.themeHookCounts)}',
  );
  if (report.sampleFindings.isNotEmpty) {
    buffer.writeln('  samples (样例):');
    for (final finding in report.sampleFindings.take(4)) {
      buffer.writeln(
        '    - ${finding.line}: [${_formatKey(finding.key)}] '
        '${finding.message}',
      );
    }
  }
  return buffer.toString().trimRight();
}

String _formatCounts(Map<String, int> counts) {
  if (counts.isEmpty) {
    return 'none';
  }
  final entries =
      counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return entries
      .map((entry) => '${_formatKey(entry.key)}=${entry.value}')
      .join(', ');
}

String _formatKey(String key) {
  final label = _keyLabels[key];
  return label == null ? key : '$key($label)';
}

String _formatKind(String kind) {
  final label = _kindLabels[kind];
  return label == null ? kind : '$kind/$label';
}

String _formatRisk(String risk) {
  final label = _riskLabels[risk];
  return label == null ? risk : '$risk/$label';
}

final class _AuditPattern {
  const _AuditPattern({
    required this.key,
    required this.regex,
    this.message = '',
  });

  final String key;
  final RegExp regex;
  final String message;
}

final class _AuditFinding {
  const _AuditFinding({
    required this.key,
    required this.line,
    required this.message,
  });

  final String key;
  final int line;
  final String message;
}

final class _FileThemeReport {
  const _FileThemeReport({
    required this.path,
    required this.kind,
    required this.findingCounts,
    required this.exemptedFindingCounts,
    required this.componentCounts,
    required this.themeHookCounts,
    required this.sampleFindings,
  });

  final String path;
  final String kind;
  final Map<String, int> findingCounts;
  final Map<String, int> exemptedFindingCounts;
  final Map<String, int> componentCounts;
  final Map<String, int> themeHookCounts;
  final List<_AuditFinding> sampleFindings;

  bool get relevant {
    return findingCounts.isNotEmpty ||
        exemptedFindingCounts.isNotEmpty ||
        componentCounts.isNotEmpty ||
        themeHookCounts.isNotEmpty;
  }

  int get riskScore {
    final localStyleScore =
        (findingCounts['hardcoded-color'] ?? 0) * 4 +
        (findingCounts['material-color'] ?? 0) * 4 +
        (findingCounts['box-shadow'] ?? 0) * 5 +
        (findingCounts['border-radius'] ?? 0) * 2 +
        (findingCounts['rounded-shape'] ?? 0) * 2 +
        (findingCounts['shape-property'] ?? 0) * 2 +
        (findingCounts['box-decoration'] ?? 0) * 2 +
        (findingCounts['local-alpha'] ?? 0);
    final componentSurfaceScore = componentCounts.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final themeHookScore = themeHookCounts.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final tokenBonus =
        (themeHookCounts['component-tokens'] ?? 0) * 8 +
        (themeHookCounts['advanced-backdrop'] ?? 0) * 6 +
        (themeHookCounts['border-tokens'] ?? 0) * 4 +
        themeHookScore;
    return (localStyleScore + componentSurfaceScore - tokenBonus).clamp(
      0,
      9999,
    );
  }

  String get riskLevel {
    if (riskScore >= 60) {
      return 'high';
    }
    if (riskScore >= 24) {
      return 'medium';
    }
    return 'low';
  }
}
