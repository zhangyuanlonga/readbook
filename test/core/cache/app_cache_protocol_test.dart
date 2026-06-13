import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/cache/cache_entry.dart';
import 'package:shuxiang_reading_next/core/cache/cache_key.dart';
import 'package:shuxiang_reading_next/core/cache/cache_policy.dart';
import 'package:shuxiang_reading_next/core/cache/cache_result.dart';
import 'package:shuxiang_reading_next/core/cache/cache_scope.dart';

void main() {
  group('AppCacheKey', () {
    test('normalizes owner and sorts parts for stable storage keys', () {
      final first = AppCacheKey(
        scope: AppCacheScope.chapterContent,
        owner: ' user  1 ',
        parts: <String, Object?>{
          'chapterUrl': ' https://example.com/a ',
          'sourceId': ' source  1 ',
        },
      );
      final second = AppCacheKey(
        scope: AppCacheScope.chapterContent,
        owner: 'user 1',
        parts: <String, Object?>{
          'sourceId': 'source 1',
          'chapterUrl': 'https://example.com/a',
        },
      );

      expect(first.normalized, second.normalized);
      expect(first.toStorageKey(), second.toStorageKey());
      expect(first.toStorageKey(), startsWith('chapterContent.user_1.'));
      expect(first.toStorageKey(), isNot(contains('https://example.com/a')));
    });

    test('drops empty parts from normalized keys', () {
      final key = AppCacheKey(
        scope: AppCacheScope.paginationLayout,
        parts: <String, Object?>{
          'sourceId': 'source_a',
          'chapterUrl': '',
          'signature': null,
        },
      );

      expect(key.parts, <String, String>{'sourceId': 'source_a'});
    });
  });

  group('AppCachePolicy', () {
    test('computes TTL expiry from creation time', () {
      const policy = AppCachePolicy(ttl: Duration(minutes: 5));
      final createdAt = DateTime(2026, 6, 13, 10);

      expect(policy.expiresAtFor(createdAt), DateTime(2026, 6, 13, 10, 5));
      expect(
        policy.isExpired(
          DateTime(2026, 6, 13, 10, 4, 59),
          createdAt: createdAt,
        ),
        isFalse,
      );
      expect(
        policy.isExpired(DateTime(2026, 6, 13, 10, 5), createdAt: createdAt),
        isTrue,
      );
    });

    test('keeps entries without TTL alive', () {
      const policy = AppCachePolicy();
      final createdAt = DateTime(2026, 6, 13);

      expect(policy.expiresAtFor(createdAt), isNull);
      expect(
        policy.isExpired(DateTime(2030, 1, 1), createdAt: createdAt),
        isFalse,
      );
    });

    test(
      'does not classify reader preferences as deletable rebuildable cache',
      () {
        const policy = AppCachePolicies.readerPreference;

        expect(policy.userScoped, isTrue);
        expect(policy.rebuildable, isFalse);
        expect(policy.deletable, isFalse);
      },
    );
  });

  group('AppCacheReadResult', () {
    test('expresses version mismatch with invalid reason', () {
      final key = AppCacheKey(
        scope: AppCacheScope.paginationLayout,
        parts: <String, Object?>{'signature': 'old'},
      );
      final now = DateTime(2026, 6, 13);
      final entry = AppCacheEntry(
        key: key,
        payload: 'payload',
        createdAt: now,
        updatedAt: now,
        lastAccessedAt: now,
        version: 1,
      );

      final result = AppCacheReadResult.versionMismatch(
        key: key,
        backend: 'memory',
        entry: entry,
      );

      expect(result.status, AppCacheReadStatus.versionMismatch);
      expect(result.invalidReason, AppCacheInvalidReason.versionChanged);
      expect(result.hasValue, isFalse);
    });
  });
}
