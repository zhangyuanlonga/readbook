import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/domain/entities/launch_image_gallery.dart';
import 'package:shuxiang_reading_next/features/mine/application/launch_image_gallery_service.dart';

void main() {
  group('LaunchImageGalleryService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('persists galleries and active gallery id', () async {
      final service = LaunchImageGalleryService();
      final gallery = LaunchImageGallery(
        id: 'launch_gallery_a',
        name: '品牌启动图',
        createdAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
        imagePaths: const <String>[],
      );

      await service.saveGalleries(<LaunchImageGallery>[gallery]);
      await service.saveActiveGalleryId(gallery.id);

      final galleries = await service.loadGalleries();
      expect(galleries, hasLength(1));
      expect(galleries.first.name, '品牌启动图');
      expect(await service.loadActiveGalleryId(), gallery.id);
      expect((await service.loadActiveGallery())?.id, gallery.id);
    });

    test('resolves first existing image path from active gallery', () async {
      final service = LaunchImageGalleryService();
      final tempDir = await Directory.systemTemp.createTemp(
        'launch_image_gallery_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final existingFile = File('${tempDir.path}/launch.png');
      await existingFile.writeAsBytes(const <int>[1, 2, 3], flush: true);

      final gallery = LaunchImageGallery(
        id: 'launch_gallery_b',
        name: '节日启动图',
        createdAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
        imagePaths: <String>['${tempDir.path}/missing.png', existingFile.path],
      );

      await service.saveGalleries(<LaunchImageGallery>[gallery]);
      await service.saveActiveGalleryId(gallery.id);

      expect(await service.loadActiveLaunchImagePath(), existingFile.path);
    });

    test(
      'resolves first existing image path for a specific gallery id',
      () async {
        final service = LaunchImageGalleryService();
        final tempDir = await Directory.systemTemp.createTemp(
          'launch_image_gallery_theme_test_',
        );
        addTearDown(() => tempDir.delete(recursive: true));

        final existingFile = File('${tempDir.path}/launch_theme.png');
        await existingFile.writeAsBytes(const <int>[7, 8, 9], flush: true);

        final gallery = LaunchImageGallery(
          id: 'launch_gallery_theme',
          name: '主题启动图',
          createdAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
          updatedAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
          imagePaths: <String>[
            '${tempDir.path}/missing.png',
            existingFile.path,
          ],
        );

        await service.saveGalleries(<LaunchImageGallery>[gallery]);

        expect(
          await service.loadLaunchImagePathForGallery(gallery.id),
          existingFile.path,
        );
      },
    );
  });
}
