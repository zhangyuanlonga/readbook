import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/sheets/reader_settings/reader_settings_sections.dart';

void main() {
  testWidgets('reader setting section widgets expose independent boundaries', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ReaderTypographySettingsSection(children: [Text('font')]),
              ReaderThemeBackgroundSettingsSection(children: [Text('theme')]),
              ReaderLayoutSettingsSection(children: [Text('layout')]),
              ReaderPageTurnSettingsSection(children: [Text('turn')]),
              ReaderAutoReadSettingsSection(children: [Text('auto')]),
              ReaderAudioSettingsSection(children: [Text('audio')]),
              ReaderMangaSettingsSection(children: [Text('manga')]),
            ],
          ),
        ),
      ),
    );

    expect(find.text('font'), findsOneWidget);
    expect(find.text('theme'), findsOneWidget);
    expect(find.text('layout'), findsOneWidget);
    expect(find.text('turn'), findsOneWidget);
    expect(find.text('auto'), findsOneWidget);
    expect(find.text('audio'), findsOneWidget);
    expect(find.text('manga'), findsOneWidget);
  });
}
