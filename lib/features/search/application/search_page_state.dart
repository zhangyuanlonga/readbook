import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../book/application/book_display_state.dart';
import 'search_models.dart';

part 'search_page_state.freezed.dart';

@freezed
abstract class DeferredSearchProgressUiUpdate
    with _$DeferredSearchProgressUiUpdate {
  const factory DeferredSearchProgressUiUpdate({
    required SearchExecutionReport report,
    required SearchCancellationToken token,
    required int sessionId,
    required bool forceRenderState,
    required bool isFinalReport,
  }) = _DeferredSearchProgressUiUpdate;
}

@freezed
abstract class SearchPageState with _$SearchPageState {
  const factory SearchPageState({
    @Default(false) bool isSearching,
    @Default(false) bool isLoadingServerSourceCount,
    @Default(0) int searchSessionId,
    @Default(SearchContentMode.novel) SearchContentMode searchContentMode,
    @Default(false) bool isPreciseBookMatch,
    @Default(true) bool aggregateByTitleAuthorEnabled,
    @Default(0) int availableServerSourceCount,
    @Default(<String>{}) Set<String> selectedServerSourceIds,
    @Default(<String>{}) Set<String> selectedServerGroupNames,
    @Default(false) bool isAppendingResults,
    @Default(<String, BookDisplayState>{})
    Map<String, BookDisplayState> bookPresentationByTargetKey,
    SearchExecutionReport? pendingProgressReport,
    DateTime? lastProgressUiUpdateAt,
    @Default(false) bool isListScrollActive,
    DeferredSearchProgressUiUpdate? deferredProgressUiUpdate,
    int? pendingSearchCompletionSessionId,
    SearchCancellationToken? pendingSearchCompletionToken,
    @Default(false) bool isCheckingOnlineSearchAccess,
    @Default(true) bool hasOnlineSearchAccess,
    String? onlineSearchAccessMessage,
    @Default(0) int onlineSearchAccessRequestId,
    @Default(<String>[]) List<String> searchHistory,
  }) = _SearchPageState;
}

final searchPageStateProvider =
    NotifierProvider.autoDispose<SearchPageStateNotifier, SearchPageState>(
      SearchPageStateNotifier.new,
    );

class SearchPageStateNotifier extends AutoDisposeNotifier<SearchPageState> {
  @override
  SearchPageState build() => const SearchPageState();

  int nextSearchSessionId() {
    final nextId = state.searchSessionId + 1;
    state = state.copyWith(searchSessionId: nextId);
    return nextId;
  }

  int nextOnlineSearchAccessRequestId() {
    final nextId = state.onlineSearchAccessRequestId + 1;
    state = state.copyWith(onlineSearchAccessRequestId: nextId);
    return nextId;
  }

  void update(SearchPageState Function(SearchPageState) fn) {
    final next = fn(state);
    if (next != state) {
      state = next;
    }
  }
}
