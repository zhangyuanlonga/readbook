enum CacheStep { search, detail, chapters, content }

class CachePolicy {
  const CachePolicy({required this.ttl, this.persistent = false});

  final Duration ttl;
  final bool persistent;

  factory CachePolicy.forStep(CacheStep step) {
    switch (step) {
      case CacheStep.search:
        return const CachePolicy(ttl: Duration(minutes: 2));
      case CacheStep.detail:
        return const CachePolicy(ttl: Duration(minutes: 30));
      case CacheStep.chapters:
        return const CachePolicy(ttl: Duration(hours: 2));
      case CacheStep.content:
        return const CachePolicy(ttl: Duration(hours: 12));
    }
  }
}
