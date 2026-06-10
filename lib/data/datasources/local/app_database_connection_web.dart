import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

QueryExecutor openAppDatabaseConnection() {
  return LazyDatabase(() async {
    // Web 端使用 drift 官方 wasm 后端，避免旧 WebDatabase 依赖全局 sql.js
    // 脚本导致书架等页面第一次访问数据库时直接崩溃。
    final result = await WasmDatabase.open(
      databaseName: 'shuxiang_reading_next',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}

Future<String?> resolveAppDatabaseDirectoryPath() async => null;

Future<String?> resolveAppDatabaseFilePath() async => null;

Future<String?> backupPersistedAppDatabase({String? suffix}) async => null;

Future<bool> deletePersistedAppDatabase() async => false;
