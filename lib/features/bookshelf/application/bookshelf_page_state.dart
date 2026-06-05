import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../book/application/book_display_state.dart';

part 'bookshelf_page_state.freezed.dart';

enum BookshelfFilter {
  all,
  todo,
  unread,
  reading,
  finished,
  local,
  novel,
  manga,
  custom,
}

enum BookshelfSortMode {
  defaultOrder,
  recentRead,
  readingProgress,
  createdAt,
  author,
  title,
}

enum BookshelfReadingStatus { unread, reading, finished }

enum BookshelfViewKind { base, tag, category }

enum BookshelfBatchAction { delete, updateCover }

@freezed
abstract class BookshelfViewSelection with _$BookshelfViewSelection {
  const BookshelfViewSelection._();

  const factory BookshelfViewSelection.base(BookshelfFilter filter) =
      _BookshelfViewBaseSelection;

  const factory BookshelfViewSelection.tag(String? tag) =
      _BookshelfViewTagSelection;

  const factory BookshelfViewSelection.category(String? category) =
      _BookshelfViewCategorySelection;

  BookshelfViewKind get kind => switch (this) {
    _BookshelfViewBaseSelection() => BookshelfViewKind.base,
    _BookshelfViewTagSelection() => BookshelfViewKind.tag,
    _BookshelfViewCategorySelection() => BookshelfViewKind.category,
    _ => BookshelfViewKind.base,
  };

  BookshelfFilter get filter => switch (this) {
    _BookshelfViewBaseSelection(:final filter) => filter,
    _BookshelfViewTagSelection() => BookshelfFilter.custom,
    _BookshelfViewCategorySelection() => BookshelfFilter.custom,
    _ => BookshelfFilter.all,
  };

  String? get tag => switch (this) {
    _BookshelfViewBaseSelection() => null,
    _BookshelfViewTagSelection(:final tag) => tag,
    _BookshelfViewCategorySelection() => null,
    _ => null,
  };

  String? get category => switch (this) {
    _BookshelfViewBaseSelection() => null,
    _BookshelfViewTagSelection() => null,
    _BookshelfViewCategorySelection(:final category) => category,
    _ => null,
  };

  bool get isTag => kind == BookshelfViewKind.tag;
  bool get isCategory => kind == BookshelfViewKind.category;
  bool get isUncategorized =>
      isCategory && (category == null || category!.isEmpty);
}

@freezed
abstract class BookshelfSelectionState with _$BookshelfSelectionState {
  const BookshelfSelectionState._();

  const factory BookshelfSelectionState({
    @Default(false) bool enabled,
    @Default(<String>{}) Set<String> selectedKeys,
    BookshelfBatchAction? activeAction,
  }) = _BookshelfSelectionState;

  bool get isBusy => activeAction != null;
  bool get isDeleting => activeAction == BookshelfBatchAction.delete;
  bool get isUpdatingCover => activeAction == BookshelfBatchAction.updateCover;
  int get selectedCount => selectedKeys.length;

  BookshelfSelectionState copyWithSelection({
    bool? enabled,
    Set<String>? selectedKeys,
    bool clearSelectedKeys = false,
    BookshelfBatchAction? activeAction,
    bool clearActiveAction = false,
  }) {
    return BookshelfSelectionState(
      enabled: enabled ?? this.enabled,
      selectedKeys:
          clearSelectedKeys
              ? const <String>{}
              : Set<String>.unmodifiable(selectedKeys ?? this.selectedKeys),
      activeAction:
          clearActiveAction ? null : (activeAction ?? this.activeAction),
    );
  }
}

@freezed
abstract class BookshelfBookCardState with _$BookshelfBookCardState {
  const BookshelfBookCardState._();

  const factory BookshelfBookCardState({
    ReadingProgress? progress,
    String? latestCachedChapterTitle,
    @Default(0) int cachedChapterCount,
    LocalBook? localBook,
    BookDisplayState? presentation,
  }) = _BookshelfBookCardState;

