import 'dart:io';

const _blockedDevicePatterns = <String>[
  r'iPhone\s*(SE|Mini|Pro|Max|\d+)',
  r'Pixel\s*\d+',
  r'Galaxy\s*S\d+',
  r'Android\s+model',
];

const _fixedSizePatterns = <String>[
  r'EdgeInsets\.all\(24\)',
  r'BorderRadius\.circular\(24\)',
  r'SizedBox\(\s*height:\s*(72|80|96|120|148|160)\b',
  r'SizedBox\(\s*width:\s*(72|80|96|104|120|160)\b',
];

void main(List<String> args) {
  final failOnFinding = args.contains('--fail');
  final roots = args.where((arg) => !arg.startsWith('--')).toList();
  final scanRoots = roots.isEmpty ? const ['lib'] : roots;
  final findings = <String>[];

  for (final root in scanRoots) {
    final entity = Directory(root);
    if (!entity.existsSync()) {
      continue;
    }
    for (final file in entity
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))) {
      final text = file.readAsStringSync();
      final lines = text.split('\n');
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') ||
            trimmed.startsWith('*') ||
            line.contains('Mozilla/5.0')) {
          continue;
        }
        for (final pattern in _blockedDevicePatterns) {
          if (RegExp(pattern, caseSensitive: false).hasMatch(line)) {
            findings.add(
              '${file.path}:${index + 1}: avoid device-model adaptive checks: ${line.trim()}',
            );
          }
        }
        for (final pattern in _fixedSizePatterns) {
          if (RegExp(pattern).hasMatch(line)) {
            findings.add(
              '${file.path}:${index + 1}: review fixed layout size, prefer AppAdaptiveMetrics: ${line.trim()}',
            );
          }
        }
      }
    }
  }

  if (findings.isEmpty) {
    stdout.writeln('Adaptive layout guard passed.');
    return;
  }

  stdout.writeln('Adaptive layout guard found ${findings.length} item(s):');
  for (final finding in findings) {
    stdout.writeln('- $finding');
  }

  if (failOnFinding) {
    exitCode = 1;
  }
}
