import 'dart:io';

final class _AuditStep {
  const _AuditStep(this.name, this.script);

  final String name;
  final String script;
}

Future<void> main(List<String> args) async {
  final rootArg = _parseRootArg(args);
  final strict = args.contains('--strict');
  final stepArgs = <String>[
    if (rootArg != null) rootArg,
    if (strict) '--strict',
  ];

  final steps = const <_AuditStep>[
    _AuditStep(
      'Core feature import guard',
      'tool/check_core_feature_import_guard.dart',
    ),
    _AuditStep('File size audit', 'tool/check_file_size_audit.dart'),
    _AuditStep('Catch audit', 'tool/check_catch_audit.dart'),
  ];

  stdout.writeln('==> Phase 6 guardrail audit');
  stdout.writeln('Mode : ${strict ? 'strict' : 'report'}');

  for (final step in steps) {
    stdout.writeln('');
    stdout.writeln('==> ${step.name}');
    final exitCode = await _runDartScript(step.script, stepArgs);
    if (exitCode != 0) {
      stderr.writeln('Step failed: ${step.name} (exit $exitCode)');
      exit(exitCode);
    }
  }

  stdout.writeln('');
  stdout.writeln('Phase 6 guardrail audit finished.');
}

String? _parseRootArg(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--root=')) {
      return arg;
    }
  }
  return null;
}

Future<int> _runDartScript(String script, List<String> args) async {
  final process = await Process.start(Platform.resolvedExecutable, [
    script,
    ...args,
  ], mode: ProcessStartMode.inheritStdio);
  return process.exitCode;
}
