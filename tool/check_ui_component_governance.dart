import 'dart:io';

const _scanRoots = <String>[
  'lib/app',
  'lib/features',
  'lib/core/app_update',
  'lib/core/media',
  'lib/core/webview',
];

const _docPaths = <String>[
  'docs/ui_ux/app_ui_component_governance_2026_06_20.md',
  'docs/ui_ux/reader_bookshelf_ui_exemptions_2026_06_20.md',
];

const _kindLabels = <String, String>{
  'missing-doc': '缺少治理文档',
  'modal-surface': '弹层表面',
  'dialog-surface': '对话框表面',
  'feedback': '反馈提示',
  'capability-wrapper': '能力封装',
  'hardcoded-style': '硬编码样式',
  'platform-branch': '平台分支',
  'loading-state': '加载状态',
  'list-performance': '列表性能',
  'list-children': '静态列表 children',
  'scaffold': '页面脚手架',
  'layout-builder': '布局计算',
};

final class _Finding {
  const _Finding({
    required this.kind,
    required this.path,
    required this.line,
    required this.message,
  });

  final String kind;
  final String path;
  final int line;
  final String message;
}

void main(List<String> args) {
  final strictNew = args.contains('--strict-new');
  final failOnWarning = args.contains('--fail-on-warning');
  final diffOnly =
      args.contains('--diff-only') || args.contains('--changed') || strictNew;
  final verbose = args.contains('--verbose');
  final changedLines = diffOnly ? _changedDartLines() : <String, Set<int>>{};
  final findings = <_Finding>[];
  final exempted = <_Finding>[];

  if (!diffOnly) {
    for (final docPath in _docPaths) {
      if (!File(docPath).existsSync()) {
        findings.add(
          _Finding(
            kind: 'missing-doc',
            path: docPath,
            line: 1,
            message: '缺少 UI 组件治理文档。',
          ),
        );
      }
    }
  }

  for (final file in _dartFiles()) {
    final relativePath = _relativePath(file);
    if (diffOnly && !changedLines.containsKey(relativePath)) {
      continue;
    }
    final lines = file.readAsLinesSync();
    void addFinding(_Finding finding, int index) {
      if (_isExempted(lines, index, finding.kind)) {
        exempted.add(finding);
        return;
      }
      findings.add(finding);
    }

    for (var index = 0; index < lines.length; index += 1) {
      final lineNumber = index + 1;
      if (!_shouldScanLine(relativePath, lineNumber, changedLines, diffOnly)) {
        continue;
      }
      final line = lines[index];
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//')) {
        continue;
      }

      if (line.contains('showModalBottomSheet') &&
          !line.contains('showAdaptiveActionSurface') &&
          !relativePath.endsWith('adaptive_bottom_sheet.dart')) {
        addFinding(
          _Finding(
            kind: 'modal-surface',
            path: relativePath,
            line: lineNumber,
            message: '新增筛选、设置、资源选择、详情弹层优先使用 showAdaptiveActionSurface。',
          ),
          index,
        );
      }

      if (line.contains('showDialog') &&
          !relativePath.endsWith('adaptive_bottom_sheet.dart') &&
          !relativePath.endsWith('adaptive_page_scaffold.dart') &&
          !relativePath.contains('/reader/')) {
        addFinding(
          _Finding(
            kind: 'dialog-surface',
            path: relativePath,
            line: lineNumber,
            message: '检查直接 showDialog；新增页面级操作优先使用自适应表面。',
          ),
          index,
        );
      }

      if (RegExp(r'\bScaffoldMessenger\.of\s*\(').hasMatch(line) &&
          _isBusinessPresentation(relativePath)) {
        addFinding(
          _Finding(
            kind: 'feedback',
            path: relativePath,
            line: lineNumber,
            message: '面向用户的 snack、toast、行内反馈优先使用 AppFeedback。',
          ),
          index,
        );
      }

      if (_hasDirectCapabilityUse(line) &&
          _isBusinessPresentation(relativePath) &&
          !_isAllowedDirectCapabilityFile(relativePath)) {
        addFinding(
          _Finding(
            kind: 'capability-wrapper',
            path: relativePath,
            line: lineNumber,
            message: 'Flutter 原生或成熟 UI 能力应通过 app/feature wrapper 使用，避免页面直接依赖。',
          ),
          index,
        );
      }

      if (_hasHardcodedStyle(line) && _isBusinessPresentation(relativePath)) {
        addFinding(
          _Finding(
            kind: 'hardcoded-style',
            path: relativePath,
            line: lineNumber,
            message:
                '检查硬编码 Color/Colors/fontSize/BoxShadow/radius；优先使用 Theme、token 或已记录资源色。',
          ),
          index,
        );
      }

      if (_hasPresentationPlatformBranch(line) &&
          !_isAllowedPlatformBranch(relativePath)) {
        addFinding(
          _Finding(
            kind: 'platform-branch',
            path: relativePath,
            line: lineNumber,
            message: '检查页面级平台分支；优先使用能力封装或自适应指标。',
          ),
          index,
        );
      }

      if (RegExp(r'\bCircularProgressIndicator\s*\(').hasMatch(line) &&
          !_isAllowedLocalSpinner(relativePath)) {
        addFinding(
          _Finding(
            kind: 'loading-state',
            path: relativePath,
            line: lineNumber,
            message: '检查页面级 spinner；阻塞内容时优先使用 AppStatusStateCard 或业务状态组件。',
          ),
          index,
        );
      }

      if (RegExp(r'\bshrinkWrap\s*:\s*true\b').hasMatch(line) &&
          _isBusinessPresentation(relativePath)) {
        addFinding(
          _Finding(
            kind: 'list-performance',
            path: relativePath,
            line: lineNumber,
            message: '检查滚动 UI 中的 shrinkWrap:true；长列表应保持懒加载和边界约束。',
          ),
          index,
        );
      }

      if (RegExp(r'\bListView\s*\(\s*$').hasMatch(line) ||
          RegExp(r'\bListView\s*\(\s*children\s*:').hasMatch(line)) {
        addFinding(
          _Finding(
            kind: 'list-children',
            path: relativePath,
            line: lineNumber,
            message:
                '检查 ListView(children)；长列表应使用 ListView.builder 或 SliverList。',
          ),
          index,
        );
      }

      if (RegExp(r'\bScaffold\s*\(').hasMatch(line) &&
          !_isAllowedScaffold(relativePath)) {
        addFinding(
          _Finding(
            kind: 'scaffold',
            path: relativePath,
            line: lineNumber,
            message: '新增页面优先使用 AdaptivePageScaffold，或记录自定义 Scaffold 的原因。',
          ),
          index,
        );
      }
    }

    for (final finding in _layoutBuilderSideEffectFindings(
      relativePath,
      lines,
      changedLines: changedLines,
      diffOnly: diffOnly,
    )) {
      final index = (finding.line - 1).clamp(0, lines.length - 1).toInt();
      if (_isExempted(lines, index, finding.kind)) {
        exempted.add(finding);
      } else {
        findings.add(finding);
      }
    }
  }

  stdout.writeln('==> UI component governance checks');
  stdout.writeln(
    'Mode: ${strictNew
        ? 'strict-new gate'
        : diffOnly
        ? 'diff-only report'
        : 'full report'}',
  );
  stdout.writeln('Findings: ${findings.length}');
  if (exempted.isNotEmpty) {
    stdout.writeln('Exempted : ${exempted.length}');
  }

  if (findings.isNotEmpty) {
    stdout.writeln('');
    final byKind = <String, int>{};
    for (final finding in findings) {
      byKind.update(finding.kind, (value) => value + 1, ifAbsent: () => 1);
    }
    stdout.writeln('Summary (问题汇总)');
    for (final entry
        in byKind.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
      stdout.writeln('- ${_formatKind(entry.key)}: ${entry.value}');
    }

    stdout.writeln('');
    stdout.writeln(
      verbose ? 'Details (全部详情)' : 'Sample details (样例，使用 --verbose 查看全部)',
    );
    final visibleFindings = verbose ? findings : findings.take(40);
    for (final finding in visibleFindings) {
      stdout.writeln(
        '- [${_formatKind(finding.kind)}] '
        '${finding.path}:${finding.line}: ${finding.message}',
      );
    }
    if (!verbose && findings.length > 40) {
      stdout.writeln('- ... ${findings.length - 40} more finding(s) hidden');
    }
  }

  final shouldFail =
      failOnWarning ||
      (strictNew && findings.any((finding) => _isBlockingFinding(finding)));
  if (findings.isNotEmpty && shouldFail) {
    exitCode = 1;
  }
}

