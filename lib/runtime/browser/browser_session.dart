class BrowserSessionSnapshot {
  const BrowserSessionSnapshot({
    required this.sourceId,
    this.lastVisitedUrl,
    this.lastVerifiedAt,
  });

  final String sourceId;
  final Uri? lastVisitedUrl;
  final DateTime? lastVerifiedAt;
}