  BookshelfBookCardState copyWithCard({
    ReadingProgress? progress,
    bool clearProgress = false,
    String? latestCachedChapterTitle,
    bool clearLatestCachedChapterTitle = false,
    int? cachedChapterCount,
    LocalBook? localBook,
    bool clearLocalBook = false,
    BookDisplayState? presentation,
    bool clearPresentation = false,
  }) {
    return BookshelfBookCardState(
      progress: clearProgress ? null : (progress ?? this.progress),
      latestCachedChapterTitle:
          clearLatestCachedChapterTitle
              ? null
              : (latestCachedChapterTitle ?? this.latestCachedChapterTitle),
      cachedChapterCount: cachedChapterCount ?? this.cachedChapterCount,
      localBook: clearLocalBook ? null : (localBook ?? this.localBook),
      presentation:
          clearPresentation ? null : (presentation ?? this.presentation),
    );
  }
}

@freezed
abstract class BookshelfPageState with _$BookshelfPageState {
  const factory BookshelfPageState({
    @Default(BookshelfPageState.defaultBaseFilters)
    List<BookshelfFilter> baseFilterOrder,
    @Default(BookshelfViewSelection.base(BookshelfFilter.all))
    BookshelfViewSelection activeView,
    @Default(BookshelfSortMode.defaultOrder) BookshelfSortMode sortMode,
    @Default(BookshelfSelectionState()) BookshelfSelectionState selection,
    @Default(<String, BookshelfBookCardState>{})
    Map<String, BookshelfBookCardState> cardStatesByKey,
  }) = _BookshelfPageState;

  static const List<BookshelfFilter> defaultBaseFilters = <BookshelfFilter>[
    BookshelfFilter.all,
    BookshelfFilter.local,
    BookshelfFilter.novel,
    BookshelfFilter.manga,
  ];
}

final bookshelfPageStateProvider =
    NotifierProvider<BookshelfPageStateNotifier, BookshelfPageState>(
      BookshelfPageStateNotifier.new,
    );

class BookshelfPageStateNotifier extends Notifier<BookshelfPageState> {
  @override
  BookshelfPageState build() {
    return const BookshelfPageState();
  }

  void setBaseFilterOrder(List<BookshelfFilter> filters) {
    state = state.copyWith(baseFilterOrder: filters);
  }

  void setActiveView(BookshelfViewSelection view) {
    state = state.copyWith(activeView: view);
  }

  void setSortMode(BookshelfSortMode mode) {
    state = state.copyWith(sortMode: mode);
  }

  void setSelection(BookshelfSelectionState selection) {
    state = state.copyWith(selection: selection);
  }

  void clearSelection() {
    setSelection(const BookshelfSelectionState());
  }

  void syncCardStates({
    required Iterable<String> validKeys,
    required BookshelfBookCardState Function(String key) resolveState,
  }) {
    final keySet = validKeys.where((key) => key.isNotEmpty).toSet();
    final next = <String, BookshelfBookCardState>{
      for (final key in keySet) key: resolveState(key),
    };
    if (_mapEquals(state.cardStatesByKey, next)) {
      return;
    }
    state = state.copyWith(cardStatesByKey: next);
  }

  void setCardState(String key, BookshelfBookCardState cardState) {
    if (key.isEmpty || state.cardStatesByKey[key] == cardState) {
      return;
    }
    state = state.copyWith(
      cardStatesByKey: <String, BookshelfBookCardState>{
        ...state.cardStatesByKey,
        key: cardState,
      },
    );
  }

  BookshelfBookCardState cardStateFor(
    String key,
    BookshelfBookCardState fallback,
  ) {
    return state.cardStatesByKey[key] ?? fallback;
  }

  bool _mapEquals(
    Map<String, BookshelfBookCardState> first,
    Map<String, BookshelfBookCardState> second,
  ) {
    if (first.length != second.length) {
      return false;
    }
    for (final entry in first.entries) {
      if (second[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
