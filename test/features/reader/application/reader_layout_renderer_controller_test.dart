import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_cache_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_diagnostics_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_engine.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_engine_mode.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_renderer_controller.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_request.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_stream_controller.dart';
import 'package:shuxiang_reading_next/features/reader/domain/entities/reader_layout_models.dart';

void main() {
  group('ReaderLayoutRendererController', () {
    test('uses layout release mode by default', () async {
      final controller = ReaderLayoutRendererController();

      final states =
          await controller
              .watch(
                _request(text: '正文'),
                options: const ReaderLayoutDevOptions(),
              )
              .toList();

      expect(states.first.kind, ReaderLayoutRendererStateKind.loading);
      expect(states.last.kind, ReaderLayoutRendererStateKind.ready);
      expect(states.last.hasFailure, isFalse);
      expect(states.last.pages, isNotEmpty);
    });

    test(
      'streams experimental layout and stores the completed pages',
      () async {
        final cacheService = ReaderLayoutCacheService(maxMemoryEntries: 2);
        final controller = ReaderLayoutRendererController(
          cacheService: cacheService,
        );
        final request = _request(text: '正文内容' * 80);

        final states =
            await controller
                .watch(
                  request,
                  options: const ReaderLayoutDevOptions(
                    mode: ReaderLayoutEngineMode.experimental,
                    diagnosticsEnabled: true,
                  ),
                  targetRatio: 0.75,
                )
                .toList();

        expect(states.first.kind, ReaderLayoutRendererStateKind.loading);
        expect(states.last.kind, ReaderLayoutRendererStateKind.ready);
        expect(states.last.completed, isTrue);
        expect(states.last.pages.length, greaterThan(1));
        expect(states.last.pageIndex, greaterThan(0));
        expect(states.last.fromCache, isFalse);
        expect(
          states.last.diagnosticsContext['layoutEffectiveMode'],
          'experimental',
        );

        final cachedStates =
            await controller
                .watch(
                  request,
                  options: const ReaderLayoutDevOptions(
                    mode: ReaderLayoutEngineMode.experimental,
                    diagnosticsEnabled: true,
                  ),
                )
                .toList();

        expect(cachedStates, hasLength(1));
        expect(cachedStates.single.kind, ReaderLayoutRendererStateKind.ready);
        expect(cachedStates.single.fromCache, isTrue);
      },
    );

    test('renders epub-like title, text, and image blocks', () async {
      final controller = ReaderLayoutRendererController();

      final states =
          await controller
              .watch(
                ReaderLayoutRequest(
                  chapterId: 'chapter-epub',
                  chapterIndex: 0,
                  blocks: const <ReaderLayoutBlock>[
                    ReaderLayoutBlock.title(text: '标题'),
                    ReaderLayoutBlock.paragraph(text: '正文内容'),
                    ReaderLayoutBlock.image(imageUrl: 'file:///cover.png'),
                  ],
                  spec: _spec,
                  documentFingerprint: 'epub-like',
                ),
                options: const ReaderLayoutDevOptions(
                  mode: ReaderLayoutEngineMode.experimental,
                  diagnosticsEnabled: true,
                ),
              )
              .toList();

      final pages = states.last.pages;
      expect(states.last.kind, ReaderLayoutRendererStateKind.ready);
      expect(
        pages.expand((page) => page.lines).any((line) => line.isTitle),
        isTrue,
      );
      expect(
        pages.expand((page) => page.lines).any((line) => line.isImage),
        isTrue,
      );
    });

    test('reports failed state when layout stream fails', () async {
      final controller = ReaderLayoutRendererController(
        streamController: ReaderLayoutStreamController(
          engine: const _ThrowingLayoutEngine(),
        ),
      );

      final states =
          await controller
              .watch(
                _request(text: 'boom'),
                options: const ReaderLayoutDevOptions(
                  mode: ReaderLayoutEngineMode.experimental,
                  diagnosticsEnabled: true,
                ),
              )
              .toList();

      expect(states.last.kind, ReaderLayoutRendererStateKind.failed);
      expect(states.last.hasFailure, isTrue);
      expect(states.last.diagnostics.failureReason, 'layout_stream_failed');
      expect(states.last.errorMessage, contains('layout failed'));
    });
  });
}

ReaderLayoutRequest _request({required String text}) {
  return ReaderLayoutRequest.fromParagraphs(
    chapterId: 'chapter-1',
    chapterIndex: 0,
    paragraphs: <String>[text],
    spec: _spec,
    documentFingerprint: text,
  );
}

class _ThrowingLayoutEngine extends ReaderLayoutEngine {
  const _ThrowingLayoutEngine();

  @override
  Future<ReaderLayoutResult?> layout(
    ReaderLayoutRequest request, {
    ReaderLayoutCancellationToken? cancellationToken,
    void Function(ReaderLayoutPage page)? onPageReady,
  }) async {
    throw StateError('layout failed');
  }
}

const _spec = ReaderLayoutSpec(
  contentWidth: 80,
  contentHeight: 42,
  contentRectLeft: 0,
  contentRectTop: 0,
  pagePaddingTop: 0,
  pagePaddingRight: 0,
  pagePaddingBottom: 0,
  pagePaddingLeft: 0,
  pinnedHeaderHeight: 0,
  fontSize: 14,
  lineHeight: 1,
  paragraphSpacing: 2,
  paragraphIndent: 0,
  letterSpacing: 0,
  textFullJustifyEnabled: false,
  bodyTextItalicEnabled: false,
  fontWeightLevel: ReaderFontWeightLevel.regular,
  fontWeightValue: null,
  fontSource: ReaderFontSource.system,
  systemFontPreset: ReaderSystemFontPreset.defaultSans,
  fontFamilyKey: null,
);
