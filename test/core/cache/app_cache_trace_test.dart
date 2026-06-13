import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/cache/cache_key.dart';
import 'package:shuxiang_reading_next/core/cache/cache_result.dart';
import 'package:shuxiang_reading_next/core/cache/cache_scope.dart';
import 'package:shuxiang_reading_next/core/cache/cache_trace.dart';

void main() {
  group('AppCacheTracer', () {
    test('emits structured read context', () {
      final logs = <Map<String, Object?>>[];
      final tracer = AppCacheTracer(
        log: (_, {context = const <String, Object?>{}}) {
          logs.add(context);
        },
      );
      final key = AppCacheKey(
        scope: AppCacheScope.chapterContent,
        owner: 'user_1',
        parts: <String, Object?>{'chapterUrl': 'chapter://1'},
      );

      tracer.traceRead(
        AppCacheReadResult.miss(key: key, backend: 'drift.chapter_caches'),
      );

      expect(logs, hasLength(1));
      expect(logs.single['scope'], AppCacheScope.chapterContent.name);
      expect(logs.single['owner'], 'user_1');
      expect(logs.single['status'], AppCacheReadStatus.miss.name);
      expect(logs.single['backend'], 'drift.chapter_caches');
      expect(logs.single['key'], key.toStorageKey());
    });

    test('can be disabled', () {
      final logs = <Map<String, Object?>>[];
      final tracer = AppCacheTracer(
        enabled: false,
        log: (_, {context = const <String, Object?>{}}) {
          logs.add(context);
        },
      );
      final key = AppCacheKey(scope: AppCacheScope.apiResponse);

      tracer.traceRead(AppCacheReadResult.miss(key: key, backend: 'memory'));

      expect(logs, isEmpty);
    });
  });
}
