import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor openAppDatabaseConnection() {
  return LazyDatabase(() async {
    final isFlutterTest = Platform.environment.containsKey('FLUTTER_TEST');

    final baseDir =
        isFlutterTest
            ? Directory.systemTemp
            : await getApplicationSupportDirectory();

    final databaseDir = Directory(
      p.join(baseDir.path, 'shuxiang_reading_next'),
    );
    if (!await databaseDir.exists()) {
      await databaseDir.create(recursive: true);
    }

    final file = File(p.join(databaseDir.path, 'shuxiang_reading_next.db'));
    return NativeDatabase.createInBackground(file);
  });
}
