import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_tap_zone_resolver.dart';

void main() {
  group('ReaderTapZoneResolver', () {
    const resolver = ReaderTapZoneResolver();
    const rect = Rect.fromLTWH(0, 0, 300, 600);

    test('primary hit uses left center right reader controls', () {
      expect(
        resolver
            .resolvePrimaryHit(localPosition: const Offset(40, 300), rect: rect)
            ?.action,
        ReaderTapZoneAction.previousPage,
      );
      expect(
        resolver
            .resolvePrimaryHit(
              localPosition: const Offset(150, 300),
              rect: rect,
            )
            ?.action,
        ReaderTapZoneAction.toggleToolbar,
      );
      expect(
        resolver
            .resolvePrimaryHit(
              localPosition: const Offset(260, 300),
              rect: rect,
            )
            ?.action,
        ReaderTapZoneAction.nextPage,
      );
    });

    test('primary hit ignores taps outside reader content rect', () {
      expect(
        resolver.resolvePrimaryHit(
          localPosition: const Offset(-1, 300),
          rect: rect,
        ),
        isNull,
      );
    });
  });
}
