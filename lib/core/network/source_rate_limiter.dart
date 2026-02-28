class SourceRateLimiter {
  SourceRateLimiter();

  final Map<String, _LimiterBucket> _buckets = <String, _LimiterBucket>{};

  Future<void> acquire({String? sourceId, String? concurrentRate}) async {
    final normalizedSourceId = sourceId?.trim() ?? '';
    final normalizedRate = concurrentRate?.trim() ?? '';
    if (normalizedSourceId.isEmpty || normalizedRate.isEmpty) {
      return;
    }

    final spec = _RateSpec.tryParse(normalizedRate);
    if (spec == null) {
      return;
    }

    final bucket = _buckets.putIfAbsent(
      normalizedSourceId,
      () => _LimiterBucket(spec: spec),
    );
    bucket.tail = bucket.tail.then((_) => _acquireInternal(bucket, spec));
    return bucket.tail;
  }

  Future<void> _acquireInternal(_LimiterBucket bucket, _RateSpec spec) async {
    if (bucket.spec != spec) {
      bucket.spec = spec;
      bucket.timestamps.clear();
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    bucket.timestamps.removeWhere((time) => now - time >= spec.windowMs);

    if (bucket.timestamps.length < spec.count) {
      bucket.timestamps.add(now);
      return;
    }

    final first = bucket.timestamps.first;
    final waitMs = spec.windowMs - (now - first);
    if (waitMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: waitMs));
    }

    final nextNow = DateTime.now().millisecondsSinceEpoch;
    bucket.timestamps.removeWhere((time) => nextNow - time >= spec.windowMs);
    bucket.timestamps.add(nextNow);
  }
}

class _LimiterBucket {
  _LimiterBucket({required this.spec});

  _RateSpec spec;
  final List<int> timestamps = <int>[];
  Future<void> tail = Future<void>.value();
}

class _RateSpec {
  const _RateSpec({required this.count, required this.windowMs});

  final int count;
  final int windowMs;

  static _RateSpec? tryParse(String rawRate) {
    final normalized = rawRate.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final slashIndex = normalized.indexOf('/');
    if (slashIndex <= 0 || slashIndex >= normalized.length - 1) {
      return null;
    }

    final count = int.tryParse(normalized.substring(0, slashIndex).trim());
    final windowMs = int.tryParse(normalized.substring(slashIndex + 1).trim());
    if (count == null || windowMs == null || count <= 0 || windowMs <= 0) {
      return null;
    }

    return _RateSpec(count: count, windowMs: windowMs);
  }

  @override
  bool operator ==(Object other) {
    return other is _RateSpec &&
        other.count == count &&
        other.windowMs == windowMs;
  }

  @override
  int get hashCode => Object.hash(count, windowMs);
}
