import 'package:drift/native.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_appread/domain/entities/reader_replace_preference.dart';
import 'package:flutter_appread/domain/entities/reader_replace_rule.dart';
import 'package:flutter_appread/features/reader/application/reader_replace_rule_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderReplaceRuleService', () {
    late AppDatabase database;
    late ReaderReplaceRuleService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      database = AppDatabase(executor: NativeDatabase.memory());
      service = ReaderReplaceRuleService(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('parses MD3 legacy replace rule payload', () {
      const raw = '''
[
  {
    "replaceSummary": "去广告",
    "regex": "广告",
    "replacement": "",
    "isRegex": true,
    "useTo": "起点,测试源",
    "enable": true,
    "serialNumber": 7
  }
]
''';

      final rules = service.parseImportPayload(raw);

      expect(rules, hasLength(1));
      expect(rules.first.name, '去广告');
      expect(rules.first.pattern, '广告');
      expect(rules.first.replacement, '');
      expect(rules.first.isRegex, isTrue);
      expect(rules.first.scope, '起点,测试源');
      expect(rules.first.isEnabled, isTrue);
      expect(rules.first.sortOrder, 7);
    });

    test('uses global default when no book preference exists', () async {
      await service.saveEnabledByDefault(false);

      final mode = await service.resolveEffectiveMode(
        bookId: 'book-1',
        sourceId: 'source-a',
        detailUrl: 'https://example.com/book-1',
      );

      expect(mode, ReaderReplaceRuleMode.disabled);
    });

    test('book preference overrides global default', () async {
      await service.saveEnabledByDefault(false);
      await service.saveBookPreference(
        ReaderReplacePreference(
          bookId: 'book-1',
          sourceId: 'source-a',
          detailUrl: 'https://example.com/book-1',
          mode: ReaderReplaceRuleMode.enabled,
          updatedAt: DateTime(2026),
        ),
      );

      final mode = await service.resolveEffectiveMode(
        bookId: 'book-1',
        sourceId: 'source-a',
        detailUrl: 'https://example.com/book-1',
      );

      expect(mode, ReaderReplaceRuleMode.enabled);
    });

    test('disabled effective mode skips content rules', () async {
      await service.saveEnabledByDefault(false);
      await service.saveRule(
        ReaderReplaceRule(
          name: '去广告',
          pattern: '广告',
          replacement: '',
          isRegex: false,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );

      final result = await service.applyContentRules(
        content: '正文 广告 内容',
        bookTitle: '测试书',
        sourceId: 'source-a',
        bookId: 'book-1',
        detailUrl: 'https://example.com/book-1',
      );

      expect(result.content, '正文 广告 内容');
      expect(result.effectiveRules, isEmpty);
    });
  });
}
