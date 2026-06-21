import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_font_registry_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_settings_groups.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/sheets/reader_settings/reader_audio_settings_section.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/sheets/reader_settings/reader_auto_read_settings_section.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/sheets/reader_settings/reader_font_picker_sheet.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/sheets/reader_settings/reader_font_weight_sheet.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/sheets/reader_settings/reader_layout_settings_section.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/sheets/reader_settings/reader_manga_settings_section.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/sheets/reader_settings/reader_page_turn_settings_section.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/sheets/reader_settings/reader_settings_sections.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/sheets/reader_settings/reader_tap_zone_editor_sheet.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/sheets/reader_settings/reader_theme_background_settings_section.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/sheets/reader_settings/reader_typography_settings_section.dart';

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

  testWidgets('typography settings panel renders core controls', (
    tester,
  ) async {
    var latest = const ReaderSettings();

    await tester.pumpWidget(
      _wrap(
        ReaderTypographySettingsPanel(
          settings: latest,
          currentFontLabel: '默认',
          fontWeightLabel: '常规',
          compactScale: 1,
          sliderBuilder: _sliderBuilder,
          onChanged: (next) => latest = next,
          onOpenFontPicker: () {},
          onManageFonts: () {},
          onOpenFontWeightSheet: () {},
          onPickBodyTextColor: (_, _) async => null,
          onRememberBodyTextColor: (_) async {},
          onPickBodyTextShadowColor: (_, _) async => null,
          onPickBodyTextDecorationColor: (_, _) async => null,
        ),
      ),
    );

    expect(find.text('字体'), findsOneWidget);
    expect(find.text('字重'), findsOneWidget);
    expect(find.text('字号'), findsOneWidget);
    expect(find.text('字体颜色'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    expect(latest.fontSize, greaterThan(const ReaderSettings().fontSize));
  });

  testWidgets('layout info settings panel renders layout cards', (
    tester,
  ) async {
    var latest = const ReaderSettings();

    await tester.pumpWidget(
      _wrap(
        ReaderLayoutInfoSettingsPanel(
          settings: latest,
          groups: latest.grouped,
          compactScale: 1,
          marginControlStep: 2,
          sliderBuilder: _sliderBuilder,
          onChanged: (next) => latest = next,
          formatLayoutMarginValue: (value) => value.toStringAsFixed(0),
          letterSpacingSliderValue: (_) => 50,
          letterSpacingValueLabel: (_) => '默认',
          letterSpacingFromSliderValue:
              (_) => ReaderSettings.defaultLetterSpacing,
          lineHeightSliderValue: (_) => 10,
          lineHeightValueLabel: (_) => '1.67',
          lineHeightFromSliderValue:
              ({required sliderValue, required settings}) => 1.67,
          paragraphSpacingValueLabel: (_) => '2',
          paragraphIndentValueLabel: (_) => '2',
          readerBatteryReadFailed: false,
        ),
      ),
    );

    expect(find.text('正文边距'), findsOneWidget);
    expect(find.text('阅读排版'), findsOneWidget);
    expect(find.text('章节头'), findsOneWidget);
    expect(find.text('信息位'), findsOneWidget);

    expect(latest.infoFooterEnabled, isFalse);
  });

  testWidgets('layout margin sliders commit after drag ends', (tester) async {
    var latest = const ReaderSettings();

    await tester.pumpWidget(
      _wrap(
        ReaderLayoutInfoSettingsPanel(
          settings: latest,
          groups: latest.grouped,
          compactScale: 1,
          marginControlStep: 1,
          sliderBuilder: _sliderBuilder,
          onChanged: (next) => latest = next,
          formatLayoutMarginValue: (value) => value.toStringAsFixed(0),
          letterSpacingSliderValue: (_) => 50,
          letterSpacingValueLabel: (_) => '默认',
          letterSpacingFromSliderValue:
              (_) => ReaderSettings.defaultLetterSpacing,
          lineHeightSliderValue: (_) => 10,
          lineHeightValueLabel: (_) => '1.67',
          lineHeightFromSliderValue:
              ({required sliderValue, required settings}) => 1.67,
          paragraphSpacingValueLabel: (_) => '2',
          paragraphIndentValueLabel: (_) => '2',
          readerBatteryReadFailed: false,
        ),
      ),
    );

    final firstSlider = tester.widget<Slider>(find.byType(Slider).first);
    firstSlider.onChanged?.call(18);
    await tester.pump();

    expect(latest.bodyMarginTop, const ReaderSettings().bodyMarginTop);
    expect(tester.widget<Slider>(find.byType(Slider).first).value, 18);

    tester.widget<Slider>(find.byType(Slider).first).onChangeEnd?.call(18);
    await tester.pump();

    expect(latest.bodyMarginTop, 18);
  });

  testWidgets('page turn settings panels render animation and interaction', (
    tester,
  ) async {
    var latest = const ReaderSettings();

    await tester.pumpWidget(
      _wrap(
        Column(
          children: [
            ReaderInlinePageAnimationSelector(
              settings: latest,
              pageAnimationLabel: (style) => style.name,
              onChanged: (next) => latest = next,
            ),
            ReaderPageTurnInteractionSettingsPanel(
              settings: latest,
              compactScale: 1,
              isVolumeKeyPagingSupported: true,
              onOpenTapZoneEditor: () {},
              onChanged: (next) => latest = next,
            ),
            ReaderReadingBehaviorSettingsPanel(
              settings: latest,
              compactScale: 1,
              isVolumeKeyPagingSupported: true,
              volumeKeySupportDescription: '不支持',
              onChanged: (next) => latest = next,
            ),
          ],
        ),
      ),
    );

    expect(find.text('paperCurl'), findsOneWidget);
    expect(find.text('排版对齐'), findsOneWidget);
    expect(find.text('正文点击分区'), findsOneWidget);
    expect(find.text('快捷开关'), findsOneWidget);

    await tester.tap(find.text('curl'));
    expect(latest.pageAnimationStyle, ReaderPageAnimationStyle.curl);
  });

  testWidgets('auto, manga, and audio settings panels expose controls', (
    tester,
  ) async {
    var latest = const ReaderSettings();
    var startAfterApply = false;

    await tester.pumpWidget(
      _wrap(
        Column(
          children: [
            ReaderAutoReadSettingsPanel(
              settings: latest,
              compactScale: 1,
              sliderBuilder: _sliderBuilder,
              startAfterApply: startAfterApply,
              resolvePagedHoldDuration:
                  ({required speedLevel}) => const Duration(seconds: 2),
              onStartAfterApplyChanged: (enabled) => startAfterApply = enabled,
              onChanged: (next) => latest = next,
            ),
            ReaderMangaSettingsPanel(
              settings: latest,
              compactScale: 1,
              onChanged: (next) => latest = next,
            ),
            ReaderAudioSettingsPanel(
              settings: latest,
              compactScale: 1,
              sliderBuilder: _sliderBuilder,
              isVolumeKeyPagingSupported: true,
              onChanged: (next) => latest = next,
            ),
          ],
        ),
      ),
    );

    expect(find.text('自动阅读'), findsOneWidget);
    expect(find.text('漫画阅读'), findsOneWidget);
    expect(find.text('听书设置'), findsOneWidget);

    await tester.tap(find.text('自动翻页'));
    expect(latest.autoReadMode, ReaderAutoReadMode.page);

    await tester.tap(find.text('分页图'));
    expect(latest.mangaReadMode, ReaderMangaReadMode.paged);

    await tester.pumpWidget(
      _wrap(
        ReaderAudioSettingsPanel(
          settings: latest,
          compactScale: 1,
          sliderBuilder: _sliderBuilder,
          isVolumeKeyPagingSupported: true,
          onChanged: (next) => latest = next,
        ),
      ),
    );

    await tester.tap(find.byType(Switch).first);
    expect(latest.audioAutoPlay, isTrue);
  });

  testWidgets('theme background settings panel renders visual resources', (
    tester,
  ) async {
    var latest = const ReaderSettings();
    String? selectedGroup;
    var clearedBackground = false;

    await tester.pumpWidget(
      _wrap(
        ReaderThemeBackgroundSettingsPanel(
          settings: latest,
          contentMode: ReaderContentMode.text,
          compactScale: 1,
          backgroundTileScale: 1,
          sliderBuilder: _sliderBuilder,
          colorOptions: const [
            ReaderThemeBackgroundColorOption(
              label: '明亮',
              previewColor: Colors.white,
              mode: ReaderThemeMode.light,
              backgroundStyle: ReaderBackgroundStyle.plain,
              backgroundTone: ReaderBackgroundTone.surface,
            ),
          ],
          presetBackgroundTiles: [
            ReaderBackgroundImageTileData(
              label: '预设',
              selected: false,
              onTap:
                  () =>
                      latest = latest.copyWith(
                        backgroundImageBase64: 'asset/background.jpg',
                      ),
            ),
          ],
          customBackgroundTiles: const [],
          hasBackgroundImage: false,
          pageAnimationLabel: (style) => style.name,
          onChanged: (next) => latest = next,
          onSelectSettingsGroup: (groupKey) => selectedGroup = groupKey,
          onClearBackgroundImage: () => clearedBackground = true,
          onApplyCustomBackgroundImage: () {},
          onOpenBackgroundManagement: () {},
          onRemoveActiveBackground: null,
        ),
      ),
    );

    expect(find.text('文本阅读模式'), findsOneWidget);
    expect(find.text('背景色'), findsOneWidget);
    expect(find.text('背景图'), findsOneWidget);
    expect(find.text('翻页动画'), findsOneWidget);

    await tester.tap(find.text('护眼'));
    expect(latest.themeMode, ReaderThemeMode.sepia);

    await tester.tap(find.text('字体'));
    expect(selectedGroup, 'typography');

    await tester.tap(find.text('无背景'));
    expect(clearedBackground, isTrue);
  });

  testWidgets('font picker sheet content owns font selection UI', (
    tester,
  ) async {
    var latest = const ReaderSettings();
    var closeCount = 0;

    await tester.pumpWidget(
      _wrap(
        ReaderFontPickerSheetContent(
          settings: latest,
          availableCustomFonts: const [
            ReaderCustomFontEntry(
              fontFamilyKey: 'custom_font',
              displayName: '自定义字体',
              filePath: '/tmp/custom.ttf',
              importedAtEpochMs: 1,
            ),
          ],
          onChanged: (next) => latest = next,
          onImportCustomFont: (_) async => null,
          onClose: () => closeCount += 1,
          onManageFonts: () async {},
        ),
      ),
    );

    expect(find.text('选择字体'), findsOneWidget);
    expect(find.text('自定义字体'), findsOneWidget);

    await tester.tap(find.text('衬线'));
    await tester.pump();

    expect(latest.fontSource, ReaderFontSource.system);
    expect(latest.systemFontPreset, ReaderSystemFontPreset.serif);
    expect(closeCount, 1);
  });

  testWidgets('font weight sheet content updates weight values', (
    tester,
  ) async {
    var latest = const ReaderSettings();

    await tester.pumpWidget(
      _wrap(
        ReaderFontWeightSheetContent(
          settings: latest,
          onChanged: (next) => latest = next,
        ),
      ),
    );

    expect(find.text('字重'), findsOneWidget);
    expect(find.text('当前 500'), findsOneWidget);

    await tester.tap(find.text('粗'));
    await tester.pump();

    expect(latest.fontWeightLevel, ReaderFontWeightLevel.medium);
    expect(latest.fontWeightValue, 600);
  });

  testWidgets('tap zone editor content restores default actions', (
    tester,
  ) async {
    var latestActions = <ReaderTapZoneAction>[];

    await tester.pumpWidget(
      _wrap(
        ReaderTapZoneEditorContent(
          actions: List<ReaderTapZoneAction>.filled(
            9,
            ReaderTapZoneAction.none,
          ),
          onChanged: (next) => latestActions = next,
        ),
      ),
    );

    expect(find.text('点击分区'), findsOneWidget);
    expect(find.text('恢复默认'), findsOneWidget);

    await tester.ensureVisible(find.text('恢复默认'));
    await tester.pump();
    await tester.tap(find.text('恢复默认'));
    await tester.pump();

    expect(latestActions, ReaderSettings.defaultTapZoneActions);
  });

  testWidgets('tap zone editor action picker updates a cell', (tester) async {
    var latestActions = <ReaderTapZoneAction>[];

    await tester.pumpWidget(
      _wrap(
        ReaderTapZoneEditorContent(
          actions: List<ReaderTapZoneAction>.filled(
            9,
            ReaderTapZoneAction.none,
          ),
          onChanged: (next) => latestActions = next,
        ),
      ),
    );

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.text('下一页'), findsOneWidget);

    await tester.tap(find.text('下一页'));
    await tester.pumpAndSettle();

    expect(latestActions.first, ReaderTapZoneAction.nextPage);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

Widget _sliderBuilder({
  required double min,
  required double max,
  required int? divisions,
  required double value,
  required ValueChanged<double>? onChanged,
  ValueChanged<double>? onChangeEnd,
  String? label,
}) {
  return Slider(
    min: min,
    max: max,
    divisions: divisions,
    value: value.clamp(min, max).toDouble(),
    label: label,
    onChanged: onChanged,
    onChangeEnd: onChangeEnd,
  );
}