bool _isBlockingFinding(_Finding finding) {
  return switch (finding.kind) {
    'modal-surface' ||
    'dialog-surface' ||
    'capability-wrapper' ||
    'loading-state' ||
    'scaffold' => true,
    _ => false,
  };
}

bool _isExempted(List<String> lines, int index, String kind) {
  if (_hasFileExemption(lines, kind)) {
    return true;
  }
  final start = (index - 4).clamp(0, lines.length).toInt();
  final end = (index + 1).clamp(0, lines.length).toInt();
  for (final line in lines.sublist(start, end)) {
    if (!_isExemptionLineForKind(line, kind)) {
      continue;
    }
    return true;
  }
  return false;
}

bool _hasFileExemption(List<String> lines, String kind) {
  final headerEnd = lines.length < 24 ? lines.length : 24;
  for (final line in lines.take(headerEnd)) {
    if (!line.contains('UI-GOV-EXEMPT-FILE')) {
      continue;
    }
    if (_isExemptionLineForKind(line, kind)) {
      return true;
    }
  }
  return false;
}

bool _isExemptionLineForKind(String line, String kind) {
  if (!line.contains('UI-GOV-EXEMPT')) {
    return false;
  }
  return line.contains(kind) ||
      line.contains('all') ||
      line.contains('theme-asset') ||
      line.contains('fixed-visual');
}

Iterable<File> _dartFiles() sync* {
  for (final root in _scanRoots) {
    final entity = File(root);
    if (entity.existsSync()) {
      yield entity;
      continue;
    }
    final directory = Directory(root);
    if (!directory.existsSync()) {
      continue;
    }
    yield* directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
  }
}

