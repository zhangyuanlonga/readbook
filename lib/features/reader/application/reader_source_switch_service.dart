import '../../../domain/entities/book.dart';
import '../../../domain/entities/chapter.dart';
import '../../book/application/book_detail_service.dart';
import 'reader_logical_position.dart';
import 'reader_source_switch_target_resolver.dart';

class ReaderSourceSwitchCurrentState {
  const ReaderSourceSwitchCurrentState({
    required this.bookId,
    required this.chapters,
    required this.chapterTitle,
    required this.chapterIndex,
    required this.logicalPosition,
  });

  final String bookId;
  final List<Chapter> chapters;
  final String? chapterTitle;
  final int? chapterIndex;
  final ReaderLogicalPosition? logicalPosition;
}

class ReaderSourceSwitchDestination {
  const ReaderSourceSwitchDestination({
    required this.book,
    required this.detailResult,
  });

  final Book book;
  final BookDetailLoadResult detailResult;
}

class ReaderSourceSwitchProgressMigration {
  const ReaderSourceSwitchProgressMigration({
    required this.previousBookId,
    required this.nextBookId,
    required this.logicalPosition,
    required this.chapterPositionRatio,
  });

  final String previousBookId;
  final String nextBookId;
  final ReaderLogicalPosition logicalPosition;
  final double chapterPositionRatio;
}

class ReaderSourceSwitchPlan {
  const ReaderSourceSwitchPlan({
    required this.target,
    required this.targetChapter,
    required this.progressMigration,
  });

  final ReaderSourceSwitchTarget target;
  final Chapter targetChapter;
  final ReaderSourceSwitchProgressMigration progressMigration;
}

class ReaderSourceSwitchService {
  const ReaderSourceSwitchService({
    ReaderSourceSwitchTargetResolver targetResolver =
        const ReaderSourceSwitchTargetResolver(),
  }) : _targetResolver = targetResolver;

  final ReaderSourceSwitchTargetResolver _targetResolver;

  ReaderSourceSwitchPlan buildPlan({
    required ReaderSourceSwitchCurrentState current,
    required ReaderSourceSwitchDestination destination,
    required int lagTolerance,
  }) {
    final targetChapters = destination.detailResult.chapters;
    final target = _targetResolver.resolve(
      currentChapters: current.chapters,
      targetChapters: targetChapters,
      previousChapterTitle: current.chapterTitle,
      previousChapterIndex: current.chapterIndex,
      previousLogicalPosition: current.logicalPosition,
      lagTolerance: lagTolerance,
    );

    final nextBookId = destination.book.id.trim();
    return ReaderSourceSwitchPlan(
      target: target,
      targetChapter: targetChapters[target.targetChapterIndex],
      progressMigration: ReaderSourceSwitchProgressMigration(
        previousBookId: current.bookId.trim(),
        nextBookId: nextBookId,
        logicalPosition: target.logicalPosition,
        chapterPositionRatio: target.logicalPosition.chapterPositionRatio,
      ),
    );
  }
}
