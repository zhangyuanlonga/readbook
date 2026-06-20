import '../../../domain/entities/reader_settings.dart';
import '../../../domain/entities/reader_document.dart';
import 'reader_mixed_content_payload.dart';
import 'reader_pagination_spec.dart';

enum ReaderLayoutBlockKind { paragraph, title, image, link, footnote, caption }

class ReaderLayoutBlock {
  const ReaderLayoutBlock._({
    required this.kind,
    required this.text,
    this.sourceIndex,
    this.imageUrl,
    this.linkUrl,
    this.estimatedHeight = 0,
    this.contentLengthOverride,
    this.payload = const <String, Object?>{},
  }) : assert(estimatedHeight >= 0),
       assert(contentLengthOverride == null || contentLengthOverride >= 0);

  const ReaderLayoutBlock.paragraph({
    required String text,
    int? sourceIndex,
    Map<String, Object?> payload = const <String, Object?>{},
  }) : this._(
         kind: ReaderLayoutBlockKind.paragraph,
         text: text,
         sourceIndex: sourceIndex,
         payload: payload,
       );

  const ReaderLayoutBlock.title({
    required String text,
    int? sourceIndex,
    Map<String, Object?> payload = const <String, Object?>{},
  }) : this._(
         kind: ReaderLayoutBlockKind.title,
         text: text,
         sourceIndex: sourceIndex,
         payload: payload,
       );

  const ReaderLayoutBlock.link({
    required String text,
    required String url,
    int? sourceIndex,
    Map<String, Object?> payload = const <String, Object?>{},
  }) : this._(
         kind: ReaderLayoutBlockKind.link,
         text: text,
         linkUrl: url,
         sourceIndex: sourceIndex,
         payload: payload,
       );

  const ReaderLayoutBlock.footnote({
    required String text,
    int? sourceIndex,
    Map<String, Object?> payload = const <String, Object?>{},
  }) : this._(
         kind: ReaderLayoutBlockKind.footnote,
         text: text,
         sourceIndex: sourceIndex,
         payload: payload,
       );

  const ReaderLayoutBlock.caption({
    required String text,
    int? sourceIndex,
    Map<String, Object?> payload = const <String, Object?>{},
  }) : this._(
         kind: ReaderLayoutBlockKind.caption,
         text: text,
         sourceIndex: sourceIndex,
         payload: payload,
       );

  const ReaderLayoutBlock.image({
    required String imageUrl,
    double estimatedHeight = 180,
    int contentLength = 1,
    int? sourceIndex,
    Map<String, Object?> payload = const <String, Object?>{},
  }) : this._(
         kind: ReaderLayoutBlockKind.image,
         text: '',
         imageUrl: imageUrl,
         estimatedHeight: estimatedHeight,
         contentLengthOverride: contentLength,
         sourceIndex: sourceIndex,
         payload: payload,
       );

  final ReaderLayoutBlockKind kind;
  final String text;
  final int? sourceIndex;
  final String? imageUrl;
  final String? linkUrl;
  final double estimatedHeight;
  final int? contentLengthOverride;
  final Map<String, Object?> payload;

  bool get isText => kind != ReaderLayoutBlockKind.image;
  bool get isTitle => kind == ReaderLayoutBlockKind.title;
  bool get isImage => kind == ReaderLayoutBlockKind.image;
  bool get isLink => kind == ReaderLayoutBlockKind.link;
  bool get isFootnote => kind == ReaderLayoutBlockKind.footnote;
  bool get isCaption => kind == ReaderLayoutBlockKind.caption;
  int get contentLength => contentLengthOverride ?? (isImage ? 1 : text.length);

  Map<String, Object?> get semanticPayload {
    return switch (kind) {
      ReaderLayoutBlockKind.image =>
        imageUrl == null
            ? const <String, Object?>{}
            : ReaderMixedContentPayloads.image(
              imageUrl: imageUrl!,
              sourceIndex: sourceIndex,
            ),
      ReaderLayoutBlockKind.link =>
        linkUrl == null
            ? const <String, Object?>{}
            : ReaderMixedContentPayloads.link(
              text: text,
              url: linkUrl!,
              sourceIndex: sourceIndex,
            ),
      ReaderLayoutBlockKind.footnote => ReaderMixedContentPayloads.footnote(
        text: text,
        sourceIndex: sourceIndex,
      ),
      ReaderLayoutBlockKind.caption => ReaderMixedContentPayloads.caption(
        text: text,
        sourceIndex: sourceIndex,
      ),
      ReaderLayoutBlockKind.paragraph ||
      ReaderLayoutBlockKind.title => const <String, Object?>{},
    };
  }

