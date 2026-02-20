import 'package:flutter_appread/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app opens bookshelf first with expected tabs', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final closeButtonFinder = find.text('我知道了');
    if (closeButtonFinder.evaluate().isNotEmpty) {
      await tester.tap(closeButtonFinder);
      await tester.pumpAndSettle();
    }

    expect(find.text('书架'), findsWidgets);
    expect(find.text('去搜索'), findsOneWidget);
    expect(find.text('书源'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('错误'), findsNothing);
  });
}
