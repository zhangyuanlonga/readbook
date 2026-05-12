import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_document_render_model.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_engine.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_models.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_spec.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_streaming_pagination_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const spec = ReaderPaginationSpec(
    contentWidth: 320,
    contentHeight: 260,
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
    letterSpacing: 0,
    textFullJustifyEnabled: false,
    bodyTextItalicEnabled: false,
    fontWeightLevel: ReaderFontWeightLevel.regular,
    fontWeightValue: null,
    fontSource: ReaderFontSource.system,
    systemFontPreset: ReaderSystemFontPreset.defaultSans,
    fontFamilyKey: null,
  );

  group('ReaderStreamingPaginationController', () {
    const controller = ReaderStreamingPaginationController();

    test('emits current page before complete for long text', () async {
      final events =
          await controller
              .paginateText(
                ReaderPaginationRequest(
                  paragraphs: <String>['长文本 ' * 260],
                  spec: spec,
                  paragraphStyle: const TextStyle(fontSize: 18, height: 1.72),
                ),
                targetRatio: 0,
              )
              .toList();

      expect(events, isNotEmpty);
      expect(
        events.first.type,
        ReaderStreamingPaginationEventType.currentPageReady,
      );
      expect(events.last.type, ReaderStreamingPaginationEventType.complete);
      expect(
        events.first.pages.length,
        lessThanOrEqualTo(events.last.pages.length),
      );
    });

    test('paginates mixed text and image blocks', () async {
      final document = ReaderDocument(
        blocks: <ReaderBlock>[
          const ReaderTextBlock(text: '第一段文字 '),
          const ReaderImageBlock(imageUrl: 'file:///tmp/image.jpg'),
          ReaderTextBlock(text: '第二段文字 ' * 80),
        ],
      );
      final events =
          await controller
              .paginateBlocks(
                ReaderBlockPaginationRequest(
                  renderItems: buildReaderRenderBlockItems(document),
                  paragraphs: document.paragraphs,
                  spec: spec,
                  paragraphStyle: const TextStyle(fontSize: 18, height: 1.72),
                ),
              )
              .toList();

      final pages = events.last.pages;
      expect(pages, isNotEmpty);
      expect(
        pages
            .expand((page) => page)
            .any((block) => block.kind == ReaderPagedBlockKind.image),
        isTrue,
      );
    });
  });
}
