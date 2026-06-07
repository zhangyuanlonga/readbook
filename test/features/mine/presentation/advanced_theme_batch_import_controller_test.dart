import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_service.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/advanced_theme_batch_import_controller.dart';

void main() {
  group('AdvancedThemeBatchImportController', () {
    const controller = AdvancedThemeBatchImportController();

    test('maps service progress stages to queue item statuses', () {
      expect(
        controller.statusForProgressStage(
          AdvancedThemeImportProgressStage.reading,
        ),
        AdvancedThemeImportQueueItemStatus.reading,
      );
      expect(
        controller.statusForProgressStage(
          AdvancedThemeImportProgressStage.parsing,
        ),
        AdvancedThemeImportQueueItemStatus.parsing,
      );
      expect(
        controller.statusForProgressStage(
          AdvancedThemeImportProgressStage.importing,
        ),
        AdvancedThemeImportQueueItemStatus.importing,
      );
    });

    test('queue item copyWith can clear stale detail text', () {
      const item = AdvancedThemeImportQueueItem(
        path: 'theme.zip',
        fileName: 'theme.zip',
        sizeBytes: 12,
        detail: 'old',
      );

      final next = item.copyWith(
        status: AdvancedThemeImportQueueItemStatus.reading,
        clearDetail: true,
      );

      expect(next.status, AdvancedThemeImportQueueItemStatus.reading);
      expect(next.detail, isNull);
    });
  });
}
