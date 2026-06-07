import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/txt_chapter_rule_service.dart';

void main() {
  group('TxtChapterRuleService', () {
    test('loads built-in enabled chapter patterns only', () async {
      const service = TxtChapterRuleService();
      final enabledPatterns = await service.loadEnabledPatterns();

      expect(enabledPatterns, isNotEmpty);
      expect(enabledPatterns.every((item) => item.enabled), isTrue);
      expect(
        enabledPatterns.any((item) => item.name.contains('Chapter')),
        isTrue,
      );
    });
  });
}
