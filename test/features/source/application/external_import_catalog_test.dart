import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/source/application/external_import_catalog.dart';
import 'package:shuxiang_reading_next/features/source/application/external_source_import_bridge.dart';

void main() {
  test('advanced theme import accepts new bundles and legacy json files', () {
    expect(
      ExternalImportCatalog.supportsFileLabel(
        ExternalImportPayloadType.advancedTheme,
        'theme.zip',
      ),
      isTrue,
    );
    expect(
      ExternalImportCatalog.supportsFileLabel(
        ExternalImportPayloadType.advancedTheme,
        'theme.json',
      ),
      isTrue,
    );
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
  });
}
