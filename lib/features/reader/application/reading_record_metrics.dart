int estimateSessionReadChars({
  required int chapterLength,
  required double startRatio,
  required double endRatio,
  double? furthestRatio,
  bool countAsText = true,
}) {
  if (!countAsText || chapterLength <= 0) {
    return 0;
  }

  final safeStart = startRatio.clamp(0.0, 1.0).toDouble();
  final safeEnd = endRatio.clamp(0.0, 1.0).toDouble();
  final safeFurthest = (furthestRatio ?? safeEnd).clamp(0.0, 1.0).toDouble();
  final effectiveEnd = safeFurthest > safeEnd ? safeFurthest : safeEnd;
  final forwardProgress = (effectiveEnd - safeStart).clamp(0.0, 1.0).toDouble();

  return (forwardProgress * chapterLength).round().clamp(0, chapterLength);
}
