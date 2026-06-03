import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/book_metadata_override.dart';

void main() {
  group('BookMetadataOverride', () {
    test('supports toJson and fromJson roundtrip', () {
      final override = BookMetadataOverride(
        targetKey: 'remote::source_a::/detail/1',
        sourceId: 'source_a',
        detailUrl: '/detail/1',
        title: '覆盖标题',
        author: '覆盖作者',
        intro: '覆盖简介',
        coverPath: '/tmp/cover.png',
        createdAt: DateTime.parse('2026-06-03T12:00:00.000Z'),
        updatedAt: DateTime.parse('2026-06-03T12:00:00.000Z'),
      );

      final restored = BookMetadataOverride.fromJson(override.toJson());

      expect(restored.targetKey, override.targetKey);
      expect(restored.sourceId, override.sourceId);
      expect(restored.detailUrl, override.detailUrl);
      expect(restored.title, override.title);
      expect(restored.coverPath, override.coverPath);
    });

    test('copyWith can clear optional metadata fields', () {
      final override = BookMetadataOverride(
        targetKey: 'remote::source_a::/detail/1',
        sourceId: 'source_a',
        detailUrl: '/detail/1',
        title: '覆盖标题',
        author: '覆盖作者',
        intro: '覆盖简介',
        coverPath: '/tmp/cover.png',
        createdAt: DateTime.parse('2026-06-03T12:00:00.000Z'),
        updatedAt: DateTime.parse('2026-06-03T12:00:00.000Z'),
      );

      final cleared = override.copyWith(
        clearTitle: true,
        clearAuthor: true,
        clearIntro: true,
        clearCoverPath: true,
      );

      expect(cleared.title, isNull);
      expect(cleared.author, isNull);
      expect(cleared.intro, isNull);
      expect(cleared.coverPath, isNull);
    });
  });
}
