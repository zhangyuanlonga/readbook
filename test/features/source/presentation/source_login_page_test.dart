import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/domain/entities/script_source.dart';
import 'package:shuxiang_reading_next/domain/repositories/script_source_repository.dart';
import 'package:shuxiang_reading_next/features/source/application/source_login_runtime_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_facade.dart';
import 'package:shuxiang_reading_next/features/source/presentation/source_login_page.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_contract.dart';

void main() {
  testWidgets('renders login fields and submits form data', (tester) async {
    final service = _FakeSourceLoginRuntimeService();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SourceLoginPage(
            sourceId: 'source_login',
            sourceLoginRuntimeService: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('测试登录源'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
    expect(find.text('开启'), findsOneWidget);
    expect(find.text('发送验证码'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '账号'), 'alice');
    await tester.enterText(find.widgetWithText(TextField, '密码'), 'secret');

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('邮箱').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('确认'));
    await tester.pumpAndSettle();

    expect(service.submitCount, 1);
    expect(service.lastActionCode, isNull);
    expect(service.lastFormData['账号'], 'alice');
    expect(service.lastFormData['密码'], 'secret');
    expect(service.lastFormData['登录方式'], '邮箱');
    expect(service.lastFormData['段评'], 'off');
  });
}

class _FakeSourceLoginRuntimeService extends SourceLoginRuntimeService {
  _FakeSourceLoginRuntimeService()
    : super(sourceRuntimeFacade: _FakeSourceRuntimeFacade());

  int submitCount = 0;
  String? lastActionCode;
  Map<String, String> lastFormData = const <String, String>{};

  final SourceLoginPresentation _presentation = SourceLoginPresentation(
    sourceId: 'source_login',
    sourceName: '测试登录源',
    fields: const <SourceLoginField>[
      SourceLoginField(name: '账号', type: SourceLoginFieldType.text),
      SourceLoginField(name: '密码', type: SourceLoginFieldType.password),
      SourceLoginField(
        name: '登录方式',
        type: SourceLoginFieldType.select,
        options: <SourceLoginFieldOption>[
          SourceLoginFieldOption(label: '扫码', value: '扫码'),
          SourceLoginFieldOption(label: '邮箱', value: '邮箱'),
        ],
        defaultValue: '扫码',
      ),
      SourceLoginField(
        name: '段评',
        type: SourceLoginFieldType.toggle,
        options: <SourceLoginFieldOption>[
          SourceLoginFieldOption(label: '关闭', value: 'off'),
          SourceLoginFieldOption(label: '开启', value: 'on'),
        ],
        defaultValue: 'off',
        style: SourceLoginFieldStyle(layoutFlexBasisPercent: 0.5),
      ),
      SourceLoginField(
        name: '发送验证码',
        type: SourceLoginFieldType.button,
        action: 'sendCode()',
        style: SourceLoginFieldStyle(layoutFlexBasisPercent: 0.5),
      ),
    ],
    formData: const <String, String>{'登录方式': '扫码', '段评': 'off'},
  );

  @override
  Future<bool> supportsLogin(String sourceId) async => true;

  @override
  Future<SourceLoginPresentation?> loadPresentation(
    String sourceId, {
    ui = const SourceUiContext(),
    book,
    chapter,
  }) async {
    return _presentation;
  }

  @override
  Future<SourceLoginActionResult> submit(
    String sourceId, {
    required Map<String, String> formData,
    ui = const SourceUiContext(),
    book,
    chapter,
    String? actionCode,
    bool isLongClick = false,
  }) async {
    submitCount += 1;
    lastActionCode = actionCode;
    lastFormData = Map<String, String>.from(formData);
    return SourceLoginActionResult(
      presentation: SourceLoginPresentation(
        sourceId: _presentation.sourceId,
        sourceName: _presentation.sourceName,
        fields: _presentation.fields,
        formData: formData,
      ),
      message: actionCode == null ? '登录已执行' : '按钮动作已执行',
    );
  }
}

class _FakeSourceRuntimeFacade extends SourceRuntimeFacade {
  _FakeSourceRuntimeFacade() : super(scriptSourceRepository: _FakeSourceRepo());
}

class _FakeSourceRepo implements ScriptSourceRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<List<ScriptSource>> getAll() async => const <ScriptSource>[];

  @override
  Future<ScriptSource?> getById(String id) async => null;

  @override
  Future<void> upsert(ScriptSource source) async {}

  @override
  Future<void> setEnabled({required String id, required bool enabled}) async {}

  @override
  Stream<List<ScriptSource>> watchAll() =>
      const Stream<List<ScriptSource>>.empty();
}
