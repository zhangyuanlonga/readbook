// ignore_for_file: deprecated_member_use

import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor openAppDatabaseConnection() {
  return WebDatabase('shuxiang_reading_next');
}
