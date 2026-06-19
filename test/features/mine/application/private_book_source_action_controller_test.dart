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
}

class _FakePrivateBookSourceService extends PrivateBookSourceService {
  String? loadedId;
  final List<String> deletedIds = <String>[];
  final Map<String, String> submitted = <String, String>{};
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
