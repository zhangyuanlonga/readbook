import 'dart:io';

final class _SuiteStep {
  const _SuiteStep({
    required this.name,
    required this.executable,
    required this.arguments,
  });

  final String name;
  final String executable;
  final List<String> arguments;
}

Future<void> main(List<String> args) async {
  final flutterCmd = _parseOption(args, '--flutter') ?? 'flutter';
  final dryRun = args.contains('--dry-run');

  final steps = <_SuiteStep>[
    _SuiteStep(
      name: 'Analyze',
      executable: flutterCmd,
      arguments: const ['analyze'],
    ),
    const _SuiteStep(
      name: 'Guardrails',
      executable: 'dart',
      arguments: ['run', 'tool/check_architecture_guardrails.dart'],
    ),
    const _SuiteStep(
      name: 'Engineering Baseline Audit',
      executable: 'dart',
      arguments: ['run', 'tool/check_codebase_engineering_baseline.dart'],
    ),
    const _SuiteStep(
      name: 'Storage Governance Guard',
      executable: 'dart',
      arguments: ['run', 'tool/check_storage_governance_guard.dart'],
    ),
    const _SuiteStep(
      name: 'Route Inventory',
      executable: 'dart',
      arguments: ['run', 'tool/check_route_inventory.dart'],
    ),
    const _SuiteStep(
      name: 'UI Component Governance',
      executable: 'dart',
      arguments: ['run', 'tool/check_ui_component_governance.dart'],
    ),
    _SuiteStep(
      name: 'Shared Models',
      executable: flutterCmd,
      arguments: const [
        'test',
        'test/domain/entities/book_identity_test.dart',
        'test/domain/entities/managed_asset_test.dart',
        'test/domain/entities/app_advanced_theme_reader_wallpaper_test.dart',
      ],
    ),
    _SuiteStep(
      name: 'Provider Smoke',
      executable: flutterCmd,
      arguments: const [
        'test',
        'test/features/announcement/application/announcement_provider_smoke_test.dart',
        'test/features/auth/application/auth_provider_smoke_test.dart',
        'test/features/book/application/book_provider_smoke_test.dart',
        'test/features/bookshelf/application/bookshelf_provider_smoke_test.dart',
        'test/features/search/application/search_provider_smoke_test.dart',
        'test/features/source/application/source_provider_smoke_test.dart',
      ],
    ),
    _SuiteStep(
      name: 'Shared Semantics',
      executable: flutterCmd,
      arguments: const [
        'test',
        'test/features/book/application/book_presentation_query_service_test.dart',
        'test/features/book/application/book_presentation_sync_service_test.dart',
        'test/features/mine/application/appearance_page_resource_service_test.dart',
      ],
    ),
    _SuiteStep(
      name: 'Reader And Source Flow',
      executable: flutterCmd,
      arguments: const [
        'test',
        'test/features/reader/application/reader_source_switch_coordinator_test.dart',
        'test/features/reader/presentation/reader_runtime_controller_test.dart',
        'test/features/source/presentation/source_page_script_tab_test.dart',
      ],
    ),
    _SuiteStep(
      name: 'Storage Migration Regression',
      executable: flutterCmd,
      arguments: const [
        'test',
        'test/data/datasources/local/app_database_reading_record_migration_test.dart',
        'test/data/datasources/local/app_database_chapter_cache_test.dart',
        'test/data/datasources/local/app_database_reading_progress_migration_test.dart',
        'test/app/startup/managed_asset_path_migration_service_test.dart',
      ],
    ),
  ];

  stdout.writeln('==> Architecture green suite');
  stdout.writeln('Flutter command : $flutterCmd');
  stdout.writeln('Dry run         : $dryRun');

  for (final step in steps) {
    final commandPreview = '${step.executable} ${step.arguments.join(' ')}';
    stdout.writeln('');
    stdout.writeln('==> ${step.name}');
    stdout.writeln(commandPreview);

    if (dryRun) {
      continue;
    }

    final exitCode = await _runStep(step);
    if (exitCode != 0) {
      stderr.writeln('Step failed: ${step.name} (exit $exitCode)');
      exit(exitCode);
    }
  }

  stdout.writeln('');
  stdout.writeln('Architecture green suite passed.');
}

String? _parseOption(List<String> args, String name) {
  for (final arg in args) {
    if (!arg.startsWith('$name=')) {
      continue;
    }
    return arg.substring(name.length + 1).trim();
  }
  return null;
}

Future<int> _runStep(_SuiteStep step) async {
  final process = await Process.start(
    step.executable,
    step.arguments,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}
