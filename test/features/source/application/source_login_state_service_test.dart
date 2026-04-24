import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shuxiang_reading_next/domain/entities/book_custom_state.dart';
import 'package:shuxiang_reading_next/domain/entities/source_login_state.dart';
import 'package:shuxiang_reading_next/features/source/application/source_login_state_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SourceLoginStateService', () {
    late SharedPreferences prefs;
    late SourceLoginStateService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      service = SourceLoginStateService(preferences: prefs);
    });

    test('saves and loads source login state', () async {
      final state = SourceLoginState(
        sourceId: 'source_jjwxc',
        loginHeaderJson: '{"token":"abc"}',
        loginInfoJson: '{"账号":"foo"}',
        sourceVariableJson: '{"tab":"小说"}',
        updatedAt: DateTime.utc(2026, 4, 24, 8),
      );

      await service.saveSourceLoginState(state);

      final restored = await service.loadSourceLoginState('source_jjwxc');
      expect(restored, isNotNull);
      expect(restored!.sourceId, 'source_jjwxc');
      expect(restored.loginHeaderJson, '{"token":"abc"}');
      expect(restored.loginInfoJson, '{"账号":"foo"}');
      expect(restored.sourceVariableJson, '{"tab":"小说"}');
    });

    test('removes empty source login state instead of persisting it', () async {
      await service.saveSourceLoginState(
        SourceLoginState(
          sourceId: 'source_empty',
          updatedAt: DateTime.utc(2026, 4, 24, 8),
        ),
      );

      expect(await service.loadSourceLoginState('source_empty'), isNull);
      expect(await service.loadSourceLoginStates(), isEmpty);
    });

    test('saves and cleans book custom states by source and book', () async {
      await service.saveBookCustomState(
        BookCustomState(
          bookId: 'book_1',
          sourceId: 'source_a',
          detailUrl: 'https://example.com/book/1',
          customVariableJson: '{"custom":"A"}',
          updatedAt: DateTime.utc(2026, 4, 24, 8),
        ),
      );
      await service.saveBookCustomState(
        BookCustomState(
          bookId: 'book_2',
          sourceId: 'source_a',
          detailUrl: 'https://example.com/book/2',
          customVariableJson: '{"custom":"B"}',
          updatedAt: DateTime.utc(2026, 4, 24, 9),
        ),
      );
      await service.saveBookCustomState(
        BookCustomState(
          bookId: 'book_3',
          sourceId: 'source_b',
          detailUrl: 'https://example.com/book/3',
          customVariableJson: '{"custom":"C"}',
          updatedAt: DateTime.utc(2026, 4, 24, 10),
        ),
      );

      final before = await service.loadBookCustomStates();
      expect(before, hasLength(3));

      await service.removeBookCustomStatesForSource('source_a');
      final afterSourceCleanup = await service.loadBookCustomStates();
      expect(afterSourceCleanup, hasLength(1));
      expect(afterSourceCleanup.values.single.sourceId, 'source_b');

      await service.removeBookCustomStatesForBook('book_3');
      expect(await service.loadBookCustomStates(), isEmpty);
    });

    test('clears all states', () async {
      await service.saveSourceLoginState(
        SourceLoginState(
          sourceId: 'source_jjwxc',
          loginHeaderJson: '{"token":"abc"}',
          updatedAt: DateTime.utc(2026, 4, 24, 8),
        ),
      );
      await service.saveBookCustomState(
        BookCustomState(
          bookId: 'book_1',
          sourceId: 'source_jjwxc',
          detailUrl: 'https://example.com/book/1',
          customVariableJson: '{"custom":"A"}',
          updatedAt: DateTime.utc(2026, 4, 24, 8),
        ),
      );

      await service.clearAllStates();

      expect(await service.loadSourceLoginStates(), isEmpty);
      expect(await service.loadBookCustomStates(), isEmpty);
    });
  });
}
