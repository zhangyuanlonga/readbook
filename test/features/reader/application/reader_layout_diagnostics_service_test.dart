import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_diagnostics_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_engine_mode.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_surface_position.dart';

void main() {
  group('ReaderLayoutDiagnosticsPresenter', () {
    test('maps layout diagnostics into reader diagnostics context', () {
      const presenter = ReaderLayoutDiagnosticsPresenter();
      final context = presenter.toReaderDiagnosticsContext(
        const ReaderLayoutDiagnostics(
          requestedMode: ReaderLayoutEngineMode.experimental,
          effectiveMode: ReaderLayoutEngineMode.experimental,
          layoutPageCount: 0,
          elapsedMicros: 120,
          surfaceKind: ReaderSurfaceKind.text,
          failureReason: 'layout_stream_failed',
          errorMessage: 'boom',
        ),
      );

      expect(context['layoutRequestedMode'], 'experimental');
      expect(context['layoutEffectiveMode'], 'experimental');
      expect(context['layoutPageCount'], 0);
      expect(context['layoutHasFailure'], isTrue);
      expect(context['layoutSurfaceKind'], 'text');
      expect(context['layoutFailureReason'], 'layout_stream_failed');
      expect(context['layoutErrorMessage'], 'boom');
    });
  });

  group('ReaderLayoutDevOptions', () {
    test('defaults to layout release mode', () {
      const defaults = ReaderLayoutDevOptions();

      expect(defaults.mode, ReaderLayoutEngineMode.experimental);
      expect(defaults.buildsLayout, isTrue);
    });
  });
}
