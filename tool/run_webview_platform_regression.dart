import 'dart:convert';
import 'dart:io';

enum PlatformBucket { android, ios, desktop }

class RunConfig {
  const RunConfig({
    required this.flutterCmd,
    required this.testTarget,
    required this.platforms,
    required this.logDir,
    required this.allowMissingPlatforms,
    required this.failFast,
    required this.deviceOverrideByPlatform,
  });

  final String flutterCmd;
  final String testTarget;
  final List<PlatformBucket> platforms;
  final String logDir;
  final bool allowMissingPlatforms;
  final bool failFast;
  final Map<PlatformBucket, String> deviceOverrideByPlatform;
}

class DeviceDescriptor {
  const DeviceDescriptor({
    required this.id,
    required this.name,
    required this.targetPlatform,
    required this.emulator,
    required this.platformBucket,
  });

  final String id;
  final String name;
  final String targetPlatform;
  final bool emulator;
  final PlatformBucket? platformBucket;
}

class RunResult {
  const RunResult({
    required this.platform,
    required this.status,
    required this.deviceId,
    required this.deviceName,
    required this.logPath,
    this.exitCode,
    this.message,
    this.durationMs,
  });

  final PlatformBucket platform;
  final String status;
  final String? deviceId;
  final String? deviceName;
  final String? logPath;
  final int? exitCode;
  final String? message;
  final int? durationMs;
}

Future<void> main(List<String> args) async {
  if (args.contains('-h') || args.contains('--help')) {
    _printUsage();
    return;
  }

  final config = _parseArgs(args);
  final timestamp = _timestamp();
  final sessionLogDir = '${config.logDir}/$timestamp';
  Directory(sessionLogDir).createSync(recursive: true);

  stdout.writeln('==> WebView platform regression');
  stdout.writeln('==> Flutter command : ${config.flutterCmd}');
  stdout.writeln('==> Test target     : ${config.testTarget}');
  stdout.writeln(
    '==> Platforms       : ${config.platforms.map(_platformLabel).join(', ')}',
  );
  stdout.writeln('==> Session log dir : $sessionLogDir');

  final devices = await _listDevices(config.flutterCmd);
  if (devices.isEmpty) {
    stderr.writeln('No devices found from `flutter devices --machine`.');
    exitCode = 2;
    return;
  }

  final selectedDevices = _selectDevices(
    devices: devices,
    platforms: config.platforms,
    overrides: config.deviceOverrideByPlatform,
  );

  final results = <RunResult>[];
  var failed = false;
  var missing = false;

  for (final platform in config.platforms) {
    final selected = selectedDevices[platform];
    if (selected == null) {
      final message = 'No matching device.';
      if (config.allowMissingPlatforms) {
        results.add(
          RunResult(
            platform: platform,
            status: 'SKIP',
            deviceId: null,
            deviceName: null,
            logPath: null,
            message: message,
          ),
        );
        stdout.writeln('[${_platformLabel(platform)}] SKIP - $message');
        continue;
      }

      missing = true;
      results.add(
        RunResult(
          platform: platform,
          status: 'MISSING',
          deviceId: null,
          deviceName: null,
          logPath: null,
          message: message,
        ),
      );
      stderr.writeln('[${_platformLabel(platform)}] MISSING - $message');
      if (config.failFast) {
        break;
      }
      continue;
    }

    final result = await _runSinglePlatform(
      config: config,
      platform: platform,
      device: selected,
      sessionLogDir: sessionLogDir,
    );
    results.add(result);
    if (result.status == 'FAIL') {
      failed = true;
      if (config.failFast) {
        break;
      }
    }
  }

  final summaryPath = '$sessionLogDir/summary.json';
  await File(summaryPath).writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'timestamp': DateTime.now().toIso8601String(),
      'testTarget': config.testTarget,
      'platforms': config.platforms.map(_platformLabel).toList(growable: false),
      'allowMissingPlatforms': config.allowMissingPlatforms,
      'failFast': config.failFast,
      'results': [
        for (final item in results)
          {
            'platform': _platformLabel(item.platform),
            'status': item.status,
            'deviceId': item.deviceId,
            'deviceName': item.deviceName,
            'exitCode': item.exitCode,
            'durationMs': item.durationMs,
            'logPath': item.logPath,
            'message': item.message,
          },
      ],
    }),
  );

  stdout.writeln('');
  stdout.writeln('==> Summary');
  for (final item in results) {
    stdout.writeln(
      '${_platformLabel(item.platform).padRight(8)} '
      '${item.status.padRight(7)} '
      'device=${item.deviceName ?? '-'} '
      'log=${item.logPath ?? '-'}',
    );
  }
  stdout.writeln('Summary json: $summaryPath');

  if (failed) {
    exitCode = 1;
    return;
  }
  if (missing && !config.allowMissingPlatforms) {
    exitCode = 3;
    return;
  }
}

