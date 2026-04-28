import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/source/application/source_script_import_service.dart';

void main() {
  test('imports local files with limit and aggregates failures', () async {
    final service = SourceScriptImportService();
    final tempDir = Directory.systemTemp.createTempSync('source_import_test');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final fileA = File('${tempDir.path}/a.js')..writeAsStringSync('export default {}');
    final fileB = File('${tempDir.path}/b.js')..writeAsStringSync('broken');

    final saved = <String>[];
    final summary = await service.importLocalFiles(
      files: [XFile(fileA.path), XFile(fileB.path)],
      remainingSlots: 1,
      saver: (sourceCode) async {
        saved.add(sourceCode);
      },
      errorFormatter: (error) => '$error',
    );

    expect(saved, hasLength(1));
    expect(summary.successCount, 1);
    expect(summary.truncatedByLimit, isTrue);
  });

  test('imports cached external file by reading source text', () async {
    final service = SourceScriptImportService();
    final tempDir = Directory.systemTemp.createTempSync('source_external_test');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
    final file = File('${tempDir.path}/source.js')
      ..writeAsStringSync('export default { meta: { name: "test" } };');

    String? saved;
    await service.importCachedExternalFile(
      file: file,
      saver: (sourceCode) async {
        saved = sourceCode;
      },
    );

    expect(saved, contains('export default'));
  });
}
