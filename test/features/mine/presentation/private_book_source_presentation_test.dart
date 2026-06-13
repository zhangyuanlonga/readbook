import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/mine/application/private_book_source_service.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/private_book_source_presentation.dart';

void main() {
  test('private source badges expose owner group and failed status', () {
    final badges = PrivateBookSourcePresentation.badgesFor(
      const PrivateBookSourceItem(
        id: 'source_1',
        name: '测试源',
        supportedTypes: <String>['novel'],
        sourceCode: '',
        sourceJson: '{}',
        description: '备用源',
        groupName: '分组 A',
        visibility: 'private',
        enabled: true,
        compatibilityReport: '',
        normalizationStatus: 'done',
        normalizationError: '',
        reviewStatus: '',
        reviewNote: '',
        lastTestStatus: 'failed',
        lastTestMessage: '响应解析失败',
        createdAt: null,
        updatedAt: null,
      ),
    );

    expect(
      badges.map((badge) => badge.label),
      containsAll(<String>['小说', '分组 A', '私人', '检测 失败 响应解析失败', '备用源']),
    );
    expect(
      badges.singleWhere((badge) => badge.label.startsWith('检测')).tone,
      PrivateBookSourceBadgeTone.danger,
    );
  });

  test('shared source badges keep shared label instead of hiding it', () {
    final badges = PrivateBookSourcePresentation.badgesFor(
      const PrivateBookSourceItem(
        id: 'source_2',
        name: '共享源',
        supportedTypes: <String>['comic'],
        sourceCode: '',
        sourceJson: '{}',
        description: '',
        groupName: '',
        visibility: 'shared',
        enabled: true,
        compatibilityReport: '',
        normalizationStatus: 'pending',
        normalizationError: '',
        reviewStatus: 'approved',
        reviewNote: '',
        lastTestStatus: 'passed',
        lastTestMessage: '',
        createdAt: null,
        updatedAt: null,
      ),
    );

    expect(
      badges.map((badge) => badge.label),
      containsAll(<String>['漫画', '未分组', '共享', '配置 待规整', '检测 通过']),
    );
  });
}
