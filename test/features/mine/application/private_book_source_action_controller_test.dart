import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/mine/application/private_book_source_action_controller.dart';
import 'package:shuxiang_reading_next/features/mine/application/private_book_source_service.dart';

void main() {
  test(
    'loads detail through service without refreshing list providers',
    () async {
      var refreshCount = 0;
      final service = _FakePrivateBookSourceService();
      final controller = PrivateBookSourceActionController(
        service: service,
        refresh: () => refreshCount += 1,
      );

      final detail = await controller.loadDetailForEdit(
        _source(id: 'source_1', name: '列表源'),
      );

      expect(service.loadedId, 'source_1');
      expect(detail.name, '详情源');
      expect(refreshCount, 0);
    },
  );

  test('delete delegates by id and refreshes after success', () async {
    var refreshCount = 0;
    final service = _FakePrivateBookSourceService();
    final controller = PrivateBookSourceActionController(
      service: service,
      refresh: () => refreshCount += 1,
    );

    await controller.delete(_source(id: 'source_2'));

    expect(service.deletedIds, <String>['source_2']);
    expect(refreshCount, 1);
  });

  test('save source creates new source and refreshes after success', () async {
    var refreshCount = 0;
    final service = _FakePrivateBookSourceService();
    final controller = PrivateBookSourceActionController(
      service: service,
      refresh: () => refreshCount += 1,
    );

    final saved = await controller.saveSource(
      item: null,
      input: _input(name: '新书源'),
    );

    expect(service.createdInputs.map((input) => input.name), <String>['新书源']);
    expect(service.updatedInputs, isEmpty);
    expect(saved.id, 'created_1');
    expect(refreshCount, 1);
  });

  test(
    'save source updates existing source and refreshes after success',
    () async {
      var refreshCount = 0;
      final service = _FakePrivateBookSourceService();
      final controller = PrivateBookSourceActionController(
        service: service,
        refresh: () => refreshCount += 1,
      );

      final saved = await controller.saveSource(
        item: _source(id: 'source_5'),
        input: _input(name: '更新书源'),
      );

      expect(service.createdInputs, isEmpty);
      expect(service.updatedInputs.keys, <String>['source_5']);
      expect(service.updatedInputs['source_5']!.name, '更新书源');
      expect(saved.id, 'source_5');
      expect(refreshCount, 1);
    },
  );

  test('submit keeps note and refreshes after success', () async {
    var refreshCount = 0;
    final service = _FakePrivateBookSourceService();
    final controller = PrivateBookSourceActionController(
      service: service,
      refresh: () => refreshCount += 1,
    );

    await controller.submit(_source(id: 'source_3'), '请审核');

    expect(service.submitted, <String, String>{'source_3': '请审核'});
    expect(refreshCount, 1);
  });

  test('test passes config to service and refreshes after result', () async {
    var refreshCount = 0;
    final service = _FakePrivateBookSourceService();
    final controller = PrivateBookSourceActionController(
      service: service,
      refresh: () => refreshCount += 1,
    );

    final result = await controller.test(
      _source(id: 'source_4'),
      keyword: '关键词',
      timeoutMs: 15000,
      checkItems: const <String>['domain', 'search'],
    );

    expect(service.testedId, 'source_4');
    expect(service.testedKeyword, '关键词');
    expect(service.testedTimeoutMs, 15000);
    expect(service.testedCheckItems, <String>['domain', 'search']);
    expect(result.item.id, 'source_4');
    expect(refreshCount, 1);
  });

  test('manual refresh invokes injected provider invalidation boundary', () {
    var refreshCount = 0;
    final controller = PrivateBookSourceActionController(
      service: _FakePrivateBookSourceService(),
      refresh: () => refreshCount += 1,
    );

    controller.refresh();

    expect(refreshCount, 1);
  });

  test('create group delegates and refreshes group boundary', () async {
    var sourceRefreshCount = 0;
    var groupRefreshCount = 0;
    final service = _FakePrivateBookSourceService();
    final controller = PrivateBookSourceActionController(
      service: service,
      refresh: () => sourceRefreshCount += 1,
      refreshGroups: () => groupRefreshCount += 1,
    );

    final group = await controller.createGroup('常用');

    expect(service.createdGroupNames, <String>['常用']);
    expect(group.name, '常用');
    expect(sourceRefreshCount, 0);
    expect(groupRefreshCount, 1);
  });

  test(
    'rename group selects updated group and refreshes group boundary',
    () async {
      var selectedGroupId = '';
      var groupRefreshCount = 0;
      final service = _FakePrivateBookSourceService();
      final controller = PrivateBookSourceActionController(
        service: service,
        refresh: () {},
        refreshGroups: () => groupRefreshCount += 1,
        selectGroup: (groupId) => selectedGroupId = groupId,
      );

      final group = await controller.renameGroup(_group(id: 'group_1'), '备用');

      expect(service.updatedGroups, <String, String>{'group_1': '备用'});
      expect(group.id, 'group_1');
      expect(group.name, '备用');
      expect(selectedGroupId, 'group_1');
      expect(groupRefreshCount, 1);
    },
  );

  test(
    'delete group clears selected group through injected boundary',
    () async {
      var clearedGroupId = '';
      var groupRefreshCount = 0;
      final service = _FakePrivateBookSourceService();
      final controller = PrivateBookSourceActionController(
        service: service,
        refresh: () {},
        refreshGroups: () => groupRefreshCount += 1,
        clearSelectedGroupIf: (groupId) => clearedGroupId = groupId,
      );

      await controller.deleteGroup(_group(id: 'group_2'));

      expect(service.deletedGroupIds, <String>['group_2']);
      expect(clearedGroupId, 'group_2');
      expect(groupRefreshCount, 1);
    },
  );
}

