import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_image_decode_budget.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_resource_budget.dart';

void main() {
  group('ReaderImageDecodeBudgetResolver', () {
    const resolver = ReaderImageDecodeBudgetResolver();

    test('scales image decode size from resource budget', () {
      final normal = resolver.resolve(
        role: ReaderImageDecodeRole.manga,
        resourceBudget: const ReaderResourceBudgetResolver().resolve(
          const ReaderResourceBudgetInput(),
        ),
        logicalWidth: 400,
        logicalHeight: 600,
        devicePixelRatio: 2,
      );
      final low = resolver.resolve(
        role: ReaderImageDecodeRole.manga,
        resourceBudget: const ReaderResourceBudgetResolver().resolve(
          const ReaderResourceBudgetInput(deviceTier: ReaderDeviceTier.low),
        ),
        logicalWidth: 400,
        logicalHeight: 600,
        devicePixelRatio: 2,
      );

      expect(low.cacheWidth, lessThan(normal.cacheWidth!));
      expect(
        resolver
            .resolve(
              role: ReaderImageDecodeRole.epubInline,
              resourceBudget: const ReaderResourceBudgetResolver().resolve(
                const ReaderResourceBudgetInput(),
              ),
              logicalWidth: 400,
              devicePixelRatio: 2,
            )
            .cacheWidth,
        lessThan(normal.cacheWidth!),
      );
      expect(
        low.imageCacheMaximumSizeBytes,
        lessThan(normal.imageCacheMaximumSizeBytes),
      );
      expect(normal.maxDataUriBytes, 5 * 1024 * 1024);
    });
  });
}
