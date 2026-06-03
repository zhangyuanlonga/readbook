import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/search/application/search_page_state.dart';
import 'package:shuxiang_reading_next/features/search/application/search_service.dart';

void main() {
  group('SearchPageStateNotifier', () {
    test('stores search session, filters, and access state in Riverpod', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(searchPageStateProvider.notifier);
      final sessionId = notifier.nextSearchSessionId();
      final accessRequestId = notifier.nextOnlineSearchAccessRequestId();
      notifier.update(
        (state) => state.copyWith(
          isSearching: true,
          searchContentMode: SearchContentMode.manga,
          isPreciseBookMatch: true,
          selectedServerSourceIds: <String>{'source-a'},
          hasOnlineSearchAccess: true,
          isCheckingOnlineSearchAccess: false,
          searchHistory: const <String>['斗破苍穹'],
        ),
      );

      final state = container.read(searchPageStateProvider);
      expect(sessionId, 1);
      expect(accessRequestId, 1);
      expect(state.searchSessionId, 1);
      expect(state.onlineSearchAccessRequestId, 1);
      expect(state.isSearching, isTrue);
      expect(state.searchContentMode, SearchContentMode.manga);
      expect(state.isPreciseBookMatch, isTrue);
      expect(state.selectedServerSourceIds, <String>{'source-a'});
      expect(state.hasOnlineSearchAccess, isTrue);
      expect(state.isCheckingOnlineSearchAccess, isFalse);
      expect(state.searchHistory, const <String>['斗破苍穹']);
    });
  });
}