RunConfig _parseArgs(List<String> args) {
  String flutterCmd = 'flutter';
  String testTarget =
      'integration_test/webview_true_platform_regression_test.dart';
  String logDir = 'build/webview_platform_regression';
  List<PlatformBucket> platforms = <PlatformBucket>[
    PlatformBucket.android,
    PlatformBucket.ios,
    PlatformBucket.desktop,
  ];
  bool allowMissingPlatforms = true;
  bool failFast = false;
  final deviceOverrideByPlatform = <PlatformBucket, String>{};

  for (final arg in args) {
    if (arg.startsWith('--flutter=')) {
      flutterCmd = arg.substring('--flutter='.length).trim();
      continue;
    }
    if (arg.startsWith('--test-target=')) {
      testTarget = arg.substring('--test-target='.length).trim();
      continue;
    }
    if (arg.startsWith('--platforms=')) {
      platforms = _parsePlatforms(arg.substring('--platforms='.length).trim());
      continue;
    }
    if (arg.startsWith('--log-dir=')) {
      logDir = arg.substring('--log-dir='.length).trim();
      continue;
    }
    if (arg.startsWith('--allow-missing-platforms=')) {
      allowMissingPlatforms = _parseBool(
        arg.substring('--allow-missing-platforms='.length).trim(),
      );
      continue;
    }
    if (arg.startsWith('--fail-fast=')) {
      failFast = _parseBool(arg.substring('--fail-fast='.length).trim());
      continue;
    }
    if (arg.startsWith('--android-device=')) {
      deviceOverrideByPlatform[PlatformBucket.android] =
          arg.substring('--android-device='.length).trim();
      continue;
    }
    if (arg.startsWith('--ios-device=')) {
      deviceOverrideByPlatform[PlatformBucket.ios] =
          arg.substring('--ios-device='.length).trim();
      continue;
    }
    if (arg.startsWith('--desktop-device=')) {
      deviceOverrideByPlatform[PlatformBucket.desktop] =
          arg.substring('--desktop-device='.length).trim();
      continue;
    }
    throw ArgumentError('Unknown argument: $arg');
  }

  if (flutterCmd.isEmpty) {
    throw ArgumentError('`--flutter` cannot be empty.');
  }
  if (testTarget.isEmpty) {
    throw ArgumentError('`--test-target` cannot be empty.');
  }
  if (logDir.isEmpty) {
    throw ArgumentError('`--log-dir` cannot be empty.');
  }

  return RunConfig(
    flutterCmd: flutterCmd,
    testTarget: testTarget,
    platforms: platforms,
    logDir: logDir,
    allowMissingPlatforms: allowMissingPlatforms,
    failFast: failFast,
    deviceOverrideByPlatform: deviceOverrideByPlatform,
  );
}

