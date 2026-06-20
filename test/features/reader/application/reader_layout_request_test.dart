import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_request.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_mixed_content_payload.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_spec.dart';

void main() {
  group('ReaderLayoutRequest and spec', () {
    test('maps pagination spec into layout spec', () {
      final spec = ReaderLayoutSpec.fromPaginationSpec(
        _paginationSpec,
        useZhLayout: true,
        imageLayoutPolicy: 'estimate',
      );

      expect(spec.contentWidth, _paginationSpec.contentWidth);
      expect(spec.fontSize, _paginationSpec.fontSize);
      expect(spec.useZhLayout, isTrue);
      expect(spec.imageLayoutPolicy, 'estimate');
    });

    test('builds a stable signature from content and layout inputs', () {
      final spec = ReaderLayoutSpec.fromPaginationSpec(_paginationSpec);
      final baseline = spec.buildSignature(
        chapterId: 'chapter-1',
        documentFingerprint: 'doc-a',
        parserVersion: 'parser-a',
      );
      final changedContent = spec.buildSignature(
        chapterId: 'chapter-1',
        documentFingerprint: 'doc-b',
        parserVersion: 'parser-a',
      );
      final zhSpec = ReaderLayoutSpec.fromPaginationSpec(
        _paginationSpec,
        useZhLayout: true,
      );

      expect(baseline, isNot(changedContent));
      expect(
        baseline,
        isNot(
          zhSpec.buildSignature(
            chapterId: 'chapter-1',
            documentFingerprint: 'doc-a',
            parserVersion: 'parser-a',
          ),
        ),
      );
    });

    test('changes signature when user-visible layout settings change', () {
      final baseline = ReaderLayoutSpec.fromPaginationSpec(
        _paginationSpec,
      ).buildSignature(
        chapterId: 'chapter-1',
        documentFingerprint: 'doc-a',
        parserVersion: 'parser-a',
      );

      String signatureFor(ReaderPaginationSpec spec) {
        return ReaderLayoutSpec.fromPaginationSpec(spec).buildSignature(
          chapterId: 'chapter-1',
          documentFingerprint: 'doc-a',
          parserVersion: 'parser-a',
        );
      }

      expect(baseline, isNot(signatureFor(_specVariant(fontSize: 20))));
      expect(baseline, isNot(signatureFor(_specVariant(lineHeight: 1.9))));
      expect(baseline, isNot(signatureFor(_specVariant(pagePaddingLeft: 24))));
      expect(
        baseline,
        isNot(
          signatureFor(
            _specVariant(
              fontSource: ReaderFontSource.builtin,
              fontFamilyKey: 'serif',
            ),
          ),
        ),
      );
    });

    test('builds paragraph requests without UI-only objects', () {
      final request = ReaderLayoutRequest.fromParagraphs(
        chapterId: 'chapter-1',
        chapterIndex: 0,
        paragraphs: const <String>['abc', 'def'],
        spec: ReaderLayoutSpec.fromPaginationSpec(_paginationSpec),
        documentFingerprint: 'doc-a',
        paragraphSeparatorLength: 2,
      );

      expect(request.blocks, hasLength(2));
      expect(request.blocks.first.text, 'abc');
      expect(request.layoutSignature, contains('reader_layout_v2_alpha_1'));
      expect(request.totalContentLength, 10);
    });

    test('builds document requests with mixed content payload blocks', () {
      final request = ReaderLayoutRequest.fromDocument(
        chapterId: 'chapter-1',
        chapterIndex: 0,
        document: ReaderDocument(
          blocks: const <ReaderBlock>[
            ReaderTitleBlock(text: '标题'),
            ReaderCaptionBlock(text: '图片说明'),
            ReaderFootnoteBlock(text: '脚注'),
            ReaderImageBlock(imageUrl: 'https://example.com/p.png'),
          ],
        ),
        spec: ReaderLayoutSpec.fromPaginationSpec(_paginationSpec),
        documentFingerprint: 'doc-mixed',
      );

      expect(request.blocks.map((block) => block.kind), <Object>[
        ReaderLayoutBlockKind.title,
        ReaderLayoutBlockKind.caption,
        ReaderLayoutBlockKind.footnote,
        ReaderLayoutBlockKind.image,
      ]);
      expect(
        ReaderMixedContentPayloads.read(request.blocks[1].columnPayload)?.kind,
        ReaderMixedContentPayloadKind.caption,
      );
      expect(
        ReaderMixedContentPayloads.read(request.blocks[2].columnPayload)?.kind,
        ReaderMixedContentPayloadKind.footnote,
      );
      expect(
        ReaderMixedContentPayloads.read(request.blocks[3].columnPayload)?.url,
        'https://example.com/p.png',
      );
    });

    test(
      'keeps document layout offsets aligned with compatibility paragraphs',
      () {
        const imageUrl = 'https://example.com/p.png';
        final document = ReaderDocument(
          blocks: const <ReaderBlock>[
            ReaderTextBlock(text: '正文'),
            ReaderImageBlock(imageUrl: imageUrl),
            ReaderFootnoteBlock(text: '脚注'),
          ],
        );
        final request = ReaderLayoutRequest.fromDocument(
          chapterId: 'chapter-1',
          chapterIndex: 0,
          document: document,
          spec: ReaderLayoutSpec.fromPaginationSpec(_paginationSpec),
          documentFingerprint: 'doc-offset',
        );

        expect(
          request.blocks.map((block) => block.contentLength),
          document.paragraphs.map((paragraph) => paragraph.length),
        );
        expect(request.blocks[2].text, '注: 脚注');
      },
    );
  });
}

const _paginationSpec = ReaderPaginationSpec(
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

ReaderPaginationSpec _specVariant({
  double? fontSize,
  double? lineHeight,
  double? pagePaddingLeft,
  ReaderFontSource? fontSource,
  String? fontFamilyKey,
}) {
  return ReaderPaginationSpec(
    contentWidth: _paginationSpec.contentWidth,
    contentHeight: _paginationSpec.contentHeight,
    contentRectLeft: _paginationSpec.contentRectLeft,
    contentRectTop: _paginationSpec.contentRectTop,
    pagePaddingTop: _paginationSpec.pagePaddingTop,
    pagePaddingRight: _paginationSpec.pagePaddingRight,
    pagePaddingBottom: _paginationSpec.pagePaddingBottom,
    pagePaddingLeft: pagePaddingLeft ?? _paginationSpec.pagePaddingLeft,
    pinnedHeaderHeight: _paginationSpec.pinnedHeaderHeight,
    paragraphSpacing: _paginationSpec.paragraphSpacing,
    paragraphIndent: _paginationSpec.paragraphIndent,
    lineHeight: lineHeight ?? _paginationSpec.lineHeight,
    fontSize: fontSize ?? _paginationSpec.fontSize,
    letterSpacing: _paginationSpec.letterSpacing,
    textFullJustifyEnabled: _paginationSpec.textFullJustifyEnabled,
    bodyTextItalicEnabled: _paginationSpec.bodyTextItalicEnabled,
    fontWeightLevel: _paginationSpec.fontWeightLevel,
    fontWeightValue: _paginationSpec.fontWeightValue,
    fontSource: fontSource ?? _paginationSpec.fontSource,
    systemFontPreset: _paginationSpec.systemFontPreset,
    fontFamilyKey: fontFamilyKey ?? _paginationSpec.fontFamilyKey,
    imagePlaceholderAspectRatio: _paginationSpec.imagePlaceholderAspectRatio,
  );
}