  Map<String, Object?> get columnPayload {
    return ReaderMixedContentPayloads.merge(payload, semanticPayload);
  }
}

class ReaderLayoutSpec {
  const ReaderLayoutSpec({
    required this.contentWidth,
    required this.contentHeight,
    required this.contentRectLeft,
    required this.contentRectTop,
    required this.pagePaddingTop,
    required this.pagePaddingRight,
    required this.pagePaddingBottom,
    required this.pagePaddingLeft,
    required this.pinnedHeaderHeight,
    required this.fontSize,
    required this.lineHeight,
    required this.paragraphSpacing,
    required this.paragraphIndent,
    required this.letterSpacing,
    required this.textFullJustifyEnabled,
    required this.bodyTextItalicEnabled,
    required this.fontWeightLevel,
    required this.fontWeightValue,
    required this.fontSource,
    required this.systemFontPreset,
    required this.fontFamilyKey,
    this.imagePlaceholderAspectRatio = 3 / 4,
    this.useZhLayout = false,
    this.imageLayoutPolicy = 'placeholder',
    this.titleLayoutPolicy = 'plain',
  });

  factory ReaderLayoutSpec.fromPaginationSpec(
    ReaderPaginationSpec spec, {
    bool useZhLayout = false,
    String imageLayoutPolicy = 'placeholder',
    String titleLayoutPolicy = 'plain',
  }) {
    return ReaderLayoutSpec(
      contentWidth: spec.contentWidth,
      contentHeight: spec.contentHeight,
      contentRectLeft: spec.contentRectLeft,
      contentRectTop: spec.contentRectTop,
      pagePaddingTop: spec.pagePaddingTop,
      pagePaddingRight: spec.pagePaddingRight,
      pagePaddingBottom: spec.pagePaddingBottom,
      pagePaddingLeft: spec.pagePaddingLeft,
      pinnedHeaderHeight: spec.pinnedHeaderHeight,
      fontSize: spec.fontSize,
      lineHeight: spec.lineHeight,
      paragraphSpacing: spec.paragraphSpacing,
      paragraphIndent: spec.paragraphIndent,
      letterSpacing: spec.letterSpacing,
      textFullJustifyEnabled: spec.textFullJustifyEnabled,
      bodyTextItalicEnabled: spec.bodyTextItalicEnabled,
      fontWeightLevel: spec.fontWeightLevel,
      fontWeightValue: spec.fontWeightValue,
      fontSource: spec.fontSource,
      systemFontPreset: spec.systemFontPreset,
      fontFamilyKey: spec.fontFamilyKey,
      imagePlaceholderAspectRatio: spec.imagePlaceholderAspectRatio,
      useZhLayout: useZhLayout,
      imageLayoutPolicy: imageLayoutPolicy,
      titleLayoutPolicy: titleLayoutPolicy,
    );
  }

  final double contentWidth;
  final double contentHeight;
  final double contentRectLeft;
  final double contentRectTop;
  final double pagePaddingTop;
  final double pagePaddingRight;
  final double pagePaddingBottom;
  final double pagePaddingLeft;
  final double pinnedHeaderHeight;
  final double fontSize;
  final double lineHeight;
  final double paragraphSpacing;
  final double paragraphIndent;
  final double letterSpacing;
  final bool textFullJustifyEnabled;
  final bool bodyTextItalicEnabled;
  final ReaderFontWeightLevel fontWeightLevel;
  final int? fontWeightValue;
  final ReaderFontSource fontSource;
  final ReaderSystemFontPreset systemFontPreset;
  final String? fontFamilyKey;
  final double imagePlaceholderAspectRatio;
  final bool useZhLayout;
  final String imageLayoutPolicy;
  final String titleLayoutPolicy;

  String buildSignature({
    required String chapterId,
    required String documentFingerprint,
    required String parserVersion,
  }) {
    return <String>[
      'reader_layout_v2_alpha_1',
      chapterId,
      documentFingerprint,
      parserVersion,
      contentWidth.toStringAsFixed(1),
      contentHeight.toStringAsFixed(1),
      contentRectLeft.toStringAsFixed(1),
      contentRectTop.toStringAsFixed(1),
      pinnedHeaderHeight.toStringAsFixed(1),
      pagePaddingTop.toStringAsFixed(1),
      pagePaddingRight.toStringAsFixed(1),
      pagePaddingBottom.toStringAsFixed(1),
      pagePaddingLeft.toStringAsFixed(1),
      fontSize.toStringAsFixed(1),
      lineHeight.toStringAsFixed(2),
      paragraphSpacing.toStringAsFixed(1),
      paragraphIndent.toStringAsFixed(1),
      letterSpacing.toStringAsFixed(3),
      textFullJustifyEnabled ? 'justify' : 'start',
      bodyTextItalicEnabled ? 'italic' : 'normal',
      fontWeightLevel.name,
      fontWeightValue?.toString() ?? '',
      fontSource.name,
      systemFontPreset.name,
      fontFamilyKey ?? '',
      imagePlaceholderAspectRatio.toStringAsFixed(3),
      useZhLayout ? 'zh' : 'plain',
      imageLayoutPolicy,
      titleLayoutPolicy,
    ].join('|');
  }
}