List<PlatformBucket> _parsePlatforms(String raw) {
  if (raw.isEmpty || raw == 'all') {
    return <PlatformBucket>[
      PlatformBucket.android,
      PlatformBucket.ios,
      PlatformBucket.desktop,
    ];
  }

  final resolved = <PlatformBucket>[];
  final seen = <PlatformBucket>{};
  final tokens = raw
      .split(',')
      .map((item) => item.trim().toLowerCase())
      .where((item) => item.isNotEmpty);

  for (final token in tokens) {
    final next = switch (token) {
      'android' => PlatformBucket.android,
      'ios' => PlatformBucket.ios,
      'desktop' => PlatformBucket.desktop,
      _ =>
        throw ArgumentError(
          'Unsupported platform token: $token. Use android,ios,desktop.',
        ),
    };
    if (seen.add(next)) {
      resolved.add(next);
    }
  }

  if (resolved.isEmpty) {
    throw ArgumentError('No valid platform token in --platforms=$raw');
  }
  return resolved;
}

bool _parseBool(String raw) {
  final normalized = raw.toLowerCase();
  if (normalized == 'true' || normalized == '1') {
    return true;
  }
  if (normalized == 'false' || normalized == '0') {
    return false;
  }
  throw ArgumentError('Invalid bool value: $raw');
}

Future<List<DeviceDescriptor>> _listDevices(String flutterCmd) async {
  final result = await Process.run(flutterCmd, <String>[
    'devices',
    '--machine',
  ]);
  if (result.exitCode != 0) {
    throw ProcessException(
      flutterCmd,
      const <String>['devices', '--machine'],
      '${result.stdout}\n${result.stderr}',
      result.exitCode,
    );
  }

  final raw = result.stdout.toString().trim();
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    throw StateError('Unexpected flutter devices output: $decoded');
  }

  return decoded
      .whereType<Map>()
      .map((dynamic item) {
        final map = item.cast<String, dynamic>();
        final id = (map['id'] ?? '').toString().trim();
        final name = (map['name'] ?? '').toString().trim();
        final targetPlatform =
            (map['targetPlatform'] ?? map['platformType'] ?? '')
                .toString()
                .trim();
        final emulator = map['emulator'] == true;
        return DeviceDescriptor(
          id: id,
          name: name,
          targetPlatform: targetPlatform,
          emulator: emulator,
          platformBucket: _toPlatformBucket(targetPlatform),
        );
      })
      .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
      .toList(growable: false);
}

Map<PlatformBucket, DeviceDescriptor?> _selectDevices({
  required List<DeviceDescriptor> devices,
  required List<PlatformBucket> platforms,
  required Map<PlatformBucket, String> overrides,
}) {
  final selected = <PlatformBucket, DeviceDescriptor?>{};

  for (final platform in platforms) {
    final overrideId = overrides[platform];
    if (overrideId != null && overrideId.isNotEmpty) {
      final matched =
          devices.where((device) => device.id == overrideId).toList();
      if (matched.isEmpty) {
        throw ArgumentError(
          'Requested ${_platformLabel(platform)} device not found: $overrideId',
        );
      }
      selected[platform] = matched.first;
      continue;
    }

    final candidates =
        devices.where((device) => device.platformBucket == platform).toList();
    if (candidates.isEmpty) {
      selected[platform] = null;
      continue;
    }

    final physical = candidates.where((device) => !device.emulator).toList();
    selected[platform] = (physical.isNotEmpty ? physical : candidates).first;
  }

  return selected;
}

