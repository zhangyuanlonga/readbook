import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'advanced_theme_service.dart';

part 'advanced_theme_list_page_state.freezed.dart';

enum AdvancedThemeSortMode { updatedDesc, nameAsc, categoryAsc }

@freezed
abstract class AdvancedThemeListPageState with _$AdvancedThemeListPageState {
  const factory AdvancedThemeListPageState({
    @Default(<AdvancedThemeSummary>[])
    List<AdvancedThemeSummary> themeSummaries,
    @Default('') String searchQuery,
    String? selectedCategory,
    @Default(<String>{}) Set<String> selectedThemeIds,
    @Default(true) bool isLoading,
    @Default(false) bool isSaving,
    @Default(false) bool isConsumingExternalImportPayloads,
    @Default(true) bool isAccessLoading,
    @Default(false) bool canUseAdvancedThemes,
    @Default(false) bool isSelectionMode,
    @Default(false) bool floatingEditEnabled,
    @Default(AdvancedThemeSortMode.updatedDesc)
    AdvancedThemeSortMode themeSortMode,
    String? savingStatusText,
    @Default(0) int summaryLoadToken,
  }) = _AdvancedThemeListPageState;
}

final advancedThemeListPageStateProvider = NotifierProvider.autoDispose<
  AdvancedThemeListPageStateNotifier,
  AdvancedThemeListPageState
>(AdvancedThemeListPageStateNotifier.new);

class AdvancedThemeListPageStateNotifier
    extends AutoDisposeNotifier<AdvancedThemeListPageState> {
  @override
  AdvancedThemeListPageState build() => const AdvancedThemeListPageState();

  int nextSummaryLoadToken() {
    final nextToken = state.summaryLoadToken + 1;
    state = state.copyWith(summaryLoadToken: nextToken);
    return nextToken;
  }

  void update(
    AdvancedThemeListPageState Function(AdvancedThemeListPageState) fn,
  ) {
    final next = fn(state);
    if (next != state) {
      state = next;
    }
  }
}