List<_Finding> _layoutBuilderSideEffectFindings(
  String relativePath,
  List<String> lines, {
  required Map<String, Set<int>> changedLines,
  required bool diffOnly,
}) {
  final findings = <_Finding>[];
  for (var index = 0; index < lines.length; index += 1) {
    final lineNumber = index + 1;
    if (!_shouldScanLine(relativePath, lineNumber, changedLines, diffOnly)) {
      continue;
    }
    if (!lines[index].contains('LayoutBuilder')) {
      continue;
    }
    final end = (index + 24).clamp(0, lines.length);
    final snippet = lines.sublist(index, end).join('\n');
    if (RegExp(
      r'\b(setState|await |Future\.|ref\.read|context\.go|context\.push)\b',
    ).hasMatch(snippet)) {
      findings.add(
        _Finding(
          kind: 'layout-builder',
          path: relativePath,
          line: lineNumber,
          message: '检查 LayoutBuilder body 是否包含副作用或重计算；这里应只做布局计算。',
        ),
      );
    }
  }
  return findings;
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

Map<String, Set<int>> _changedDartLines() {
  final changed = <String, Set<int>>{};
  _collectChangedLinesFromDiff(changed, const [
    'diff',
    '--unified=0',
    '--no-ext-diff',
    '--',
    '*.dart',
  ]);
  _collectChangedLinesFromDiff(changed, const [
    'diff',
    '--cached',
    '--unified=0',
    '--no-ext-diff',
    '--',
    '*.dart',
  ]);

  final untracked = Process.runSync('git', const [
    'ls-files',
    '--others',
    '--exclude-standard',
    '--',
    '*.dart',
  ], runInShell: false);
  if (untracked.exitCode == 0) {
    for (final rawPath in '${untracked.stdout}'.split('\n')) {
      final path = rawPath.trim();
      if (path.isEmpty || !File(path).existsSync()) {
        continue;
      }
      final lineCount = File(path).readAsLinesSync().length;
      changed[path] = <int>{for (var line = 1; line <= lineCount; line++) line};
    }
  }
  return changed;
}

void _collectChangedLinesFromDiff(
  Map<String, Set<int>> changed,
  List<String> arguments,
) {
  final result = Process.runSync('git', arguments, runInShell: false);
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
    if (line.startsWith('-') || line.startsWith('\\')) {
      continue;
    }
    nextLine += 1;
  }
}

bool _isAllowedLocalSpinner(String path) {
  return path.contains('/reader/') ||
      path.contains('/app/widgets/import_export_task') ||
      path.contains('/app/widgets/foundation/') ||
      path.endsWith('adaptive_setting_tile.dart') ||
      path.endsWith('runtime_feedback_card.dart') ||
      path.endsWith('search_progress_card.dart');
}

bool _isAllowedScaffold(String path) {
  return path.endsWith('adaptive_page_scaffold.dart') ||
      path.endsWith('shell_scaffold.dart') ||
      path.endsWith('feature_disabled_page.dart') ||
      path.contains('/reader/') ||
      path.contains('/core/webview/') ||
      path.contains('/source/');
}

bool _hasPresentationPlatformBranch(String line) {
  return RegExp(
    r'\b(kIsWeb|defaultTargetPlatform|Platform\.is(Android|IOS|MacOS|Windows|Linux))\b',
  ).hasMatch(line);
}

bool _isAllowedPlatformBranch(String path) {
  return path.contains('/platform/') ||
      path.contains('/capabilit') ||
      path.contains('/bridge') ||
      path.contains('/application/') ||
      path.startsWith('lib/core/') ||
      path.startsWith('lib/app/') ||
      path.contains('/core/webview/') ||
      path.endsWith('app_layout.dart') ||
      path.endsWith('app_adaptive.dart') ||
      path.endsWith('reader_layout_context.dart') ||
      path.endsWith('bootstrap.dart');
}

bool _isBusinessPresentation(String path) {
  return path.startsWith('lib/features/') && path.contains('/presentation/');
}

bool _hasDirectCapabilityUse(String line) {
  return RegExp(
        r'\b(RefreshIndicator|ReorderableListView|HapticFeedback|MenuAnchor|Shimmer|Slidable|CachedNetworkImage)\b',
      ).hasMatch(line) ||
      line.contains('package:flutter_animate/');
}

bool _isAllowedDirectCapabilityFile(String path) {
  return path.contains('/widgets/') && !path.endsWith('_page.dart');
}

bool _hasHardcodedStyle(String line) {
  return RegExp(
    r'\b(Color\s*\(0x|Colors\.|BoxShadow\s*\(|fontSize\s*:|BorderRadius\.circular\s*\()',
  ).hasMatch(line);
}

String _relativePath(File file) {
  final prefix = '${Directory.current.path}/';
  return file.path.startsWith(prefix)
      ? file.path.substring(prefix.length)
      : file.path;
}

String _formatKind(String kind) {
  final label = _kindLabels[kind];
  return label == null ? kind : '$kind($label)';
}
