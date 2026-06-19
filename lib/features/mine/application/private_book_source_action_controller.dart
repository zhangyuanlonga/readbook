import 'private_book_source_service.dart';

typedef PrivateBookSourceRefresh = void Function();

class PrivateBookSourceActionController {
  const PrivateBookSourceActionController({
    required PrivateBookSourceService service,
    required PrivateBookSourceRefresh refresh,
  }) : _service = service,
       _refresh = refresh;

  final PrivateBookSourceService _service;
  final PrivateBookSourceRefresh _refresh;

  Future<PrivateBookSourceItem> loadDetailForEdit(PrivateBookSourceItem item) {
    return _service.get(item.id);
  }

  Future<void> delete(PrivateBookSourceItem item) async {
    await _service.delete(item.id);
    _refresh();
  }

  Future<void> submit(PrivateBookSourceItem item, String note) async {
    await _service.submit(item.id, note);
    _refresh();
  }

  Future<PrivateBookSourceTestResult> test(
    PrivateBookSourceItem item, {
    required String keyword,
    required int timeoutMs,
    required List<String> checkItems,
  }) async {
    final result = await _service.test(
      item.id,
      keyword: keyword,
      timeoutMs: timeoutMs,
      checkItems: checkItems,
    );
    _refresh();
    return result;
  }

  void refresh() {
    _refresh();
  }
}
