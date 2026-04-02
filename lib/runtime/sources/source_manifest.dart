class SourceManifest {
  const SourceManifest({
    required this.name,
    required this.group,
    required this.author,
    required this.description,
    this.domains = const <String>[],
    this.homepage,
    this.enabled = true,
    this.capabilities = const <String>{},
    this.rateLimits = const <String, SourceRateLimit>{},
  });

  final String name;
  final String group;
  final String author;
  final String description;
  final List<String> domains;
  final String? homepage;
  final bool enabled;
  final Set<String> capabilities;
  final Map<String, SourceRateLimit> rateLimits;

  factory SourceManifest.fromMap(Map<String, dynamic> map) {
    return SourceManifest(
      name: map['name']?.toString() ?? '未命名书享源',
      group: map['group']?.toString() ?? '未分组',
      author: map['author']?.toString() ?? 'unknown',
      description: map['description']?.toString() ?? '',
      domains: (map['domains'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic value) => value.toString())
          .toList(growable: false),
      homepage: map['homepage']?.toString(),
      enabled: map['enabled'] is bool ? map['enabled'] as bool : true,
      capabilities: _normalizeCapabilities(
        map['capabilities'] as List<dynamic>? ?? const <dynamic>[],
      ),
      rateLimits: SourceRateLimit.parseMap(map['rateLimits']),
    );
  }

  SourceManifest copyWith({
    String? name,
    String? group,
    String? author,
    String? description,
    List<String>? domains,
    Object? homepage = _sentinel,
    bool? enabled,
    Set<String>? capabilities,
    Map<String, SourceRateLimit>? rateLimits,
  }) {
    return SourceManifest(
      name: name ?? this.name,
      group: group ?? this.group,
      author: author ?? this.author,
      description: description ?? this.description,
      domains: domains ?? this.domains,
      homepage:
          identical(homepage, _sentinel) ? this.homepage : homepage as String?,
      enabled: enabled ?? this.enabled,
      capabilities: capabilities ?? this.capabilities,
      rateLimits: rateLimits ?? this.rateLimits,
    );
  }

  bool supportsCapability(String capability) {
    final normalized = capability.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    return capabilities.contains(normalized);
  }

  SourceRateLimit? rateLimitForUri(Uri uri) {
    final host = uri.host.trim().toLowerCase();
    if (host.isEmpty) {
      return null;
    }
    return rateLimits[host];
  }
}

Set<String> _normalizeCapabilities(Iterable<dynamic> rawValues) {
  return rawValues
      .map((dynamic value) => value.toString().trim().toLowerCase())
      .where((String value) => value.isNotEmpty)
      .toSet();
}

const Object _sentinel = Object();

class SourceRateLimit {
  const SourceRateLimit({required this.minInterval});

  final Duration minInterval;

  static Map<String, SourceRateLimit> parseMap(dynamic raw) {
    if (raw is! Map) {
      return const <String, SourceRateLimit>{};
    }

    final result = <String, SourceRateLimit>{};
    raw.forEach((dynamic key, dynamic value) {
      final domain = key?.toString().trim().toLowerCase() ?? '';
      if (domain.isEmpty) {
        return;
      }
      final rateLimit = SourceRateLimit.tryParse(value);
      if (rateLimit != null) {
        result[domain] = rateLimit;
      }
    });
    return Map.unmodifiable(result);
  }

  static SourceRateLimit? tryParse(dynamic raw) {
    if (raw is num) {
      if (raw <= 0) {
        return null;
      }
      return SourceRateLimit(minInterval: Duration(milliseconds: raw.toInt()));
    }

    if (raw is Map) {
      final rawInterval = raw['minIntervalMs'];
      if (rawInterval is num && rawInterval > 0) {
        return SourceRateLimit(
          minInterval: Duration(milliseconds: rawInterval.toInt()),
        );
      }
    }

    return null;
  }
}

class SourceRuntimeInfo {
  const SourceRuntimeInfo({
    required this.id,
    required this.name,
    required this.group,
    required this.revision,
  });

  final String id;
  final String name;
  final String group;
  final String revision;
}
