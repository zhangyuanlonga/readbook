import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const String appDatabaseDirectoryName = 'shuxiang_reading_next';
const String appDatabaseFileName = 'shuxiang_reading_next.db';

QueryExecutor openAppDatabaseConnection() {
  return LazyDatabase(() async {
    final isFlutterTest = Platform.environment.containsKey('FLUTTER_TEST');

    final baseDir =
        isFlutterTest
            ? Directory.systemTemp
            : await getApplicationSupportDirectory();

    final databaseDir = Directory(
      p.join(baseDir.path, appDatabaseDirectoryName),
    );
    if (!await databaseDir.exists()) {
      await databaseDir.create(recursive: true);
    }

    final file = File(p.join(databaseDir.path, appDatabaseFileName));
    return NativeDatabase.createInBackground(file);
  });
}

Future<String?> resolveAppDatabaseDirectoryPath() async {
  final isFlutterTest = Platform.environment.containsKey('FLUTTER_TEST');
  final baseDir =
      isFlutterTest
          ? Directory.systemTemp
          : await getApplicationSupportDirectory();
  return p.join(baseDir.path, appDatabaseDirectoryName);
}

Future<String?> resolveAppDatabaseFilePath() async {
  final databaseDirPath = await resolveAppDatabaseDirectoryPath();
  if (databaseDirPath == null || databaseDirPath.isEmpty) {
    return null;
  }
  return p.join(databaseDirPath, appDatabaseFileName);
}

Future<String?> backupPersistedAppDatabase({String? suffix}) async {
  final filePath = await resolveAppDatabaseFilePath();
  if (filePath == null || filePath.isEmpty) {
    return null;
  }
  final file = File(filePath);
  if (!await file.exists()) {
    return null;
  }
  final normalizedSuffix =
      (suffix?.trim().isNotEmpty ?? false)
          ? suffix!.trim()
          : DateTime.now().millisecondsSinceEpoch.toString();
  final backupPath = '${file.path}.corrupt.$normalizedSuffix';
  final backupFile = await file.copy(backupPath);
  return backupFile.path;
}

Future<bool> deletePersistedAppDatabase() async {
  final filePath = await resolveAppDatabaseFilePath();
  if (filePath == null || filePath.isEmpty) {
    return false;
  }
  final file = File(filePath);
  if (!await file.exists()) {
    return false;
  }
  await file.delete();
  return true;
}
