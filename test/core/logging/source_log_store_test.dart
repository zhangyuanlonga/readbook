import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/core/errors/error_codes.dart';
import 'package:flutter_appread/core/errors/error_stage.dart';
import 'package:flutter_appread/core/logging/source_log_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceLogStore', () {
    final store = SourceLogStore.instance;

    setUp(() {
      store.clear();
    });

    test('stores newest logs first', () {
      store.add(
        AppLogEntry(
          timestamp: DateTime.parse('2026-02-12T10:00:00.000Z'),
          level: AppLogLevel.warn,
          message: 'first',
        ),
      );
      store.add(
        AppLogEntry(
          timestamp: DateTime.parse('2026-02-12T10:01:00.000Z'),
          level: AppLogLevel.error,
          message: 'second',
        ),
      );

      final entries = store.entries;
      expect(entries, hasLength(2));
      expect(entries.first.message, 'second');
      expect(entries.last.message, 'first');
    });

    test(
      'exportText includes exception details and filters info by default',
      () {
        store.add(
          AppLogEntry(
            timestamp: DateTime.parse('2026-02-12T10:00:00.000Z'),
            level: AppLogLevel.info,
            message: 'info',
          ),
        );
        store.add(
          AppLogEntry(
            timestamp: DateTime.parse('2026-02-12T10:01:00.000Z'),
            level: AppLogLevel.error,
            message: 'boom',
            context: const {'sourceId': 'src_1'},
            exception: const AppException(
              code: ErrorCode.network,
              stage: ErrorStage.search,
              sourceId: 'src_1',
              requestUrl: 'https://example.com/search',
              briefMessage: '网络失败',
            ),
          ),
        );

        final withoutInfo = store.exportText();
        expect(withoutInfo, isNot(contains('info')));
        expect(withoutInfo, contains('sourceId: src_1'));
        expect(withoutInfo, contains('code: network'));

        final withInfo = store.exportText(includeInfo: true);
        expect(withInfo, contains('info'));
      },
    );
  });
}
