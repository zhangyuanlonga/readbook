import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_feature_parity_matrix.dart';

void main() {
  group('ReaderFeatureParityMatrix', () {
    test('tracks V7 P0-P3 user visible reader capabilities', () {
      final ids =
          ReaderFeatureParityMatrix.v7CoreItems.map((item) => item.id).toSet();

      expect(ids, contains('paper_curl_animation'));
      expect(ids, contains('tap_keyboard_volume_wheel_intent'));
      expect(ids, contains('annotation_style_visuals'));
      expect(ids, contains('bookmark_layout_restore'));
      expect(ids, contains('search_highlight_jump'));
      expect(ids, contains('manga_surface_isolation'));
    });

    test('marks migrated animations as release complete items', () {
      final completeIds =
          ReaderFeatureParityMatrix.v7CoreItems
              .where((item) => item.isReleaseComplete)
              .map((item) => item.id)
              .toSet();

      expect(completeIds, contains('paper_curl_animation'));
      expect(completeIds, contains('curl_animation'));
      expect(completeIds, contains('cover_translate_fade_animation'));
    });

    test('keeps release incomplete items visible for later V nodes', () {
      final incompleteIds =
          ReaderFeatureParityMatrix.releaseIncompleteItems()
              .map((item) => item.id)
              .toSet();

      expect(incompleteIds, contains('layout_cross_page_drag_selection'));
      expect(incompleteIds, contains('annotation_toolbar_restore'));
      expect(incompleteIds, contains('bookmark_layout_restore'));
      expect(incompleteIds, contains('auto_read_paged_scroll'));
    });
  });
}
