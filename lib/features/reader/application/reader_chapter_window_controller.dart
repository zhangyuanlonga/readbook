import '../../../domain/entities/chapter.dart';
import 'reader_chapter_navigation.dart';

enum ReaderChapterSlot { previous, current, next }

enum ReaderChapterWindowStatus { empty, loading, ready, failed, cancelled }

class ReaderChapterSlotState {
  const ReaderChapterSlotState({
    required this.slot,
    required this.status,
    this.chapterIndex,
  });

  final ReaderChapterSlot slot;
  final ReaderChapterWindowStatus status;
  final int? chapterIndex;

  bool get hasChapter => chapterIndex != null;
}

class ReaderChapterWindowPlan {
  const ReaderChapterWindowPlan({
    required this.currentChapterIndex,
    this.status = ReaderChapterWindowStatus.ready,
    this.previousChapterIndex,
    this.nextChapterIndex,
  });

  final int currentChapterIndex;
  final ReaderChapterWindowStatus status;
  final int? previousChapterIndex;
  final int? nextChapterIndex;

  List<int> get indices {
    return <int>[
      if (previousChapterIndex != null) previousChapterIndex!,
      currentChapterIndex,
      if (nextChapterIndex != null) nextChapterIndex!,
    ];
  }

  bool contains(int chapterIndex) {
    return chapterIndex == currentChapterIndex ||
        chapterIndex == previousChapterIndex ||
        chapterIndex == nextChapterIndex;
  }

  List<ReaderChapterSlotState> get slots {
    return <ReaderChapterSlotState>[
      ReaderChapterSlotState(
        slot: ReaderChapterSlot.previous,
        status:
            previousChapterIndex == null
                ? ReaderChapterWindowStatus.empty
                : status,
        chapterIndex: previousChapterIndex,
      ),
      ReaderChapterSlotState(
        slot: ReaderChapterSlot.current,
        status: status,
        chapterIndex: currentChapterIndex,
      ),
      ReaderChapterSlotState(
        slot: ReaderChapterSlot.next,
        status:
            nextChapterIndex == null ? ReaderChapterWindowStatus.empty : status,
        chapterIndex: nextChapterIndex,
      ),
    ];
  }

  int? chapterIndexFor(ReaderChapterSlot slot) {
    return switch (slot) {
      ReaderChapterSlot.previous => previousChapterIndex,
      ReaderChapterSlot.current => currentChapterIndex,
      ReaderChapterSlot.next => nextChapterIndex,
    };
  }
}

class ReaderChapterWindowMovePlan {
  const ReaderChapterWindowMovePlan({
    required this.from,
    required this.to,
    required this.reusableChapterIndexes,
    required this.enteringChapterIndexes,
    required this.leavingChapterIndexes,
  });

  final ReaderChapterWindowPlan? from;
  final ReaderChapterWindowPlan? to;
  final List<int> reusableChapterIndexes;
  final List<int> enteringChapterIndexes;
  final List<int> leavingChapterIndexes;

  bool get hasReusableCurrent {
    final current = to?.currentChapterIndex;
    return current != null && reusableChapterIndexes.contains(current);
  }
}

class ReaderChapterWindowController {
  const ReaderChapterWindowController({
    ReaderChapterNavigation chapterNavigation = const ReaderChapterNavigation(),
  }) : _chapterNavigation = chapterNavigation;

  final ReaderChapterNavigation _chapterNavigation;

  ReaderChapterWindowPlan? buildWindowPlan({
    required List<Chapter> chapters,
    required int? currentChapterIndex,
    ReaderChapterWindowStatus status = ReaderChapterWindowStatus.ready,
  }) {
    final current = _resolveReadableCurrentIndex(
      chapters: chapters,
      currentChapterIndex: currentChapterIndex,
    );
    if (current == null) {
      return null;
    }
    return ReaderChapterWindowPlan(
      currentChapterIndex: current,
      status: status,
      previousChapterIndex: _chapterNavigation.findReadableChapterIndex(
        chapters,
        current - 1,
        forward: false,
      ),
      nextChapterIndex: _chapterNavigation.findReadableChapterIndex(
        chapters,
        current + 1,
        forward: true,
      ),
    );
  }

