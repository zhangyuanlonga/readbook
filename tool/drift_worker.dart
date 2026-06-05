import 'package:drift/wasm.dart';

void main() {
  // drift 的 Web worker 负责在独立线程中打开 SQLite，主线程只通过
  // WasmDatabase.open 返回的连接访问数据库，避免 UI 线程被数据库操作阻塞。
  WasmDatabase.workerMainForOpen();
}
