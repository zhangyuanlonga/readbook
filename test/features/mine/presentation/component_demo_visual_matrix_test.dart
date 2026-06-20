import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/component_demo_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory documentsDir;
  late Directory supportDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    documentsDir = await Directory.systemTemp.createTemp(
      'component_demo_visual_docs_',
    );
    supportDir = await Directory.systemTemp.createTemp(
      'component_demo_visual_support_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return documentsDir.path;
          }
          if (call.method == 'getApplicationSupportDirectory') {
            return supportDir.path;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
    if (supportDir.existsSync()) {
      await supportDir.delete(recursive: true);
    }
  });

  for (final scenario in _scenarios) {
    testWidgets('component demo visual matrix ${scenario.name}', (
      tester,
    ) async {
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
        tester.view.resetDevicePixelRatio();
      });
      tester.view.devicePixelRatio = scenario.devicePixelRatio;
      await tester.binding.setSurfaceSize(scenario.size);

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp(home: const ComponentDemoPage())),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.scrollUntilVisible(
        find.text('页面状态'),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('页面状态'), findsOneWidget);
      expect(find.text('导入失败'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('业务模式'),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('业务模式'), findsOneWidget);
      expect(find.text('书籍卡'), findsOneWidget);
      expect(find.text('资源 Tile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

const _scenarios = <_ComponentDemoVisualScenario>[
  _ComponentDemoVisualScenario(
    name: 'lumina_mobile',
    size: Size(390, 844),
    devicePixelRatio: 3,
  ),
  _ComponentDemoVisualScenario(
    name: 'lumina_desktop',
    size: Size(1280, 800),
    devicePixelRatio: 1,
  ),
];

class _ComponentDemoVisualScenario {
  const _ComponentDemoVisualScenario({
    required this.name,
    required this.size,
    required this.devicePixelRatio,
  });

  final String name;
  final Size size;
  final double devicePixelRatio;
}
