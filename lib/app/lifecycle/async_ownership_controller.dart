/// 页面异步任务归属控制器。
///
/// 适用于“只允许最后一次请求写回页面状态”的轻量场景，例如会员权限刷新、
/// 搜索条件刷新、导入进度回调等。控制器只负责 generation 归属，不负责真正
/// 取消网络请求；如果底层服务支持 cancel，应继续配合业务自己的取消 token。
class AsyncOwnershipController {
  int _generation = 0;
  bool _disposed = false;

  int get generation => _generation;
  bool get isDisposed => _disposed;

  int begin() {
    if (_disposed) {
      throw StateError('AsyncOwnershipController 已释放，不能再创建新任务。');
    }
    _generation += 1;
    return _generation;
  }

  int cancel() {
    _generation += 1;
    return _generation;
  }

  bool isActive(int token, {required bool mounted}) {
    return mounted && !_disposed && token > 0 && token == _generation;
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _generation += 1;
  }
}
