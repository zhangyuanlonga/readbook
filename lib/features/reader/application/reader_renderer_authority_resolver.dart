enum ReaderRendererAuthority { release }

class ReaderRendererAuthoritySnapshot {
  const ReaderRendererAuthoritySnapshot({
    required this.authority,
    required this.pageCount,
    required this.currentPageIndex,
    this.reason,
  });

  final ReaderRendererAuthority authority;
  final int pageCount;
  final int currentPageIndex;
  final String? reason;

  bool get usesRelease => authority == ReaderRendererAuthority.release;
}

class ReaderRendererAuthorityResolver {
  const ReaderRendererAuthorityResolver();

  ReaderRendererAuthoritySnapshot resolve({
    required bool releaseActive,
    required int? releasePageCount,
    required int currentPageIndex,
    String? inactiveReason,
  }) {
    final pageCount = releaseActive ? releasePageCount ?? 0 : 0;
    return ReaderRendererAuthoritySnapshot(
      authority: ReaderRendererAuthority.release,
      pageCount: pageCount,
      currentPageIndex: _safePageIndex(currentPageIndex, pageCount),
      reason:
          releaseActive
              ? 'layout_release_active'
              : (inactiveReason ?? 'layout_release_inactive'),
    );
  }

  int _safePageIndex(int pageIndex, int pageCount) {
    if (pageCount <= 0) {
      return 0;
    }
    return pageIndex.clamp(0, pageCount - 1);
  }
}
