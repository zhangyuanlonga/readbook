import 'dart:async';

import 'private_book_source_service.dart';

typedef PrivateBookSourceRefresh = FutureOr<void> Function();
typedef PrivateBookSourceGroupSelection = void Function(String groupId);

class PrivateBookSourceActionController {
  const PrivateBookSourceActionController({
    required PrivateBookSourceService service,
    required PrivateBookSourceRefresh refresh,
    PrivateBookSourceRefresh? refreshGroups,
    PrivateBookSourceGroupSelection? selectGroup,
    PrivateBookSourceGroupSelection? clearSelectedGroupIf,
  }) : _service = service,
       _refresh = refresh,
       _refreshGroups = refreshGroups ?? refresh,
       _selectGroup = selectGroup ?? _ignoreGroupSelection,
       _clearSelectedGroupIf = clearSelectedGroupIf ?? _ignoreGroupSelection;

  final PrivateBookSourceService _service;
  final PrivateBookSourceRefresh _refresh;
  final PrivateBookSourceRefresh _refreshGroups;
  final PrivateBookSourceGroupSelection _selectGroup;
  final PrivateBookSourceGroupSelection _clearSelectedGroupIf;

  Future<PrivateBookSourceItem> loadDetailForEdit(PrivateBookSourceItem item) {
    return _service.get(item.id);
  }

  Future<void> delete(PrivateBookSourceItem item) async {
    await _service.delete(item.id);
    await _refresh();
  }

  Future<void> submit(PrivateBookSourceItem item, String note) async {
    await _service.submit(item.id, note);
    await _refresh();
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
    await _refresh();
    return result;
  }

  Future<PrivateBookSourceGroup> createGroup(String name) async {
    final group = await _service.createGroup(name);
    await _refreshGroups();
    return group;
  }

  Future<PrivateBookSourceGroup> renameGroup(
    PrivateBookSourceGroup group,
    String name,
  ) async {
    final updated = await _service.updateGroup(group.id, name);
    _selectGroup(updated.id);
    await _refreshGroups();
    return updated;
  }

  Future<void> deleteGroup(PrivateBookSourceGroup group) async {
    await _service.deleteGroup(group.id);
    _clearSelectedGroupIf(group.id);
    await _refreshGroups();
  }

  Future<void> refresh() async {
    await _refresh();
  }
}

void _ignoreGroupSelection(String groupId) {}
