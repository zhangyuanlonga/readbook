enum ReaderReplaceRuleMode { inherit, enabled, disabled }

class ReaderReplacePreference {
  const ReaderReplacePreference({
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.mode,
    required this.updatedAt,
  });

  final String bookId;
  final String sourceId;
  final String detailUrl;
  final ReaderReplaceRuleMode mode;
  final DateTime updatedAt;
}
