class SourceHealthAutoDisableService {
  SourceHealthAutoDisableService();

  static final SourceHealthAutoDisableService instance =
      SourceHealthAutoDisableService();

  Future<void> evaluateSource({
    required String sourceId,
    required String sourceName,
    required String trigger,
  }) async {}
}
