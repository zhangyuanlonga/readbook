import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/book_detail.dart';

void main() {
  group('BookDetail', () {
    test('supports toJson and fromJson roundtrip', () {
      const detail = BookDetail(
        id: 'book_1',
        sourceId: 'source-a',
        title: '凡人修仙传',
        detailUrl: 'https://example.com/book/1',
        author: '忘语',
        intro: '简介',
        coverUrl: 'https://example.com/cover.jpg',
        tocUrl: 'https://example.com/toc',
        latestChapterTitle: '第100章',
        totalChapterNum: 100,
        wordCount: '100万',
        category: '仙侠',
        tags: <String>['热门', '完结'],
        updateTime: '2026-06-03',
        executionContext: 'server',
      );

      final restored = BookDetail.fromJson(detail.toJson());

      expect(restored.id, detail.id);
      expect(restored.sourceId, detail.sourceId);
      expect(restored.title, detail.title);
      expect(restored.detailUrl, detail.detailUrl);
      expect(restored.totalChapterNum, 100);
      expect(restored.tags, <String>['热门', '完结']);
      expect(restored.executionContext, 'server');
    });

    test('normalizes optional fields and parses chapter count from string', () {
      final restored = BookDetail.fromJson(<String, dynamic>{
        'id': 'book_1',
        'sourceId': 'source-a',
        'title': '凡人修仙传',
        'detailUrl': 'https://example.com/book/1',
        'author': '  ',
        'latestChapterTitle': ' 第100章 ',
        'totalChapterNum': '120',
        'tags': <Object?>[' 热门 ', '', null],
      });

      expect(restored.author, isNull);
      expect(restored.latestChapterTitle, '第100章');
      expect(restored.totalChapterNum, 120);
      expect(restored.tags, <String>['热门']);
    });
  });
}
