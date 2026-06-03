import 'dart:io';

const _targetRoots = <String>['lib'];
const _allowedFiles = <String>{
  'lib/features/reader/presentation/reader_route.dart',
  'lib/features/book/presentation/book_detail_route.dart',
  'lib/features/reader/routes.dart',
  'lib/features/book/routes.dart',
};
const _navigationPatterns = <String>[
  "context.go('/reader/",
  "context.push('/reader/",
  "context.go('/book/",
  "context.push('/book/",
  "appRouter.go('/reader/",
  "appRouter.push('/reader/",
  "appRouter.go('/book/",
  "appRouter.push('/book/",
];

void main() {
  final violations = <String>[];

  for (final root in _targetRoots) {
    final directory = Directory(root);
    if (!directory.existsSync()) {
      continue;
    }
    for (final file in directory.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) {
        continue;
      }
      final normalizedPath = file.path.replaceAll('\\', '/');
      if (_allowedFiles.contains(normalizedPath)) {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        for (final pattern in _navigationPatterns) {
          if (!line.contains(pattern)) {
            continue;
          }
          violations.add('$normalizedPath:${index + 1}: $pattern');
        }
      }
    }
  }

  stdout.writeln('==> Complex route string guard');
  if (violations.isEmpty) {
    stdout.writeln('No raw reader/book detail route strings found.');
    return;
  }

  stdout.writeln('Found raw complex route strings:');
  for (final violation in violations) {
    stdout.writeln('- $violation');
  }
  exitCode = 1;
}