  ReaderChapterWindowMovePlan buildMovePlan({
    required List<Chapter> chapters,
    required int? previousCurrentChapterIndex,
    required int? nextCurrentChapterIndex,
  }) {
    final from = buildWindowPlan(
      chapters: chapters,
      currentChapterIndex: previousCurrentChapterIndex,
    );
    final to = buildWindowPlan(
      chapters: chapters,
      currentChapterIndex: nextCurrentChapterIndex,
    );
    final fromIndexes = from?.indices.toSet() ?? const <int>{};
    final toIndexes = to?.indices.toSet() ?? const <int>{};
    final reusable = toIndexes.intersection(fromIndexes).toList()..sort();
    final entering = toIndexes.difference(fromIndexes).toList()..sort();
    final leaving = fromIndexes.difference(toIndexes).toList()..sort();
    return ReaderChapterWindowMovePlan(
      from: from,
      to: to,
      reusableChapterIndexes: List<int>.unmodifiable(reusable),
      enteringChapterIndexes: List<int>.unmodifiable(entering),
      leavingChapterIndexes: List<int>.unmodifiable(leaving),
    );
  }

  List<T> retainWindow<T>({
    required Iterable<T> items,
    required int Function(T item) chapterIndexOf,
    required List<Chapter> chapters,
    required int? currentChapterIndex,
  }) {
    final plan = buildWindowPlan(
      chapters: chapters,
      currentChapterIndex: currentChapterIndex,
    );
    if (plan == null) {
      return List<T>.unmodifiable(<T>[]);
    }
    final retained = items
        .where((item) => plan.contains(chapterIndexOf(item)))
        .toList(growable: false)
      ..sort((a, b) => chapterIndexOf(a).compareTo(chapterIndexOf(b)));
    return List<T>.unmodifiable(retained);
  }

  List<T> insertAndRetainWindow<T>({
    required Iterable<T> items,
    required T item,
    required int Function(T item) chapterIndexOf,
    required List<Chapter> chapters,
    required int? currentChapterIndex,
  }) {
    final byIndex = <int, T>{};
    for (final existing in items) {
      byIndex[chapterIndexOf(existing)] = existing;
    }
    byIndex[chapterIndexOf(item)] = item;
    return retainWindow(
      items: byIndex.values,
      chapterIndexOf: chapterIndexOf,
      chapters: chapters,
      currentChapterIndex: currentChapterIndex,
    );
  }

  bool shouldAcceptLoadedChapter({
    required int loadedChapterIndex,
    required List<Chapter> chapters,
    required int? currentChapterIndex,
  }) {
    final plan = buildWindowPlan(
      chapters: chapters,
      currentChapterIndex: currentChapterIndex,
    );
    return plan?.contains(loadedChapterIndex) ?? false;
  }

  List<int> resolveStaleLoadedChapterIndexes({
    required Iterable<int> loadedChapterIndices,
    required List<Chapter> chapters,
    required int? currentChapterIndex,
  }) {
    final plan = buildWindowPlan(
      chapters: chapters,
      currentChapterIndex: currentChapterIndex,
    );
    if (plan == null) {
      return loadedChapterIndices.toSet().toList()..sort();
    }
    final stale =
        loadedChapterIndices
            .where((index) => !plan.contains(index))
            .toSet()
            .toList()
          ..sort();
    return List<int>.unmodifiable(stale);
  }

  int? resolveAdjacentLoadIndex({
    required List<Chapter> chapters,
    required Iterable<int> loadedChapterIndices,
    required int? currentChapterIndex,
    required bool forward,
  }) {
    final retained = retainWindow<int>(
      items: loadedChapterIndices,
      chapterIndexOf: (index) => index,
      chapters: chapters,
      currentChapterIndex: currentChapterIndex,
    );
    if (retained.isEmpty) {
      return null;
    }
    final plan = buildWindowPlan(
      chapters: chapters,
      currentChapterIndex: currentChapterIndex,
    );
    if (plan == null) {
      return null;
    }
    final target = forward ? plan.nextChapterIndex : plan.previousChapterIndex;
    if (target == null || retained.contains(target)) {
      return null;
    }
    return target;
  }

  int? _resolveReadableCurrentIndex({
    required List<Chapter> chapters,
    required int? currentChapterIndex,
  }) {
    if (currentChapterIndex == null ||
        currentChapterIndex < 0 ||
        currentChapterIndex >= chapters.length) {
      return null;
    }
    final currentChapter = chapters[currentChapterIndex];
    if (_chapterNavigation.isReadableChapter(currentChapter)) {
      return currentChapterIndex;
    }
    return _chapterNavigation.resolveNearestReadableChapterIndex(
      chapters,
      currentChapterIndex,
      preferForward: true,
    );
  }
}
