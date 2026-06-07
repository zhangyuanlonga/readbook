import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_editor_resource_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdvancedThemeEditorResourceService', () {
    test('keeps asset paths and filters missing files', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'advanced_theme_resource_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final imageFile = File('${tempDir.path}/cover.png');
      await imageFile.writeAsBytes([0, 1, 2, 3]);
      final service = AdvancedThemeEditorResourceService();

      expect(
        service.resolveExistingImagePath('assets/images/cover.png'),
        'assets/images/cover.png',
      );
      expect(
        service.existingImagePaths([
          imageFile.path,
          '${tempDir.path}/missing.png',
          'assets/images/cover.png',
        ]),
        [imageFile.path, 'assets/images/cover.png'],
      );
    });

    test('reads picked image data from file and supports file uri', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'advanced_theme_resource_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final imageFile = File('${tempDir.path}/wallpaper.png');
      await imageFile.writeAsBytes([9, 8, 7]);
      final service = AdvancedThemeEditorResourceService();

      final picked = await service.pickedImageFromPath(
        imageFile.uri.toString(),
      );
      final provider = service.imageProviderFor(imageFile.path);

      expect(picked?.name, 'wallpaper.png');
      expect(picked?.bytes, [9, 8, 7]);
      expect(provider, isA<FileImage>());
    });
  });
}
