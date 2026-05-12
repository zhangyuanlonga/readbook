import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/app/motion/app_motion.dart';
import 'package:shuxiang_reading_next/app/motion/app_motion_widgets.dart';

void main() {
  testWidgets('AppAnimatedSwitcher swaps keyed children', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppAnimatedSwitcher(
            child: Text('loading', key: ValueKey<String>('loading')),
          ),
        ),
      ),
    );

    expect(find.text('loading'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppAnimatedSwitcher(
            child: Text('content', key: ValueKey<String>('content')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('AppFadeSlideTransition disables movement when motion is off', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: AppFadeSlideTransition(child: Text('instant'))),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('instant'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppFadeSlideTransition),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('AppStaggeredEntrance renders all children', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppMotionScope(
            enabled: false,
            child: AppStaggeredEntrance(
              children: [Text('first'), Text('second')],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('AppPressable keeps tap behavior intact', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppPressable(
              semanticLabel: 'open item',
              onTap: () {
                tapped = true;
              },
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(tapped, isTrue);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('AppLoadingStateSwitcher changes visible state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLoadingStateSwitcher(
            state: AppLoadingState.loading,
            loading: Text('loading'),
            empty: Text('empty'),
            error: Text('error'),
            content: Text('content'),
            enabled: false,
          ),
        ),
      ),
    );

    expect(find.text('loading'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLoadingStateSwitcher(
            state: AppLoadingState.content,
            loading: Text('loading'),
            empty: Text('empty'),
            error: Text('error'),
            content: Text('content'),
            enabled: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('content'), findsOneWidget);
    expect(find.text('loading'), findsNothing);
  });

  testWidgets('AppAnimatedStatusCard can hide and show content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppAnimatedStatusCard(
            icon: Icons.info_outline,
            title: '状态',
            message: '状态说明',
            enabled: false,
          ),
        ),
      ),
    );

    expect(find.text('状态'), findsOneWidget);
    expect(find.text('状态说明'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppAnimatedStatusCard(
            icon: Icons.info_outline,
            title: '状态',
            message: '状态说明',
            visible: false,
            enabled: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('状态'), findsNothing);
  });
}
