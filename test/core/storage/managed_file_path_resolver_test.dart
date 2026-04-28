import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/storage/managed_file_path_resolver.dart';

void main() {
  late Directory tempRoot;
  late Directory documentsDirectory;
  late Directory supportDirectory;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp(
      'managed_file_path_resolver_test_',
    );
    documentsDirectory = Directory('${tempRoot.path}/documents')
      ..createSync(recursive: true);
    supportDirectory = Directory('${tempRoot.path}/support')
      ..createSync(recursive: true);
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  ManagedFilePathResolver createResolver() {
    return ManagedFilePathResolver(
      documentsDirectoryProvider: () async => documentsDirectory,
      supportDirectoryProvider: () async => supportDirectory,
    );
  }

  test('rebases document managed paths to current container', () async {
    final file = File(
      '${documentsDirectory.path}/cover_galleries/gallery_a/cover_1.png',
    )..createSync(recursive: true);
    final resolver = createResolver();

    final resolved = await resolver.resolveExistingFilePath(
      '/old/container/Documents/cover_galleries/gallery_a/cover_1.png',
    );

    expect(resolved, file.path);
  });

  test('rebases support managed paths with nested custom cover folder', () async {
    final file = File(
      '${supportDirectory.path}/shuxiang_reading_next/custom_covers/book_1.jpg',
    )..createSync(recursive: true);
    final resolver = createResolver();

    final resolved = await resolver.resolveExistingFilePath(
      '/old/container/Library/Application Support/shuxiang_reading_next/custom_covers/book_1.jpg',
    );

    expect(resolved, file.path);
  });

  test('sync resolution works after root priming', () async {
    final file = File('${supportDirectory.path}/reader_fonts/font_a.ttf')
      ..createSync(recursive: true);
    await ManagedFilePathResolver.primeCurrentRoots(
      documentsDirectoryProvider: () async => documentsDirectory,
      supportDirectoryProvider: () async => supportDirectory,
    );
    final resolver = createResolver();

    final resolved = resolver.tryResolveExistingFilePathSync(
      '/old/container/Library/Application Support/reader_fonts/font_a.ttf',
    );

    expect(resolved, file.path);
  });
}
