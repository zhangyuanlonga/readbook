import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';

void main() {
  group('ReaderDocument.fromContent', () {
    test('merges single line breaks inside the same paragraph', () {
      final document = ReaderDocument.fromContent(content: '第一行\n第二行\n\n第三段');

      expect(document.paragraphs, <String>['第一行第二行', '第三段']);
    });

    test('collapses excessive blank lines to one paragraph break', () {
      final document = ReaderDocument.fromContent(content: '第一段\n\n\n\n第二段');

      expect(document.paragraphs, <String>['第一段', '第二段']);
    });
  });

  group('ReaderSettings.fromJson', () {
    test('defaults textFullJustifyEnabled to true when missing', () {
      final settings = ReaderSettings.fromJson(const <String, dynamic>{});

      expect(settings.textFullJustifyEnabled, isTrue);
    });

    test('restores auto read options and clamps speed level', () {
      final settings = ReaderSettings.fromJson(const <String, dynamic>{
        'autoReadMode': 'page',
        'autoReadSpeed': 66.0,
        'autoReadSpeedLevel': 99,
        'autoReadPauseMode': 'chapterEnd',
        'autoReadEndBehavior': 'loopBook',
      });

      expect(settings.autoReadMode, ReaderAutoReadMode.page);
      expect(settings.autoReadSpeed, 66);
      expect(settings.autoReadSpeedLevel, ReaderSettings.maxAutoReadSpeedLevel);
      expect(settings.autoReadPauseMode, ReaderAutoReadPauseMode.chapterEnd);
      expect(settings.autoReadEndBehavior, ReaderAutoReadEndBehavior.loopBook);
    });

    test('derives auto read speed level from legacy speed', () {
      final settings = ReaderSettings.fromJson(const <String, dynamic>{
        'autoReadSpeed': 120.0,
      });

      expect(settings.autoReadSpeedLevel, ReaderSettings.maxAutoReadSpeedLevel);
    });

    test('restores tap zone actions and falls back on invalid payload', () {
      final settings = ReaderSettings.fromJson(const <String, dynamic>{
        'tapZoneActions': <String>[
          'catalog',
          'none',
          'bookmark',
          'previousPage',
          'toggleToolbar',
          'nextPage',
          'previousPage',
          'autoRead',
          'nightMode',
        ],
      });
      final fallback = ReaderSettings.fromJson(const <String, dynamic>{
        'tapZoneActions': <String>['catalog'],
      });

      expect(settings.tapZoneActions[0], ReaderTapZoneAction.catalog);
      expect(settings.tapZoneActions[8], ReaderTapZoneAction.nightMode);
      expect(fallback.tapZoneActions, ReaderSettings.defaultTapZoneActions);
    });
  });
}
