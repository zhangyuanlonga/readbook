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
          requestedMode: ReaderLayoutEngineMode.adapterOnly,
          effectiveMode: ReaderLayoutEngineMode.legacy,
          layoutPageCount: 0,
          elapsedMicros: 120,
          surfaceKind: ReaderSurfaceKind.text,
          fallbackReason: 'adapter_error',
          errorMessage: 'boom',
        ),
      );

      expect(context['layoutRequestedMode'], 'adapterOnly');
      expect(context['layoutEffectiveMode'], 'legacy');
      expect(context['layoutPageCount'], 0);
      expect(context['layoutUsedFallback'], isTrue);
      expect(context['layoutSurfaceKind'], 'text');
      expect(context['layoutFallbackReason'], 'adapter_error');
      expect(context['layoutErrorMessage'], 'boom');
    });
  });

  group('ReaderLayoutDevOptions', () {
    test('defaults to legacy and can enable adapter diagnostics', () {
      const defaults = ReaderLayoutDevOptions();
      const adapterOnly = ReaderLayoutDevOptions.adapterOnlyDiagnostics();

      expect(defaults.mode, ReaderLayoutEngineMode.legacy);
      expect(defaults.buildsLayout, isFalse);
      expect(adapterOnly.mode, ReaderLayoutEngineMode.adapterOnly);
      expect(adapterOnly.diagnosticsEnabled, isTrue);
      expect(adapterOnly.buildsLayout, isTrue);
    });
  });
}
