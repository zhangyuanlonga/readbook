import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/theme/app_official_theme_presets.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_provider.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final documentsDir = await Directory.systemTemp.createTemp(
      'official_theme_activation_docs_',
    );
    addTearDown(() => documentsDir.delete(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return documentsDir.path;
          }
          return documentsDir.path;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, null);
    });
    final prefs = await SharedPreferences.getInstance();
    ActiveAdvancedThemeIdNotifier.prime(prefs);
    ActiveThemeAppearanceSnapshotNotifier.prime(prefs);
  });

  test('defaults active theme id to official lumina', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(activeAdvancedThemeIdProvider),
      appDefaultOfficialThemeId,
    );
    expect(
      container
          .read(activeThemeAppearanceSnapshotProvider)
          ?.lightConfig
          ?.colors
          .primaryColorValue,
      0xFF1C1B1B,
    );
  });

  test('advanced theme service stores official preset snapshot', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = AdvancedThemeService(preferences: prefs);

    await service.saveActiveThemeId('official:ink-green');

    expect(await service.loadActiveThemeId(), 'official:ink-green');
    final snapshot = await service.loadActiveThemeAppearanceSnapshot();
    expect(snapshot?.lightConfig?.colors.primaryColorValue, 0xFF2F7652);
  });
}
