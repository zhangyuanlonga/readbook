import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_engine_mode.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_paged_slice_layout_adapter.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_models.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_spec.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_surface_position.dart';
import 'package:shuxiang_reading_next/features/reader/domain/entities/reader_layout_models.dart';

void main() {
  group('ReaderLayoutFallbackRunner', () {
    test('keeps legacy mode as a zero-cost no-layout path', () {
      const runner = ReaderLayoutFallbackRunner();

      final result = runner.build(
        mode: ReaderLayoutEngineMode.legacy,
        chapterId: 'chapter-1',
        chapterIndex: 0,
        paragraphs: const <String>['abcdef'],
        pagedPages: const <List<ReaderPagedSlice>>[
          <ReaderPagedSlice>[
            ReaderPagedSlice(paragraphIndex: 0, start: 0, end: 3, height: 24),
          ],
        ],
        spec: _spec,
        layoutSignature: 'sig',
        surfaceKind: ReaderSurfaceKind.text,
      );

      expect(result.pages, isEmpty);
      expect(result.usedFallback, isFalse);
      expect(result.diagnostics.effectiveMode, ReaderLayoutEngineMode.legacy);
      expect(result.diagnostics.layoutPageCount, 0);
      expect(result.diagnostics.toJson()['surfaceKind'], 'text');
    });

    test('builds adapter layout in adapterOnly mode', () {
      const runner = ReaderLayoutFallbackRunner();

      final result = runner.build(
        mode: ReaderLayoutEngineMode.adapterOnly,
        chapterId: 'chapter-1',
        chapterIndex: 0,
        paragraphs: const <String>['abcdef'],
        pagedPages: const <List<ReaderPagedSlice>>[
          <ReaderPagedSlice>[
            ReaderPagedSlice(paragraphIndex: 0, start: 1, end: 4, height: 24),
          ],
        ],
        spec: _spec,
        layoutSignature: 'sig',
      );

      expect(result.pages, hasLength(1));
      expect(result.pages.single.lines.single.text, 'bcd');
      expect(result.usedFallback, isFalse);
      expect(
        result.diagnostics.effectiveMode,
        ReaderLayoutEngineMode.adapterOnly,
      );
    });

    test('falls back to legacy when adapter throws', () {
      const runner = ReaderLayoutFallbackRunner(adapter: _ThrowingAdapter());

      final result = runner.build(
        mode: ReaderLayoutEngineMode.adapterOnly,
        chapterId: 'chapter-1',
        chapterIndex: 0,
        paragraphs: const <String>['abcdef'],
        pagedPages: const <List<ReaderPagedSlice>>[],
        spec: _spec,
        layoutSignature: 'sig',
      );

      expect(result.pages, isEmpty);
      expect(result.usedFallback, isTrue);
      expect(result.diagnostics.effectiveMode, ReaderLayoutEngineMode.legacy);
      expect(result.diagnostics.fallbackReason, 'adapter_error');
      expect(result.diagnostics.errorMessage, contains('boom'));
    });
  });
}

class _ThrowingAdapter extends ReaderPagedSliceLayoutAdapter {
  const _ThrowingAdapter();

  @override
  List<ReaderLayoutPage> buildPages({
    required String chapterId,
    required int chapterIndex,
    required List<String> paragraphs,
    required List<List<ReaderPagedSlice>> pagedPages,
    required ReaderPaginationSpec spec,
    required String layoutSignature,
    int paragraphSeparatorLength = 2,
  }) {
    throw StateError('boom');
  }
}

const _spec = ReaderPaginationSpec(
  contentWidth: 320,
  contentHeight: 480,
  contentRectLeft: 18,
  contentRectTop: 18,
  pagePaddingTop: 18,
  pagePaddingRight: 18,
  pagePaddingBottom: 18,
  pagePaddingLeft: 18,
  pinnedHeaderHeight: 40,
  paragraphSpacing: 12,
  paragraphIndent: 2,
  lineHeight: 1.72,
  fontSize: 18,
  letterSpacing: 0.02,
  textFullJustifyEnabled: false,
  bodyTextItalicEnabled: false,
  fontWeightLevel: ReaderFontWeightLevel.regular,
  fontWeightValue: null,
  fontSource: ReaderFontSource.system,
  systemFontPreset: ReaderSystemFontPreset.defaultSans,
  fontFamilyKey: null,
);
