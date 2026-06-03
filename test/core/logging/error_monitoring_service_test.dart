import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/core/logging/app_logger.dart';
import 'package:shuxiang_reading_next/core/logging/error_monitoring_service.dart';
import 'package:shuxiang_reading_next/core/logging/source_log_error_monitoring_sink.dart';
import 'package:shuxiang_reading_next/core/logging/source_log_store.dart';

void main() {
  group('AppErrorMonitoringService', () {
    late _RecordingMonitoringSink sink;
    late AppErrorMonitoringService service;

    setUp(() {
      sink = _RecordingMonitoringSink();
      service = AppErrorMonitoringService.instance;
      service.configure(sink: sink, captureEnabled: true);
      SourceLogStore.instance.clear();
    });

    tearDown(() {
      service.resetForTesting();
      SourceLogStore.instance.clear();
    });

    test('sanitizes sensitive context before capture', () async {
      await service.captureLoggerError(
        'Gateway failed with Bearer secret-token',
        exception: const AppException(
          code: ErrorCode.network,
          stage: ErrorStage.search,
          sourceId: 'src_1',
          requestUrl: 'https://example.com/search?q=secret&token=abc#frag',
          briefMessage: '网络失败',
        ),
        context: const <String, Object?>{
          'authorization': 'Bearer secret-token',
          'filePath': '/Users/me/private/book.txt',
          'nested': <String, Object?>{'cookie': 'sid=secret'},
        },
      );

      final event = sink.events.single;
      expect(event.message, 'Gateway failed with Bearer [redacted]');
      expect(event.context['authorization'], '[redacted]');
      expect(event.context['filePath'], '[redacted-path]');
      expect(event.context['requestUrl'], 'https://example.com/search');
      expect(event.context['nested'], <String, Object?>{
        'cookie': '[redacted]',
      });
      expect(event.throwable, isA<MonitoredException>());
    });

    test('AppLogger.error forwards sanitized events to monitoring', () async {
      AppLogger.instance.error(
        'Reader failed',
        exception: const AppException(
          code: ErrorCode.decode,
          stage: ErrorStage.content,
          requestUrl: 'https://example.com/chapter?id=private',
          briefMessage: '解析失败',
        ),
        context: const <String, Object?>{
          'refreshToken': 'secret',
          'chapterId': 'chapter_1',
        },
      );

      await Future<void>.delayed(Duration.zero);

      final event = sink.events.single;
      expect(event.origin, 'app_logger');
      expect(event.context['refreshToken'], '[redacted]');
      expect(event.context['chapterId'], 'chapter_1');
      expect(event.context['requestUrl'], 'https://example.com/chapter');

      final localEntry = SourceLogStore.instance.entries.single;
      expect(localEntry.context['refreshToken'], '[redacted]');
      expect(localEntry.context['requestUrl'], 'https://example.com/chapter');
      expect(localEntry.toMultilineText(), isNot(contains('id=private')));
    });

    test('source log sink records unhandled errors locally', () async {
      final localSink = SourceLogAppErrorMonitoringSink(
        store: SourceLogStore.instance,
      );
      service.configure(sink: localSink, captureEnabled: true);

      await service.captureUnhandledError(
        StateError('Bearer secret-token'),
        StackTrace.current,
        origin: 'zone',
      );

      final entry = SourceLogStore.instance.entries.single;
      expect(entry.level, AppLogLevel.error);
      expect(entry.message, 'Unhandled StateError');
      expect(entry.context['origin'], 'zone');
      expect(entry.context['severity'], 'fatal');
      expect(entry.toMultilineText(), isNot(contains('secret-token')));
    });
  });
}

class _RecordingMonitoringSink implements AppErrorMonitoringSink {
  final List<AppErrorMonitoringEvent> events = <AppErrorMonitoringEvent>[];

  @override
  void capture(AppErrorMonitoringEvent event) {
    events.add(event);
  }
}
