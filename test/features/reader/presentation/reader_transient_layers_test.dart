import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/widgets/chrome/reader_transient_layers.dart';

void main() {
  testWidgets('overlay scrim intercepts taps when visible', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ReaderOverlayScrimLayer(
                animation: const AlwaysStoppedAnimation<double>(1),
                maxAlpha: 0.45,
                onTap: () {
                  tapped = true;
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(400, 300));

    expect(tapped, isTrue);
  });

  testWidgets('chapter loading indicator renders progress bar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ReaderChapterLoadingIndicatorLayer(
                animation: AlwaysStoppedAnimation<double>(0.5),
                showIndicator: true,
                topInset: 24,
                dividerColor: Colors.black26,
                indicatorColor: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
