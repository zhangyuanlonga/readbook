import 'package:shuxiang_reading_next/features/source/application/source_site_cluster_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceSiteClusterService', () {
    const service = SourceSiteClusterService();

    test('resolves primary host and cluster from homepage first', () {
      final meta = service.resolve(
        homepage: 'https://www.sudugu.org/book/1',
        domains: const <String>['sudugu.org'],
      );

      expect(meta.primaryHost, 'www.sudugu.org');
      expect(meta.registrableDomain, 'sudugu.org');
      expect(meta.clusterKey, 'sudugu.org');
    });

    test('falls back to domains when homepage is absent', () {
      final meta = service.resolve(
        domains: const <String>['m.example.com', 'www.example.com'],
      );

      expect(meta.primaryHost, 'm.example.com');
      expect(meta.registrableDomain, 'example.com');
      expect(meta.clusterKey, 'example.com');
    });
  });
}
