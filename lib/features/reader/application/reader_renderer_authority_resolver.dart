enum ReaderRendererAuthority { legacy, release, fallback }

class ReaderRendererAuthoritySnapshot {
  const ReaderRendererAuthoritySnapshot({
    required this.authority,
    required this.pageCount,
    required this.currentPageIndex,
    required this.shouldScheduleLegacyPagination,
    this.reason,
  });

  final ReaderRendererAuthority authority;
  final int pageCount;
  final int currentPageIndex;
  final bool shouldScheduleLegacyPagination;
  final String? reason;

  bool get usesRelease => authority == ReaderRendererAuthority.release;
}

class ReaderRendererAuthorityResolver {
  const ReaderRendererAuthorityResolver();

  ReaderRendererAuthoritySnapshot resolve({
    required bool releaseActive,
    required int? releasePageCount,
    required int legacyTextPageCount,
    required int legacyBlockPageCount,
    required int currentPageIndex,
    String? fallbackReason,
  }) {
    final legacyPageCount = _max(legacyTextPageCount, legacyBlockPageCount);
    if (releaseActive) {
      final pageCount = releasePageCount ?? 0;
      return ReaderRendererAuthoritySnapshot(
        authority: ReaderRendererAuthority.release,
        pageCount: pageCount,
        currentPageIndex: _safePageIndex(currentPageIndex, pageCount),
        shouldScheduleLegacyPagination: false,
        reason: 'layout_release_active',
      );
    }
    if (fallbackReason != null && fallbackReason.isNotEmpty) {
      return ReaderRendererAuthoritySnapshot(
        authority: ReaderRendererAuthority.fallback,
        pageCount: legacyPageCount,
        currentPageIndex: _safePageIndex(currentPageIndex, legacyPageCount),
        shouldScheduleLegacyPagination: true,
        reason: fallbackReason,
      );
    }
    return ReaderRendererAuthoritySnapshot(
      authority: ReaderRendererAuthority.legacy,
      pageCount: legacyPageCount,
      currentPageIndex: _safePageIndex(currentPageIndex, legacyPageCount),
      shouldScheduleLegacyPagination: true,
      reason: 'legacy_renderer_active',
    );
  }

  int _safePageIndex(int pageIndex, int pageCount) {
    if (pageCount <= 0) {
      return 0;
    }
    return pageIndex.clamp(0, pageCount - 1);
  }

  int _max(int a, int b) => a > b ? a : b;
}
