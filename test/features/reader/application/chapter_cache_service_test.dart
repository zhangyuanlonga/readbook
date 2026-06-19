import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/features/reader/application/chapter_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('cacheRange closes stream when chapter list is empty', () async {
    final service = ChapterCacheService();

    final events =
        await service
            .cacheRange(
              bookId: 'book-1',
              sourceId: 'server-gateway:source-1',
              chapters: const [],
              startIndex: 0,
              endIndex: 0,
            )
            .toList();

    expect(events, hasLength(1));
    expect(events.single.isCompleted, isTrue);
    expect(events.single.total, 0);
  });

  test('cacheRange closes stream when required ids are missing', () async {
    final service = ChapterCacheService();

    final events =
        await service
            .cacheRange(
              bookId: '',
              sourceId: '',
              chapters: const [],
              startIndex: 0,
              endIndex: 0,
            )
            .toList();

    expect(events, hasLength(1));
    expect(events.single.isCompleted, isTrue);
    expect(events.single.failed, 0);
  });
}
