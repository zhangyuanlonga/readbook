import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/preferences/deprecated_keys_cleaner.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('cleans retired preference keys only once', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'reader.local.txt.chapterRules': '{"legacy":true}',
    });
    final prefs = await SharedPreferences.getInstance();
    final cleaner = DeprecatedKeysCleaner(preferences: prefs);

    final first = await cleaner.cleanOnce();
    final second = await cleaner.cleanOnce();

    expect(first.cleaned, isTrue);
    expect(first.removedKeys, <String>['reader.local.txt.chapterRules']);
    expect(prefs.getString('reader.local.txt.chapterRules'), isNull);
    expect(second.cleaned, isFalse);
    expect(second.removedKeys, isEmpty);
  });
}
