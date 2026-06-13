import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_page_support_models.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/sheets/reader_settings/reader_settings_background_tiles_presenter.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/sheets/reader_settings/reader_settings_sheet_frame.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/sheets/reader_settings/reader_settings_sheet_session.dart';

void main() {
  testWidgets('settings sheet session deduplicates normalized persistence', (
    tester,
  ) async {
    var draft = const ReaderSettings(autoReadEnabled: true);
    final persisted = <ReaderSettings>[];
    final session = ReaderSettingsSheetSession(
      initialSettings: const ReaderSettings(),
      currentDraft: () => draft,
      isMounted: () => true,
      persistSettings: (settings) async => persisted.add(settings),
    );

    await session.persistNow();
    expect(persisted, isEmpty);

    draft = const ReaderSettings(fontSize: 20, autoReadEnabled: true);
    await session.persistNow();
    await session.persistNow();

    expect(persisted, hasLength(1));
    expect(persisted.single.fontSize, 20);
    expect(persisted.single.autoReadEnabled, isFalse);
  });

  testWidgets('settings sheet session schedules and cancels persistence', (
    tester,
  ) async {
    var draft = const ReaderSettings(fontSize: 21);
    final persisted = <ReaderSettings>[];
    final session = ReaderSettingsSheetSession(
      initialSettings: const ReaderSettings(),
      currentDraft: () => draft,
      isMounted: () => true,
      persistSettings: (settings) async => persisted.add(settings),
      persistDelay: const Duration(milliseconds: 30),
    );

    session.schedulePersistDraft();
    await tester.pump(const Duration(milliseconds: 29));
    expect(persisted, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(persisted.map((settings) => settings.fontSize), [21]);

    draft = const ReaderSettings(fontSize: 22);
    session.schedulePersistDraft();
    session.cancelTimers();
    await tester.pump(const Duration(milliseconds: 30));

    expect(persisted.map((settings) => settings.fontSize), [21]);
  });

  testWidgets('settings sheet session restores slider preview after delay', (
    tester,
  ) async {
    var notifyCount = 0;
    final session = ReaderSettingsSheetSession(
      initialSettings: const ReaderSettings(),
      currentDraft: () => const ReaderSettings(),
      isMounted: () => true,
      persistSettings: (_) async {},
      sliderRestoreDelay: const Duration(milliseconds: 40),
    );

    session.setSliderInteractionPreview(
      true,
      canUpdate: () => true,
      notifyChanged: () => notifyCount += 1,
    );
    expect(session.isSliderInteracting, isTrue);
    expect(notifyCount, 1);

    session.setSliderInteractionPreview(
      false,
      delayedRestore: true,
      canUpdate: () => true,
      notifyChanged: () => notifyCount += 1,
    );
    await tester.pump(const Duration(milliseconds: 39));
    expect(session.isSliderInteracting, isTrue);

    await tester.pump(const Duration(milliseconds: 1));
    expect(session.isSliderInteracting, isFalse);
    expect(notifyCount, 2);
  });

  test('background tiles presenter resolves preset and custom tiles', () {
    const presenter = ReaderSettingsBackgroundTilesPresenter();
    var selectedSource = '';
    final selection = presenter.resolveSelection(
      activeBackgroundValue: 'preset-base64',
      presetValues: const ['preset-base64'],
    );

    expect(selection.hasBackgroundImage, isTrue);
    expect(selection.isPresetBackground, isTrue);

    final presetTiles = presenter.buildPresetTiles(
      presets: const [
        ReaderBackgroundPreset(label: '预设', assetPath: 'asset/bg.jpg'),
      ],
      presetBytes: {
        'asset/bg.jpg': Uint8List.fromList([1, 2, 3]),
      },
      presetBase64: const {'asset/bg.jpg': 'preset-base64'},
      activeBackgroundValue: 'preset-base64',
      onSelectPreset: (source) => selectedSource = source,
    );

    expect(presetTiles, hasLength(1));
    expect(presetTiles.single.selected, isTrue);
    presetTiles.single.onTap();
    expect(selectedSource, 'asset/bg.jpg');

    final customSelection = presenter.resolveSelection(
      activeBackgroundValue: 'file://custom-a',
      presetValues: const ['preset-base64'],
    );
    final customTiles = presenter.buildCustomTiles(
      customBackgrounds: const ['file://custom-a', 'file://missing-preview'],
      customPreviewBytes: {
        'file://custom-a': Uint8List.fromList([4]),
      },
      selection: customSelection,
      onSelectCustom: (source) => selectedSource = source,
    );

    expect(customTiles, hasLength(2));
    expect(customTiles.first.selected, isTrue);
    expect(customTiles.first.icon, isNull);
    expect(customTiles.last.previewBytes, isNull);
    expect(customTiles.last.icon, Icons.broken_image_outlined);
  });

  test('background color options include theme palette tones', () {
    expect(
      readerPaletteSeedColorForTone(ReaderBackgroundTone.pineGreenTint),
      isNotNull,
    );
    expect(readerPaletteSeedColorForTone(ReaderBackgroundTone.surface), isNull);
  });

  testWidgets('settings sheet frame renders title, children, and back action', (
    tester,
  ) async {
    var backCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 420,
            child: ReaderSettingsSheetFrame(
              title: '字体',
              safeBottom: 0,
              onBack: () => backCount += 1,
              children: const [Text('字号设置')],
            ),
          ),
        ),
      ),
    );

    expect(find.text('字体'), findsOneWidget);
    expect(find.text('字号设置'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    expect(backCount, 1);
  });
}
