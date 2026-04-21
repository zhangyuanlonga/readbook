import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';

void main() {
  test('mode config serializes and copies reader wallpaper path', () {
    const config = AppAdvancedThemeModeConfig(
      wallpaperPath: '/tmp/app_bg.jpg',
      readerWallpaperPath: '/tmp/reader_bg.jpg',
    );

    final json = config.toJson();
    expect(json['wallpaperPath'], '/tmp/app_bg.jpg');
    expect(json['readerWallpaperPath'], '/tmp/reader_bg.jpg');

    final restored = AppAdvancedThemeModeConfig.fromJson(json);
    expect(restored.wallpaperPath, '/tmp/app_bg.jpg');
    expect(restored.readerWallpaperPath, '/tmp/reader_bg.jpg');
    expect(restored.hasReaderWallpaper, isTrue);

    final cleared = restored.copyWith(clearReaderWallpaperPath: true);
    expect(cleared.readerWallpaperPath, isNull);
    expect(cleared.hasReaderWallpaper, isFalse);
  });
}
