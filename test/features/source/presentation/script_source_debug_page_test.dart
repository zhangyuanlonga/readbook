import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shuxiang_reading_next/features/source/presentation/script_source_debug_page.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_script_template.dart';

void main() {
  testWidgets('ScriptSourceDebugPage renders without exceptions', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ScriptSourceDebugPage(
            sourceCode: sourceScriptTemplateV1,
            autoRunOnInit: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('调试关键词'), findsOneWidget);
    expect(find.text('重新执行'), findsOneWidget);
    expect(find.byTooltip('复制'), findsNWidgets(3));
  });
}