Future<RunResult> _runSinglePlatform({
  required RunConfig config,
  required PlatformBucket platform,
  required DeviceDescriptor device,
  required String sessionLogDir,
}) async {
  final testArgs = <String>[
    'test',
    config.testTarget,
    '-d',
    device.id,
    '--reporter',
    'expanded',
  ];

  final platformLabel = _platformLabel(platform);
  final safeDeviceName = _sanitizeFileToken(device.name);
  final logPath = '$sessionLogDir/${platformLabel}_$safeDeviceName.log';

  stdout.writeln('');
  stdout.writeln(
    '[$platformLabel] RUN device="${device.name}" id="${device.id}"',
  );
  stdout.writeln(
    '[$platformLabel] CMD ${config.flutterCmd} ${testArgs.join(' ')}',
  );

  final started = DateTime.now();
  final process = await Process.start(
    config.flutterCmd,
    testArgs,
    workingDirectory: Directory.current.path,
    runInShell: true,
  );

  final output = StringBuffer();
  final stdoutDone =
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            stdout.writeln('[$platformLabel] $line');
            output.writeln(line);
          })
          .asFuture<void>();
  final stderrDone =
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            stderr.writeln('[$platformLabel] $line');
            output.writeln(line);
          })
          .asFuture<void>();

  final exitCodeValue = await process.exitCode;
  await Future.wait(<Future<void>>[stdoutDone, stderrDone]);

  final durationMs = DateTime.now().difference(started).inMilliseconds;
  await File(logPath).writeAsString(
    [
      'flutter command: ${config.flutterCmd}',
      'test args: ${testArgs.join(' ')}',
      'device id: ${device.id}',
      'device name: ${device.name}',
      'target platform: ${device.targetPlatform}',
      'duration ms: $durationMs',
      'exit code: $exitCodeValue',
      '--- output ---',
      output.toString(),
    ].join('\n'),
  );

  if (exitCodeValue == 0) {
    stdout.writeln('[$platformLabel] PASS ($durationMs ms)');
    return RunResult(
      platform: platform,
      status: 'PASS',
      deviceId: device.id,
      deviceName: device.name,
      logPath: logPath,
      exitCode: exitCodeValue,
      durationMs: durationMs,
    );
  }

  stderr.writeln(
    '[$platformLabel] FAIL exitCode=$exitCodeValue ($durationMs ms)',
  );
  return RunResult(
    platform: platform,
    status: 'FAIL',
    deviceId: device.id,
    deviceName: device.name,
    logPath: logPath,
    exitCode: exitCodeValue,
    durationMs: durationMs,
  );
}

PlatformBucket? _toPlatformBucket(String rawPlatform) {
  final text = rawPlatform.toLowerCase();
  if (text.contains('android')) {
    return PlatformBucket.android;
  }
  if (text.contains('ios')) {
    return PlatformBucket.ios;
  }
  if (text.contains('macos') ||
      text.contains('windows') ||
      text.contains('linux')) {
    return PlatformBucket.desktop;
  }
  return null;
}

String _timestamp() {
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
}

String _sanitizeFileToken(String input) {
  return input.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
}

String _platformLabel(PlatformBucket platform) {
  return switch (platform) {
    PlatformBucket.android => 'android',
    PlatformBucket.ios => 'ios',
    PlatformBucket.desktop => 'desktop',
  };
}

void _printUsage() {
  stdout.writeln('''
Run real-device/platform regression for webView:true path.

Usage:
  dart run tool/run_webview_platform_regression.dart [options]

Options:
  --flutter=<cmd>                     Flutter command (default: flutter)
  --test-target=<path>                Integration test target
                                      (default: integration_test/webview_true_platform_regression_test.dart)
  --platforms=android,ios,desktop     Target platform buckets (default: all)
  --log-dir=<dir>                     Log root dir (default: build/webview_platform_regression)
  --allow-missing-platforms=true|false
                                      Skip missing platform device or fail (default: true)
  --fail-fast=true|false              Stop after first failure (default: false)
  --android-device=<id>               Force selected Android device id
  --ios-device=<id>                   Force selected iOS device id
  --desktop-device=<id>               Force selected Desktop device id
  -h, --help                          Show help

Examples:
  dart run tool/run_webview_platform_regression.dart
  dart run tool/run_webview_platform_regression.dart --platforms=android,ios
  dart run tool/run_webview_platform_regression.dart --android-device=emulator-5554
''');
}
