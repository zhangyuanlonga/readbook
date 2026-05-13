import 'dart:io';

const _scanRoots = <String>[
  'lib/app',
  'lib/features',
  'lib/core/app_update',
  'lib/core/media',
  'lib/core/webview',
];

const _docPaths = <String>[
  'docs/page_ui_component_governance_plan_2026-05-12.md',
  'docs/page_ui_scaffold_audit_2026-05-12.md',
  'docs/page_ui_state_component_audit_2026-05-12.md',
  'docs/page_ui_modal_surface_audit_2026-05-12.md',
  'docs/adaptive_component_coverage_matrix_2026-05-13.md',
  'docs/adaptive_ui_antipatterns_2026-05-13.md',
  'docs/adaptive_legacy_page_migration_inventory_2026-05-13.md',
  'docs/adaptive_size_typography_tokens_2026-05-13.md',
];

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
  final failOnWarning = args.contains('--fail-on-warning');
  final verbose = args.contains('--verbose');
  final findings = <_Finding>[];

  for (final docPath in _docPaths) {
    if (!File(docPath).existsSync()) {
      findings.add(
        _Finding(
          kind: 'missing-doc',
          path: docPath,
          line: 1,
          message: 'UI component governance document is missing.',
        ),
      );
    }
  }

  for (final file in _dartFiles()) {
    final relativePath = _relativePath(file);
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//')) {
        continue;
      }

      if (line.contains('showModalBottomSheet') &&
          !line.contains('showAdaptiveActionSurface') &&
          !relativePath.endsWith('adaptive_bottom_sheet.dart')) {
        findings.add(
          _Finding(
            kind: 'modal-surface',
            path: relativePath,
            line: index + 1,
            message:
                'Prefer showAdaptiveActionSurface for new filter, settings, resource picker, or detail surfaces.',
          ),
        );
      }

      if (line.contains('showDialog') &&
          !relativePath.endsWith('adaptive_bottom_sheet.dart') &&
          !relativePath.endsWith('adaptive_page_scaffold.dart') &&
          !relativePath.contains('/reader/')) {
        findings.add(
          _Finding(
            kind: 'dialog-surface',
            path: relativePath,
            line: index + 1,
            message:
                'Review direct showDialog; prefer an adaptive surface for new page-level actions.',
          ),
        );
      }

      if (_hasPresentationPlatformBranch(line) &&
          !_isAllowedPlatformBranch(relativePath)) {
        findings.add(
          _Finding(
            kind: 'platform-branch',
            path: relativePath,
            line: index + 1,
            message:
                'Review page-level platform branch; prefer capability or adaptive metrics.',
          ),
        );
      }

      if (RegExp(r'\bCircularProgressIndicator\s*\(').hasMatch(line) &&
          !_isAllowedLocalSpinner(relativePath)) {
        findings.add(
          _Finding(
            kind: 'loading-state',
            path: relativePath,
            line: index + 1,
            message:
                'Review page-level spinner; prefer AppStatusStateCard or a feature status component when it blocks content.',
          ),
        );
      }

      if (RegExp(r'\bListView\s*\(\s*$').hasMatch(line) ||
          RegExp(r'\bListView\s*\(\s*children\s*:').hasMatch(line)) {
        findings.add(
          _Finding(
            kind: 'list-children',
            path: relativePath,
            line: index + 1,
            message:
                'Review ListView(children); long lists should use ListView.builder or SliverList.',
          ),
        );
      }

      if (RegExp(r'\bScaffold\s*\(').hasMatch(line) &&
          !_isAllowedScaffold(relativePath)) {
        findings.add(
          _Finding(
            kind: 'scaffold',
            path: relativePath,
            line: index + 1,
            message:
                'New pages should prefer AdaptivePageScaffold or document why a custom scaffold is required.',
          ),
        );
      }
    }

    findings.addAll(_layoutBuilderSideEffectFindings(relativePath, lines));
  }

  stdout.writeln('==> UI component governance checks');
  stdout.writeln('Findings: ${findings.length}');

  if (findings.isNotEmpty) {
    stdout.writeln('');
    final byKind = <String, int>{};
    for (final finding in findings) {
      byKind.update(finding.kind, (value) => value + 1, ifAbsent: () => 1);
    }
    stdout.writeln('Summary');
    for (final entry
        in byKind.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
      stdout.writeln('- ${entry.key}: ${entry.value}');
    }

    stdout.writeln('');
    stdout.writeln(
      verbose ? 'Details' : 'Sample details (use --verbose for all)',
    );
    final visibleFindings = verbose ? findings : findings.take(40);
    for (final finding in visibleFindings) {
      stdout.writeln(
        '- [${finding.kind}] ${finding.path}:${finding.line}: ${finding.message}',
      );
    }
    if (!verbose && findings.length > 40) {
      stdout.writeln('- ... ${findings.length - 40} more finding(s) hidden');
    }
  }

  if (findings.isNotEmpty && failOnWarning) {
    exitCode = 1;
  }
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
  List<String> lines,
) {
  final findings = <_Finding>[];
  for (var index = 0; index < lines.length; index += 1) {
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
          line: index + 1,
          message:
              'Review LayoutBuilder body for side effects or heavy work; it should stay layout-only.',
        ),
      );
    }
  }
  return findings;
}

bool _isAllowedLocalSpinner(String path) {
  return path.contains('/reader/') ||
      path.contains('/app/widgets/import_export_task') ||
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
      path.contains('/core/webview/') ||
      path.endsWith('app_layout.dart') ||
      path.endsWith('app_adaptive.dart') ||
      path.endsWith('bootstrap.dart');
}

String _relativePath(File file) {
  final prefix = '${Directory.current.path}/';
  return file.path.startsWith(prefix)
      ? file.path.substring(prefix.length)
      : file.path;
}
