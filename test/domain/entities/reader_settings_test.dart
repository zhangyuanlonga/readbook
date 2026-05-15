import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';

void main() {
  group('ReaderDocument.fromContent', () {
    test('merges single line breaks inside the same paragraph', () {
      final document = ReaderDocument.fromContent(
        content: '第一行\n第二行\n\n第三段',
      );

      expect(document.paragraphs, <String>['第一行第二行', '第三段']);
    });

    test('collapses excessive blank lines to one paragraph break', () {
      final document = ReaderDocument.fromContent(
        content: '第一段\n\n\n\n第二段',
      );

      expect(document.paragraphs, <String>['第一段', '第二段']);
    });
  });

  group('ReaderSettings.fromJson', () {
    test('defaults textFullJustifyEnabled to true when missing', () {
      final settings = ReaderSettings.fromJson(const <String, dynamic>{});

      expect(settings.textFullJustifyEnabled, isTrue);
    });
  });
}
