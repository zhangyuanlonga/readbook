import 'package:flutter_appread/core/errors/error_codes.dart';
import 'package:flutter_appread/features/reader/application/reader_error_center_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderErrorCenterService', () {
    final service = ReaderErrorCenterService.instance;

    setUp(() {
      service.clear();
    });

    test('stores latest chapter failure and dedupes by chapter', () {
      service.addFailure(
        bookId: 'book_1',
        chapterId: 'chapter_1',
        chapterTitle: '第一章',
        message: '网络失败',
        errorCode: ErrorCode.network,
      );

      service.addFailure(
        bookId: 'book_1',
        chapterId: 'chapter_1',
        chapterTitle: '第一章',
        message: '403 防盗链',
        errorCode: ErrorCode.network,
      );

      expect(service.records, hasLength(1));
      expect(service.records.first.message, '403 防盗链');
    });

    test('drops oldest records when max exceeded', () {
      for (var i = 0; i < 45; i += 1) {
        service.addFailure(
          bookId: 'book_$i',
          chapterId: 'chapter_$i',
          chapterTitle: '章节$i',
          message: '失败$i',
        );
      }

      expect(service.records, hasLength(40));
      expect(service.records.first.chapterId, 'chapter_44');
      expect(service.records.last.chapterId, 'chapter_5');
    });
  });
}
