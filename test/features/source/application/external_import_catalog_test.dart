import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/features/source/application/external_import_catalog.dart';
import 'package:shuxiang_reading_next/features/source/application/external_source_import_bridge.dart';

void main() {
  group('ExternalImportCatalog', () {
    test('maps payload types to canonical routes', () {
      expect(
        ExternalImportCatalog.routeForPayloadType(
          ExternalImportPayloadType.scriptSource,
        ),
        '/source',
      );
      expect(
        ExternalImportCatalog.routeForPayloadType(
          ExternalImportPayloadType.localBook,
        ),
        '/bookshelf',
      );
      expect(
        ExternalImportCatalog.routeForPayloadType(
          ExternalImportPayloadType.advancedTheme,
        ),
        '/appearance/advanced-themes',
      );
    });

    test('validates script source extensions consistently', () {
      expect(
        ExternalImportCatalog.supportsFileLabel(
          ExternalImportPayloadType.scriptSource,
          'demo.js',
        ),
        isTrue,
      );
      expect(
        ExternalImportCatalog.supportsFileLabel(
          ExternalImportPayloadType.scriptSource,
          'demo.mjs',
        ),
        isTrue,
      );
      expect(
        ExternalImportCatalog.supportsFileLabel(
          ExternalImportPayloadType.scriptSource,
          'demo.epub',
        ),
        isFalse,
      );
    });

    test('validates local book extensions consistently', () {
      expect(
        ExternalImportCatalog.supportsFileLabel(
          ExternalImportPayloadType.localBook,
          'novel.azw3',
        ),
        isTrue,
      );
      expect(
        ExternalImportCatalog.supportsFileLabel(
          ExternalImportPayloadType.localBook,
          'novel.js',
        ),
        isFalse,
      );
    });

    test('validates advanced theme extensions consistently', () {
      expect(
        ExternalImportCatalog.supportsFileLabel(
          ExternalImportPayloadType.advancedTheme,
          'theme.red',
        ),
        isTrue,
      );
      expect(
        ExternalImportCatalog.supportsFileLabel(
          ExternalImportPayloadType.advancedTheme,
          'theme.rgshare',
        ),
        isTrue,
      );
      expect(
        ExternalImportCatalog.supportsFileLabel(
          ExternalImportPayloadType.advancedTheme,
          'theme.txt',
        ),
        isFalse,
      );
    });
  });
}
