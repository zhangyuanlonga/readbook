class BookshelfImportCandidate {
  const BookshelfImportCandidate({
    required this.filePath,
    required this.displayName,
  });

  final String filePath;
  final String displayName;
}

class BookshelfImportSummary {
  const BookshelfImportSummary({
    required this.successCount,
    required this.failureCount,
    this.lastError,
  });

  final int successCount;
  final int failureCount;
  final String? lastError;

  bool get hasSuccess => successCount > 0;
}

class BookshelfImportProgress {
  const BookshelfImportProgress({
    required this.completedCount,
    required this.totalCount,
    required this.currentFileLabel,
  });

  final int completedCount;
  final int totalCount;
  final String currentFileLabel;
}

typedef BookshelfImportProgressCallback =
    void Function(BookshelfImportProgress progress);

class BookshelfFlowCoordinator {
  const BookshelfFlowCoordinator();

  bool shouldCollapseSearch({
    required bool hasFocus,
    required bool hasKeyword,
    required bool alwaysShowSearchBar,
    required bool isSearchExpanded,
  }) {
    return !hasFocus && !hasKeyword && !alwaysShowSearchBar && isSearchExpanded;
  }

  bool canStartSelectionMode({
    required bool isBatchDeleting,
    required bool isBatchUpdatingCovers,
    required bool hasFilteredBooks,
  }) {
    return !isBatchDeleting && !isBatchUpdatingCovers && hasFilteredBooks;
  }

  Set<String> toggleSelectedKeys(Set<String> currentKeys, String key) {
    final next = Set<String>.from(currentKeys);
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    return Set<String>.unmodifiable(next);
  }

  Set<String> selectAllVisibleKeys(Iterable<String> keys) {
    return Set<String>.unmodifiable(keys.where((key) => key.trim().isNotEmpty));
  }

  Set<String> syncSelectedKeys({
    required Set<String> selectedKeys,
    required Iterable<String> visibleKeys,
  }) {
    final validKeys = visibleKeys.where((key) => key.trim().isNotEmpty).toSet();
    return Set<String>.unmodifiable(
      selectedKeys.where((key) => validKeys.contains(key)),
    );
  }

  Future<BookshelfImportSummary> importLocalBooks({
    required Iterable<BookshelfImportCandidate> candidates,
    required Future<void> Function(BookshelfImportCandidate candidate) importer,
    String Function(Object error)? errorFormatter,
    BookshelfImportProgressCallback? onProgress,
  }) async {
    var successCount = 0;
    var failureCount = 0;
    String? lastError;
    final importTargets = candidates.toList(growable: false);

    for (var index = 0; index < importTargets.length; index += 1) {
      final candidate = importTargets[index];
      if (candidate.filePath.trim().isEmpty) {
        continue;
      }
      onProgress?.call(
        BookshelfImportProgress(
          completedCount: index,
          totalCount: importTargets.length,
          currentFileLabel: candidate.displayName,
        ),
      );
      try {
        await importer(candidate);
        successCount += 1;
      } catch (error) {
        failureCount += 1;
        lastError = errorFormatter?.call(error) ?? '$error';
      }
    }

    if (importTargets.isNotEmpty) {
      onProgress?.call(
        BookshelfImportProgress(
          completedCount: importTargets.length,
          totalCount: importTargets.length,
          currentFileLabel: importTargets.last.displayName,
        ),
      );
    }

    return BookshelfImportSummary(
      successCount: successCount,
      failureCount: failureCount,
      lastError: lastError,
    );
  }
}
