import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/media/image_selection_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/appearance_page_resource_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/app_background_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_font_registry_service.dart';

void main() {
  test('loads appearance resources and imports backgrounds', () async {
    final backgroundService = _FakeAppBackgroundService();
    final fontService = _FakeReaderFontRegistryService();
    final service = AppearancePageResourceService(
      backgroundService: backgroundService,
      fontRegistryService: fontService,
    );

    final resources = await service.loadResources();
    expect(resources.backgroundPaths, ['/tmp/bg_1.png']);
    expect(resources.availableFonts.single.displayName, '测试字体');

    final importedCount = await service.importBackgrounds([
      PickedImageData(bytes: Uint8List.fromList([1, 2, 3]), name: 'a.png'),
      PickedImageData(bytes: Uint8List.fromList([4, 5, 6]), name: 'b.jpg'),
    ]);
    expect(importedCount, 2);
    expect(backgroundService.importedFileNames, ['a.png', 'b.jpg']);

    await service.deleteBackground('/tmp/bg_1.png');
    expect(backgroundService.deletedPaths, ['/tmp/bg_1.png']);
  });
}

class _FakeAppBackgroundService extends AppBackgroundService {
  final List<String> importedFileNames = <String>[];
  final List<String> deletedPaths = <String>[];

  @override
  Future<List<String>> loadBackgroundPaths() async => ['/tmp/bg_1.png'];

  @override
  Future<String> importBackground({
    required List<int> bytes,
    required String fileName,
  }) async {
    importedFileNames.add(fileName);
    return '/tmp/$fileName';
  }

  @override
  Future<void> deleteBackground(String path) async {
    deletedPaths.add(path);
  }
}

class _FakeReaderFontRegistryService extends ReaderFontRegistryService {
  _FakeReaderFontRegistryService();

  @override
  Future<List<ReaderCustomFontEntry>> listRegisteredFonts() async {
    return const [
      ReaderCustomFontEntry(
        fontFamilyKey: 'family_1',
        displayName: '测试字体',
        filePath: '/tmp/font.ttf',
        importedAtEpochMs: 1,
      ),
    ];
  }
}
