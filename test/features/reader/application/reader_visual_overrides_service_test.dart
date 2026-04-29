import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/storage/managed_asset_store.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_visual_overrides.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_visual_overrides_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documentsDir;
  late Directory supportDir;
  late ManagedAssetStore assetStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    documentsDir = await Directory.systemTemp.createTemp('reader_visual_docs_');
    supportDir = await Directory.systemTemp.createTemp(
      'reader_visual_support_',
    );
    assetStore = ManagedAssetStore(
      documentsDirectoryProvider: () async => documentsDir,
      supportDirectoryProvider: () async => supportDir,
    );
  });

  tearDown(() async {
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
    if (supportDir.existsSync()) {
      await supportDir.delete(recursive: true);
    }
  });

  test(
    'persists managed paths as relative overrides and restores them',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final service = ReaderVisualOverridesService(
        preferences: prefs,
        assetStore: assetStore,
      );
      final backgroundFile = File(
        '${documentsDir.path}/reader_backgrounds/demo/background.png',
      );
      await backgroundFile.parent.create(recursive: true);
      await backgroundFile.writeAsBytes(const <int>[1, 2, 3], flush: true);
      final fontFile = File('${supportDir.path}/reader_fonts/demo/font.ttf');
      await fontFile.parent.create(recursive: true);
      await fontFile.writeAsBytes(const <int>[4, 5, 6], flush: true);

      await service.saveOverrides(
        ReaderVisualOverrides(
          hasBackgroundImageOverride: true,
          backgroundImageBase64: backgroundFile.path,
          fontSource: ReaderFontSource.custom,
          hasFontFamilyKeyOverride: true,
          fontFamilyKey: 'demo_font',
          hasCustomFontPathOverride: true,
          customFontPath: fontFile.path,
        ),
      );

      final raw = prefs.getString('reader.visualOverrides');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!);
      expect(
        decoded['backgroundImageBase64'],
        'reader_backgrounds/demo/background.png',
      );
      expect(decoded['customFontPath'], 'reader_fonts/demo/font.ttf');

      final restored = await service.loadOverrides();
      expect(restored.backgroundImageBase64, backgroundFile.path);
      expect(restored.fontFamilyKey, 'demo_font');
      expect(restored.customFontPath, fontFile.path);
    },
  );

  test('removes stored override payload when empty', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = ReaderVisualOverridesService(
      preferences: prefs,
      assetStore: assetStore,
    );

    await prefs.setString(
      'reader.visualOverrides',
      jsonEncode(
        const ReaderVisualOverrides(hasBackgroundImageOverride: true).toJson(),
      ),
    );

    await service.saveOverrides(ReaderVisualOverrides.empty);

    expect(prefs.containsKey('reader.visualOverrides'), isFalse);
  });
}
