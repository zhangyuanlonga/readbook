import 'dart:io';

const _inventoryPath = 'docs/global_page_route_inventory_2026-05-12.md';
const _routeRoots = <String>['lib/app/router.dart', 'lib/features'];

void main(List<String> args) {
  final projectRoot = Directory.current;
  final inventoryFile = File(_inventoryPath);
  if (!inventoryFile.existsSync()) {
    stderr.writeln('Route inventory not found: $_inventoryPath');
    exitCode = 1;
    return;
  }

  final routeFiles = _collectRouteFiles(projectRoot);
  final routePaths = _collectRoutePaths(routeFiles);
  final inventoryText = inventoryFile.readAsStringSync();
  final missing = <String>[];

  for (final routePath in routePaths.keys.toList()..sort()) {
    if (!_isRouteDocumented(inventoryText, routePath)) {
      missing.add(routePath);
    }
  }

  stdout.writeln('==> Route inventory coverage');
  stdout.writeln('Inventory : $_inventoryPath');
  stdout.writeln('Route files: ${routeFiles.length}');
  stdout.writeln('Route paths: ${routePaths.length}');

  if (missing.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('Missing route path(s):');
    for (final routePath in missing) {
      stdout.writeln('- $routePath');
      for (final source in routePaths[routePath]!) {
        stdout.writeln('  $source');
      }
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('');
  stdout.writeln('All route paths are documented.');
}

List<File> _collectRouteFiles(Directory projectRoot) {
  final files = <File>[];
  for (final root in _routeRoots) {
    final entity = File(root);
    if (entity.existsSync()) {
      files.add(entity);
      continue;
    }

    final directory = Directory(root);
    if (!directory.existsSync()) {
      continue;
    }
    files.addAll(
      directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('/routes.dart')),
    );
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

Map<String, List<String>> _collectRoutePaths(List<File> routeFiles) {
  final routePaths = <String, List<String>>{};
  final pathPattern = RegExp(r'''path\s*:\s*['"]([^'"]+)['"]''');

  for (final file in routeFiles) {
    final relativePath = file.path.replaceFirst(
      '${Directory.current.path}/',
      '',
    );
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      for (final match in pathPattern.allMatches(line)) {
        final routePath = match.group(1)!.trim();
        if (routePath.isEmpty || routePath.contains(r'$')) {
          continue;
        }
        routePaths
            .putIfAbsent(routePath, () => <String>[])
            .add('$relativePath:${index + 1}');
      }
    }
  }

  return routePaths;
}

bool _isRouteDocumented(String inventoryText, String routePath) {
  return inventoryText.contains('`$routePath`') ||
      inventoryText.contains('| $routePath |') ||
      inventoryText.contains(routePath);
}
