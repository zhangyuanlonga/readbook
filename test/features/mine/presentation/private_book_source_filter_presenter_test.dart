import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/mine/application/private_book_source_service.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/private_book_source_filter_presenter.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/widgets/private_book_source_more_menu_button.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/widgets/private_book_source_tile.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/widgets/private_book_source_toolbar.dart';

void main() {
  group('PrivateBookSourceListFilter', () {
    test('returns original list when keyword is blank', () {
      final items = <PrivateBookSourceItem>[
        _source(id: 'source_1', name: '青石书源'),
      ];

      expect(PrivateBookSourceListFilter.filter(items, '  '), same(items));
    });

    test('matches source fields and presentation labels', () {
      final items = <PrivateBookSourceItem>[
        _source(
          id: 'source_1',
          name: '漫画仓库',
          supportedTypes: const <String>['comic'],
          groupName: '图像',
          visibility: 'shared',
          reviewStatus: 'approved',
          normalizationStatus: 'failed',
          normalizationError: '规则缺失',
          lastTestStatus: 'passed',
        ),
        _source(
          id: 'source_2',
          name: '私人小说',
          supportedTypes: const <String>['novel'],
          groupName: '',
          visibility: 'private',
          reviewStatus: '',
          normalizationStatus: 'done',
          lastTestStatus: 'failed',
          lastTestMessage: '连接超时',
        ),
      ];

      expect(_idsFor(items, '漫画'), <String>['source_1']);
      expect(_idsFor(items, '配置异常'), <String>['source_1']);
      expect(_idsFor(items, '规则缺失'), <String>['source_1']);
      expect(_idsFor(items, '未分组'), <String>['source_2']);
      expect(_idsFor(items, '私人'), <String>['source_2']);
      expect(_idsFor(items, '失败'), <String>['source_2']);
      expect(_idsFor(items, '连接超时'), <String>['source_2']);
    });
  });

  group('PrivateBookSourceGroupFilterPresenter', () {
    test('resolves selected label and stale selection', () {
      final groups = <PrivateBookSourceGroup>[
        _group(id: 'group_1', name: '玄幻'),
        _group(id: 'group_2', name: ''),
      ];

      expect(
        PrivateBookSourceGroupFilterPresenter.selectedLabel(groups, 'group_1'),
        '玄幻',
      );
      expect(
        PrivateBookSourceGroupFilterPresenter.selectedLabel(groups, 'group_2'),
        '未分组',
      );
      expect(
        PrivateBookSourceGroupFilterPresenter.selectedLabel(groups, 'missing'),
        '全部分组',
      );
      expect(
        PrivateBookSourceGroupFilterPresenter.isSelectionStale(
          groups,
          'missing',
        ),
        isTrue,
      );
      expect(
        PrivateBookSourceGroupFilterPresenter.isSelectionStale(groups, null),
        isFalse,
      );
    });
  });

  group('PrivateBookSourceMoreMenuRules', () {
    test('keeps submit and edit availability aligned with visibility', () {
      final privateItem = _source(id: 'private', visibility: 'private');
      final sharedItem = _source(id: 'shared', visibility: 'shared');

      expect(PrivateBookSourceMoreMenuRules.canSubmit(privateItem), isTrue);
      expect(PrivateBookSourceMoreMenuRules.canEdit(privateItem), isTrue);
      expect(PrivateBookSourceMoreMenuRules.canSubmit(sharedItem), isFalse);
      expect(PrivateBookSourceMoreMenuRules.canEdit(sharedItem), isFalse);
    });
  });

  testWidgets('PrivateBookSourceTile renders badges and opens detail', (
    tester,
  ) async {
    var openedDetail = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivateBookSourceTile(
            item: _source(
              id: 'source_1',
              name: '测试书源',
              description: '备用源',
              groupName: '分组 A',
              lastTestStatus: 'failed',
              lastTestMessage: '响应解析失败',
            ),
            onDetail: () => openedDetail = true,
            onEdit: () {},
            onDelete: () {},
            onTest: () {},
            onSubmit: () {},
          ),
        ),
      ),
    );

    expect(find.text('测试书源'), findsOneWidget);
    expect(find.text('小说'), findsOneWidget);
    expect(find.text('分组 A'), findsOneWidget);
    expect(find.text('私人'), findsOneWidget);
    expect(find.text('检测 失败 响应解析失败'), findsOneWidget);

    await tester.tap(find.text('测试书源'));

    expect(openedDetail, isTrue);
  });

  testWidgets('PrivateBookSourceToolbar wires search and group label', (
    tester,
  ) async {
    var changedKeyword = '';
    var cleared = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivateBookSourceToolbar(
            keyword: '漫画',
            selectedGroupId: 'group_1',
            groupsAsync: AsyncValue.data(<PrivateBookSourceGroup>[
              _group(id: 'group_1', name: '常用'),
            ]),
            onKeywordChanged: (value) => changedKeyword = value,
            onKeywordCleared: () => cleared = true,
            onGroupSelected: (_) {},
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.text('常用'), findsOneWidget);
    expect(find.byTooltip('清空搜索'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '小说');
    expect(changedKeyword, '小说');

    await tester.tap(find.byTooltip('清空搜索'));
    expect(cleared, isTrue);
  });

  testWidgets('PrivateBookSourceGroupPickerSurface shows selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivateBookSourceGroupPickerSurface(
            groups: <PrivateBookSourceGroup>[
              _group(id: 'group_1', name: '常用'),
              _group(id: 'group_2', name: '备用'),
            ],
            selectedGroupId: 'group_2',
          ),
        ),
      ),
    );

    expect(find.text('选择分组'), findsOneWidget);
    expect(find.text('全部分组'), findsOneWidget);
    expect(find.text('常用'), findsOneWidget);
    expect(find.text('备用'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}

List<String> _idsFor(List<PrivateBookSourceItem> items, String keyword) {
  return PrivateBookSourceListFilter.filter(
    items,
    keyword,
  ).map((item) => item.id).toList(growable: false);
}

PrivateBookSourceItem _source({
  required String id,
  String name = '测试书源',
  List<String> supportedTypes = const <String>['novel'],
  String description = '',
  String groupName = '',
  String visibility = 'private',
  String reviewStatus = 'pending',
  String normalizationStatus = '',
  String normalizationError = '',
  String lastTestStatus = '',
  String lastTestMessage = '',
}) {
  return PrivateBookSourceItem(
    id: id,
    name: name,
    supportedTypes: supportedTypes,
    sourceCode: '',
    sourceJson: '{}',
    description: description,
    groupName: groupName,
    visibility: visibility,
    enabled: true,
    compatibilityReport: '',
    normalizationStatus: normalizationStatus,
    normalizationError: normalizationError,
    reviewStatus: reviewStatus,
    reviewNote: '',
    lastTestStatus: lastTestStatus,
    lastTestMessage: lastTestMessage,
    createdAt: null,
    updatedAt: null,
  );
}

PrivateBookSourceGroup _group({required String id, required String name}) {
  return PrivateBookSourceGroup(
    id: id,
    code: id,
    name: name,
    scopeType: 'private',
    ownerUserId: 'user_1',
    enabled: true,
  );
}
