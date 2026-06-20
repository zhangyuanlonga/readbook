import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_engine.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_request.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_stream_controller.dart';
import 'package:shuxiang_reading_next/features/reader/domain/entities/reader_layout_models.dart';

void main() {
  group('ReaderLayoutStreamController', () {
    test('emits loading, current, nearby, and complete events', () async {
      final controller = ReaderLayoutStreamController();

      final events =
          await controller
              .layout(_request(text: '正文内容' * 80), nearbyPageRadius: 1)
              .toList();

      expect(events.first.type, ReaderLayoutStreamEventType.loading);
      expect(
        events.map((event) => event.type),
        containsAllInOrder(<ReaderLayoutStreamEventType>[
          ReaderLayoutStreamEventType.currentPageReady,
          ReaderLayoutStreamEventType.nearbyPageReady,
          ReaderLayoutStreamEventType.complete,
        ]),
      );
      expect(events.last.completed, isTrue);
      expect(events.last.pages.length, greaterThan(1));
    });

    test('cancels the previous generation when a new layout starts', () async {
      final engine = _WaitingLayoutEngine();
      final controller = ReaderLayoutStreamController(engine: engine);

      final first = controller.layout(_request(text: 'first')).toList();
      final second = controller.layout(_request(text: 'second')).toList();
      engine.release();

      final firstEvents = await first;
      final secondEvents = await second;

      expect(firstEvents.last.type, ReaderLayoutStreamEventType.cancelled);
      expect(secondEvents.last.type, ReaderLayoutStreamEventType.complete);
      expect(firstEvents.last.generation, 1);
      expect(secondEvents.last.generation, 2);
    });

    test('emits failed events when the engine throws', () async {
      final controller = ReaderLayoutStreamController(
        engine: const _ThrowingLayoutEngine(),
      );

      final events = await controller.layout(_request(text: 'boom')).toList();

      expect(events.last.type, ReaderLayoutStreamEventType.failed);
      expect(events.last.errorMessage, contains('layout failed'));
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

ReaderLayoutPage _singlePage(ReaderLayoutRequest request) {
  return ReaderLayoutPage(
    chapterId: request.chapterId,
    chapterIndex: request.chapterIndex,
    pageIndex: 0,
    startOffset: 0,
    endOffset: 1,
    contentWidth: request.spec.contentWidth,
    contentHeight: request.spec.contentHeight,
    layoutSignature: request.layoutSignature,
    lines: const <ReaderLayoutLine>[
      ReaderLayoutLine(
        lineIndex: 0,
        paragraphIndex: 0,
        text: 'x',
        chapterOffset: 0,
        pageOffset: 0,
        lineTop: 0,
        lineBase: 10,
        lineBottom: 12,
        columns: <ReaderLayoutColumn>[
          ReaderLayoutColumn(
            columnIndex: 0,
            kind: ReaderLayoutColumnKind.text,
            startOffset: 0,
            endOffset: 1,
            rect: ReaderLayoutRect(left: 0, top: 0, right: 10, bottom: 12),
            text: 'x',
          ),
        ],
      ),
    ],
  );
}

class _WaitingLayoutEngine extends ReaderLayoutEngine {
  final Completer<void> _release = Completer<void>();

  void release() {
    if (!_release.isCompleted) {
      _release.complete();
    }
  }

  @override
  Future<ReaderLayoutResult?> layout(
    ReaderLayoutRequest request, {
    ReaderLayoutCancellationToken? cancellationToken,
    void Function(ReaderLayoutPage page)? onPageReady,
  }) async {
    await _release.future;
    if (cancellationToken?.isCancelled ?? false) {
      return null;
    }
    final page = _singlePage(request);
    onPageReady?.call(page);
    return ReaderLayoutResult(
      request: request,
      pages: <ReaderLayoutPage>[page],
      elapsedMicros: 1,
    );
  }
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