class ReaderLayoutRequest {
  const ReaderLayoutRequest({
    required this.chapterId,
    required this.chapterIndex,
    required this.blocks,
    required this.spec,
    required this.documentFingerprint,
    this.parserVersion = 'reader_parser_v1',
    this.paragraphSeparatorLength = 2,
  }) : assert(chapterId.length > 0),
       assert(chapterIndex >= 0),
       assert(paragraphSeparatorLength >= 0);

  factory ReaderLayoutRequest.fromParagraphs({
    required String chapterId,
    required int chapterIndex,
    required List<String> paragraphs,
    required ReaderLayoutSpec spec,
    required String documentFingerprint,
    String parserVersion = 'reader_parser_v1',
    int paragraphSeparatorLength = 2,
  }) {
    return ReaderLayoutRequest(
      chapterId: chapterId,
      chapterIndex: chapterIndex,
      blocks: List<ReaderLayoutBlock>.generate(
        paragraphs.length,
        (index) => ReaderLayoutBlock.paragraph(
          text: paragraphs[index],
          sourceIndex: index,
        ),
        growable: false,
      ),
      spec: spec,
      documentFingerprint: documentFingerprint,
      parserVersion: parserVersion,
      paragraphSeparatorLength: paragraphSeparatorLength,
    );
  }

  factory ReaderLayoutRequest.fromDocument({
    required String chapterId,
    required int chapterIndex,
    required ReaderDocument document,
    required ReaderLayoutSpec spec,
    required String documentFingerprint,
    String parserVersion = 'reader_parser_v1',
    int paragraphSeparatorLength = 2,
  }) {
    return ReaderLayoutRequest(
      chapterId: chapterId,
      chapterIndex: chapterIndex,
      blocks: List<ReaderLayoutBlock>.generate(
        document.blocks.length,
        (index) => _blockFromDocument(document.blocks[index], index),
        growable: false,
      ),
      spec: spec,
      documentFingerprint: documentFingerprint,
      parserVersion: parserVersion,
      paragraphSeparatorLength: paragraphSeparatorLength,
    );
  }

  final String chapterId;
  final int chapterIndex;
  final List<ReaderLayoutBlock> blocks;
  final ReaderLayoutSpec spec;
  final String documentFingerprint;
  final String parserVersion;
  final int paragraphSeparatorLength;

  String get layoutSignature {
    return spec.buildSignature(
      chapterId: chapterId,
      documentFingerprint: documentFingerprint,
      parserVersion: parserVersion,
    );
  }

  int get totalContentLength {
    if (blocks.isEmpty) {
      return 0;
    }
    return blocks.fold<int>(
      0,
      (total, block) => total + block.contentLength + paragraphSeparatorLength,
    );
  }

  static ReaderLayoutBlock _blockFromDocument(ReaderBlock block, int index) {
    if (block is ReaderTitleBlock) {
      return ReaderLayoutBlock.title(text: block.text, sourceIndex: index);
    }
    if (block is ReaderListItemBlock) {
      return ReaderLayoutBlock.paragraph(
        text: '• ${block.text}',
        sourceIndex: index,
      );
    }
    if (block is ReaderQuoteBlock) {
      return ReaderLayoutBlock.paragraph(
        text: block.text,
        sourceIndex: index,
        payload: const <String, Object?>{'blockKind': 'quote'},
      );
    }
    if (block is ReaderCaptionBlock) {
      return ReaderLayoutBlock.caption(text: block.text, sourceIndex: index);
    }
    if (block is ReaderFootnoteBlock) {
      return ReaderLayoutBlock.footnote(
        text: '注: ${block.text}',
        sourceIndex: index,
      );
    }
    if (block is ReaderImageBlock) {
      return ReaderLayoutBlock.image(
        imageUrl: block.imageUrl,
        contentLength:
            ReaderDocument.inlineImageParagraph(block.imageUrl).length,
        sourceIndex: index,
      );
    }
    if (block is ReaderTextBlock) {
      return ReaderLayoutBlock.paragraph(text: block.text, sourceIndex: index);
    }
    return const ReaderLayoutBlock.paragraph(text: '');
  }
}

class ReaderLayoutCancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}
