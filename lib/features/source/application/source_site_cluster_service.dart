class SourceSiteClusterMeta {
  const SourceSiteClusterMeta({
    this.primaryHost,
    this.registrableDomain,
    this.clusterKey,
  });

  final String? primaryHost;
  final String? registrableDomain;
  final String? clusterKey;
}

class SourceSiteClusterService {
  const SourceSiteClusterService();

  SourceSiteClusterMeta resolve({
    String? homepage,
    Iterable<String> domains = const <String>[],
  }) {
    final normalizedHomepageHost = _hostFromUrl(homepage);
    final normalizedDomains = domains
        .map(_normalizeHost)
        .whereType<String>()
        .toList(growable: false);

    final primaryHost =
        normalizedHomepageHost ??
        (normalizedDomains.isEmpty ? null : normalizedDomains.first);
    final registrableDomain =
        primaryHost == null ? null : _toRegistrableDomain(primaryHost);
    final clusterKey = registrableDomain;

    return SourceSiteClusterMeta(
      primaryHost: primaryHost,
      registrableDomain: registrableDomain,
      clusterKey: clusterKey,
    );
  }

  String? _hostFromUrl(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      return null;
    }
    return _normalizeHost(uri.host);
  }

  String? _normalizeHost(String? value) {
    final host = value?.trim().toLowerCase();
    if (host == null || host.isEmpty) {
      return null;
    }
    return host;
  }

  String _toRegistrableDomain(String host) {
    final parts = host.split('.').where((item) => item.isNotEmpty).toList();
    if (parts.length <= 2) {
      return host;
    }

    final suffix = '${parts[parts.length - 2]}.${parts.last}';
    const doubleLevelSuffixes = <String>{
      'com.cn',
      'net.cn',
      'org.cn',
      'gov.cn',
      'co.uk',
      'org.uk',
      'ac.uk',
      'com.hk',
      'com.tw',
      'co.jp',
    };
    if (doubleLevelSuffixes.contains(suffix) && parts.length >= 3) {
      return '${parts[parts.length - 3]}.$suffix';
    }
    return suffix;
  }
}
