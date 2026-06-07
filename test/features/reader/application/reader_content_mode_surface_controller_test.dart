import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_mode_surface_controller.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';

void main() {
  group('ReaderContentModeSurfaceController', () {
    const controller = ReaderContentModeSurfaceController();

    test('describes paged text surface', () {
      final model = controller.buildModel(
        mode: ReaderContentMode.text,
        isTextPagedViewport: true,
        isTextScrollViewport: false,
      );

      expect(model.viewportLabel, '文本分页');
      expect(model.supportsTextSelection, isTrue);
      expect(model.supportsPagedText, isTrue);
    });

    test('describes audio surface without text selection', () {
      final model = controller.buildModel(
        mode: ReaderContentMode.audio,
        isTextPagedViewport: false,
        isTextScrollViewport: false,
      );

      expect(model.viewportLabel, '听书');
      expect(model.supportsTextSelection, isFalse);
      expect(model.supportsPagedText, isFalse);
    });
  });
}
