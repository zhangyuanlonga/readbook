import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_diagnostics_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_engine.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_engine_mode.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_renderer_controller.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_request.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_stream_controller.dart';
import 'package:shuxiang_reading_next/features/reader/domain/entities/reader_layout_models.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_layout_paged_view.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_layout_renderer_preview_surface.dart';

void main() {
  testWidgets('preview surface keeps legacy mode on the fallback builder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderLayoutRendererPreviewSurface(
            request: _request('正文'),
            legacyBuilder: (context, state) {
              return Text('legacy:${state.effectiveMode.name}');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('legacy:legacy'), findsOneWidget);
  });

  testWidgets('preview surface renders experimental layout pages', (
    tester,
  ) async {
    final diagnostics = <ReaderLayoutRendererState>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 480,
            child: ReaderLayoutRendererPreviewSurface(
              request: _request('正文内容'),
              options: const ReaderLayoutDevOptions(
                mode: ReaderLayoutEngineMode.experimental,
                diagnosticsEnabled: true,
              ),
              showDiagnosticsOverlay: true,
              textStyle: const TextStyle(fontSize: 16),
              onDiagnostics: diagnostics.add,
              readyBuilder:
                  (context, state, child) => DecoratedBox(
                    decoration: const BoxDecoration(color: Color(0xFFFFFFFF)),
                    child: KeyedSubtree(
                      key: const ValueKey<String>('ready-wrapper'),
                      child: child,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReaderLayoutPagedView), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('ready-wrapper')), findsOneWidget);
    expect(find.text('正文内容', findRichText: true), findsOneWidget);
    expect(diagnostics.last.kind, ReaderLayoutRendererStateKind.ready);
    expect(diagnostics.last.completed, isTrue);
  });

  testWidgets('preview surface falls back when experimental layout fails', (
    tester,
  ) async {
    final controller = ReaderLayoutRendererController(
      streamController: ReaderLayoutStreamController(
        engine: const _ThrowingLayoutEngine(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderLayoutRendererPreviewSurface(
            request: _request('boom'),
            controller: controller,
            options: const ReaderLayoutDevOptions(
              mode: ReaderLayoutEngineMode.experimental,
              diagnosticsEnabled: true,
            ),
            legacyBuilder: (context, state) {
              return Text(state.diagnostics.fallbackReason ?? 'legacy');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('layout_stream_failed'), findsOneWidget);
  });

  testWidgets('strict release validation blocks legacy fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderLayoutRendererPreviewSurface(
            request: _request('正文'),
            options: const ReaderLayoutDevOptions(
              strictReleaseValidation: true,
            ),
            legacyBuilder: (context, state) {
              return const Text('legacy builder should not render');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>('reader-layout-strict-release-failure'),
      ),
      findsOneWidget,
    );
    expect(find.text('legacy builder should not render'), findsNothing);
  });

  testWidgets('strict release validation blocks layout failure fallback', (
    tester,
  ) async {
    final controller = ReaderLayoutRendererController(
      streamController: ReaderLayoutStreamController(
        engine: const _ThrowingLayoutEngine(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderLayoutRendererPreviewSurface(
            request: _request('boom'),
            controller: controller,
            options: const ReaderLayoutDevOptions(
              mode: ReaderLayoutEngineMode.experimental,
              diagnosticsEnabled: true,
              strictReleaseValidation: true,
            ),
            legacyBuilder: (context, state) {
              return const Text('legacy builder should not render');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('reason=layout_stream_failed'), findsOneWidget);
    expect(find.text('legacy builder should not render'), findsNothing);
  });
}

ReaderLayoutRequest _request(String text) {
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
  contentWidth: 320,
  contentHeight: 480,
  contentRectLeft: 0,
  contentRectTop: 0,
  pagePaddingTop: 0,
  pagePaddingRight: 0,
  pagePaddingBottom: 0,
  pagePaddingLeft: 0,
  pinnedHeaderHeight: 0,
  fontSize: 16,
  lineHeight: 1.4,
  paragraphSpacing: 8,
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
