import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/source_login_state.dart';

void main() {
  group('SourceLoginState', () {
    test('supports toJson and fromJson with normalized optional values', () {
      final state = SourceLoginState(
        sourceId: 'source_a',
        updatedAt: DateTime.parse('2026-06-03T10:00:00.000Z'),
        loginHeaderJson: ' {"token":"abc"} ',
        loginInfoJson: '  ',
        sourceVariableJson: '{"cookie":"1"}',
      );

      final restored = SourceLoginState.fromJson(state.toJson());

      expect(restored.sourceId, 'source_a');
      expect(restored.updatedAt, state.updatedAt);
      expect(restored.loginHeaderJson, '{"token":"abc"}');
      expect(restored.loginInfoJson, isNull);
      expect(restored.sourceVariableJson, '{"cookie":"1"}');
    });

    test('copyWith can clear nullable payload fields', () {
      final state = SourceLoginState(
        sourceId: 'source_a',
        updatedAt: DateTime.parse('2026-06-03T10:00:00.000Z'),
        loginHeaderJson: '{"token":"abc"}',
        loginInfoJson: '{"name":"tester"}',
        sourceVariableJson: '{"cookie":"1"}',
      );

      final cleared = state.copyWith(
        loginHeaderJson: null,
        loginInfoJson: null,
        sourceVariableJson: null,
      );

      expect(cleared.loginHeaderJson, isNull);
      expect(cleared.loginInfoJson, isNull);
      expect(cleared.sourceVariableJson, isNull);
      expect(cleared.isEmpty, isTrue);
    });

    test('throws when required fields are missing', () {
      expect(
        () => SourceLoginState.fromJson(<String, dynamic>{
          'sourceId': 'source_a',
          'updatedAt': '',
        }),
        throwsFormatException,
      );
    });
  });
}
