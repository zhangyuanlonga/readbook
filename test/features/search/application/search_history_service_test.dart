import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/features/search/application/search_history_service.dart';

void main() {
  const localHistoryKey =
      '${SearchHistoryService.historyPreferenceKey}.local_user';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('adds, deduplicates, trims, and limits history to 15', () async {
    final service = SearchHistoryService();

    for (var index = 0; index < 18; index++) {
      await service.add('  keyword-$index  ');
    }
    await service.add('keyword-12');

    final history = await service.getAll();

    expect(history, hasLength(15));
    expect(history.first, 'keyword-12');
    expect(history.where((item) => item == 'keyword-12'), hasLength(1));
    expect(history, isNot(contains('keyword-0')));
  });

  test('reads legacy json payload from search.history', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SearchHistoryService.historyPreferenceKey: jsonEncode(<String>[
        '  玄幻  ',
        '',
        '科幻',
        '玄幻',
      ]),
    });

    final service = SearchHistoryService();

    expect(await service.getAll(), <String>['玄幻', '科幻']);
  });

  test('writes StringList instead of JSON string', () async {
    final service = SearchHistoryService();

    await service.add('历史');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.get(localHistoryKey), isA<List<String>>());
    expect(prefs.getStringList(localHistoryKey), ['历史']);
  });

  test('remove and clear keep typed key behavior', () async {
    final service = SearchHistoryService();

    await service.add('A');
    await service.add('B');
    await service.remove(' A ');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(localHistoryKey), ['B']);

    await service.clear();

    expect(prefs.containsKey(localHistoryKey), false);
    expect(await service.getAll(), isEmpty);
  });

  test('isolates history by resolved user id', () async {
    final userA = SearchHistoryService(userIdResolver: () async => 'user-a');
    final userB = SearchHistoryService(userIdResolver: () async => 'user-b');

    await userA.add('A');
    await userB.add('B');

    expect(await userA.getAll(), <String>['A']);
    expect(await userB.getAll(), <String>['B']);
  });
}
