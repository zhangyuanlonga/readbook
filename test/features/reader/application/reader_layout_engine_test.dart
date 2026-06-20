import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_engine.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_request.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_mixed_content_payload.dart';
import 'package:shuxiang_reading_next/features/reader/domain/entities/reader_layout_models.dart';

void main() {
  group('ReaderLayoutEngine', () {
    const engine = ReaderLayoutEngine();

    test('lays out title and paragraph blocks into pages', () async {
      final readyPages = <ReaderLayoutPage>[];
      final result = await engine.layout(
        ReaderLayoutRequest(
          chapterId: 'chapter-1',
          chapterIndex: 0,
          blocks: const <ReaderLayoutBlock>[
            ReaderLayoutBlock.title(text: '标题', sourceIndex: 0),
            ReaderLayoutBlock.paragraph(
              text: 'abcdefghijklmnopqrstuvwxyz0123456789',
              sourceIndex: 1,
            ),
          ],
          spec: _spec,
          documentFingerprint: 'doc-a',
        ),
        onPageReady: readyPages.add,
      );

      expect(result, isNotNull);
      expect(result!.pages.length, greaterThan(1));
      expect(readyPages, hasLength(result.pages.length));
      expect(result.pages.first.lines.first.isTitle, isTrue);
      final bodyLine = result.pages
          .expand((page) => page.lines)
          .firstWhere((line) => !line.isTitle);
      expect(bodyLine.columns.single.rect.left, greaterThan(0));
      expect(result.layoutSignature, contains('reader_layout_v2_alpha_1'));
    });

    test('lays out image blocks with image payload', () async {
      final result = await engine.layout(
        ReaderLayoutRequest(
          chapterId: 'chapter-1',
          chapterIndex: 0,
          blocks: const <ReaderLayoutBlock>[
            ReaderLayoutBlock.image(
              imageUrl: 'https://example.com/a.png',
              estimatedHeight: 80,
            ),
          ],
          spec: _spec,
          documentFingerprint: 'doc-a',
        ),
      );

      final line = result!.pages.single.lines.single;
      expect(line.isImage, isTrue);
      expect(line.columns.single.kind, ReaderLayoutColumnKind.image);
      expect(
        line.columns.single.payload['imageUrl'],
        'https://example.com/a.png',
      );
      expect(line.lineBottom, 80);
    });

    test(
      'writes mixed content payload for image link footnote and caption',
      () async {
        final result = await engine.layout(
          ReaderLayoutRequest(
            chapterId: 'chapter-1',
            chapterIndex: 0,
            blocks: const <ReaderLayoutBlock>[
              ReaderLayoutBlock.link(
                text: '官网',
                url: 'https://example.com',
                sourceIndex: 0,
              ),
              ReaderLayoutBlock.footnote(text: '脚注内容', sourceIndex: 1),
              ReaderLayoutBlock.caption(text: '图片说明', sourceIndex: 2),
              ReaderLayoutBlock.image(
                imageUrl: 'https://example.com/a.png',
                estimatedHeight: 24,
                sourceIndex: 3,
              ),
            ],
            spec: _spec,
            documentFingerprint: 'doc-mixed',
          ),
        );

        final columns = result!.pages.expand(
          (page) => page.lines.map((line) => line.columns.single),
        );
        final payloads = columns
            .map((column) => ReaderMixedContentPayloads.read(column.payload))
            .whereType<ReaderMixedContentPayload>()
            .toList(growable: false);

        expect(payloads.map((payload) => payload.kind), <Object>[
          ReaderMixedContentPayloadKind.link,
          ReaderMixedContentPayloadKind.footnote,
          ReaderMixedContentPayloadKind.caption,
          ReaderMixedContentPayloadKind.image,
        ]);
        expect(payloads.first.url, 'https://example.com');
        expect(payloads.last.url, 'https://example.com/a.png');
      },
    );

    test('returns null when cancelled before layout', () async {
      final token = ReaderLayoutCancellationToken()..cancel();

      final result = await engine.layout(
        ReaderLayoutRequest.fromParagraphs(
          chapterId: 'chapter-1',
          chapterIndex: 0,
          paragraphs: const <String>['abc'],
          spec: _spec,
          documentFingerprint: 'doc-a',
        ),
        cancellationToken: token,
      );

      expect(result, isNull);
    });
  });
}

const _spec = ReaderLayoutSpec(
  contentWidth: 90,
  contentHeight: 50,
  contentRectLeft: 0,
  contentRectTop: 0,
  pagePaddingTop: 0,
  pagePaddingRight: 0,
  pagePaddingBottom: 0,
  pagePaddingLeft: 0,
  pinnedHeaderHeight: 0,
  fontSize: 18,
  lineHeight: 1,
  paragraphSpacing: 4,
  paragraphIndent: 2,
  letterSpacing: 0,
  textFullJustifyEnabled: false,
  bodyTextItalicEnabled: false,
  fontWeightLevel: ReaderFontWeightLevel.regular,
  fontWeightValue: null,
  fontSource: ReaderFontSource.system,
  systemFontPreset: ReaderSystemFontPreset.defaultSans,
  fontFamilyKey: null,
);