class _FakePrivateBookSourceService extends PrivateBookSourceService {
  String? loadedId;
  final List<String> deletedIds = <String>[];
  final Map<String, String> submitted = <String, String>{};
  final List<PrivateBookSourceInput> createdInputs = <PrivateBookSourceInput>[];
  final Map<String, PrivateBookSourceInput> updatedInputs =
      <String, PrivateBookSourceInput>{};
  final List<String> createdGroupNames = <String>[];
  final Map<String, String> updatedGroups = <String, String>{};
  final List<String> deletedGroupIds = <String>[];
  String? testedId;
  String? testedKeyword;
  int? testedTimeoutMs;
  List<String>? testedCheckItems;

  @override
  Future<PrivateBookSourceItem> get(String id) async {
    loadedId = id;
    return _source(id: id, name: '详情源', sourceJson: '{"ok":true}');
  }

  @override
  Future<void> delete(String id) async {
    deletedIds.add(id);
  }

  @override
  Future<void> submit(String id, String note) async {
    submitted[id] = note;
  }

  @override
  Future<PrivateBookSourceItem> create(PrivateBookSourceInput input) async {
    createdInputs.add(input);
    return _source(id: 'created_${createdInputs.length}', name: input.name);
  }

  @override
  Future<PrivateBookSourceItem> update(
    String id,
    PrivateBookSourceInput input,
  ) async {
    updatedInputs[id] = input;
    return _source(id: id, name: input.name);
  }

  @override
  Future<PrivateBookSourceTestResult> test(
    String id, {
    String keyword = '',
    int? timeoutMs,
    List<String> checkItems = const <String>[],
  }) async {
    testedId = id;
    testedKeyword = keyword;
    testedTimeoutMs = timeoutMs;
    testedCheckItems = checkItems;
    return PrivateBookSourceTestResult(
      item: _source(id: id, lastTestStatus: 'passed'),
      quota: null,
      report: null,
      raw: const <String, dynamic>{},
    );
  }

  @override
  Future<PrivateBookSourceGroup> createGroup(String name) async {
    createdGroupNames.add(name);
    return _group(id: 'group_${createdGroupNames.length}', name: name);
  }

  @override
  Future<PrivateBookSourceGroup> updateGroup(String id, String name) async {
    updatedGroups[id] = name;
    return _group(id: id, name: name);
  }

  @override
  Future<void> deleteGroup(String id) async {
    deletedGroupIds.add(id);
  }
}

PrivateBookSourceItem _source({
  required String id,
  String name = '测试源',
  String sourceJson = '{}',
  String lastTestStatus = '',
}) {
  return PrivateBookSourceItem(
    id: id,
    name: name,
    supportedTypes: const <String>['novel'],
    sourceCode: '',
    sourceJson: sourceJson,
    description: '',
    groupName: '',
    visibility: 'private',
    enabled: true,
    compatibilityReport: '',
    normalizationStatus: '',
    normalizationError: '',
    reviewStatus: '',
    reviewNote: '',
    lastTestStatus: lastTestStatus,
    lastTestMessage: '',
    createdAt: null,
    updatedAt: null,
  );
}

PrivateBookSourceInput _input({required String name}) {
  return PrivateBookSourceInput(
    name: name,
    supportedTypes: const <String>['novel'],
    sourceCode: '{"name":"$name"}',
    description: '',
    groupName: '',
  );
}

PrivateBookSourceGroup _group({required String id, String name = '分组'}) {
  return PrivateBookSourceGroup(
    id: id,
    code: id,
    name: name,
    scopeType: 'private',
    ownerUserId: 'owner',
    enabled: true,
  );
}
