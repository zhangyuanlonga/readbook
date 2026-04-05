import '../../../domain/entities/reader_document.dart';

enum ReaderRenderTextKind {
  paragraph,
  title,
  listItem,
  quote,
  caption,
  footnote,
}

abstract class ReaderRenderBlockItem {
  const ReaderRenderBlockItem({this.paragraphIndex});

  final int? paragraphIndex;
}

class ReaderRenderTextItem extends ReaderRenderBlockItem {
  const ReaderRenderTextItem({
    required this.text,
    required this.kind,
    required int paragraphIndex,
    this.level = 1,
  }) : super(paragraphIndex: paragraphIndex);

  final String text;
  final ReaderRenderTextKind kind;
  final int level;
}

class ReaderRenderImageItem extends ReaderRenderBlockItem {
  const ReaderRenderImageItem({required this.imageUrl})
    : super(paragraphIndex: null);

  final String imageUrl;
}

List<ReaderRenderBlockItem> buildReaderRenderBlockItems(
  ReaderDocument document,
) {
  final items = <ReaderRenderBlockItem>[];
  var paragraphIndex = 0;

  for (final block in document.blocks) {
    if (block is ReaderTitleBlock) {
      items.add(
        ReaderRenderTextItem(
          text: block.text,
          kind: ReaderRenderTextKind.title,
          level: block.level,
          paragraphIndex: paragraphIndex,
        ),
      );
      paragraphIndex += 1;
      continue;
    }
    if (block is ReaderTextBlock) {
      items.add(
        ReaderRenderTextItem(
          text: block.text,
          kind: ReaderRenderTextKind.paragraph,
          paragraphIndex: paragraphIndex,
        ),
      );
      paragraphIndex += 1;
      continue;
    }
    if (block is ReaderListItemBlock) {
      items.add(
        ReaderRenderTextItem(
          text: block.text,
          kind: ReaderRenderTextKind.listItem,
          paragraphIndex: paragraphIndex,
        ),
      );
      paragraphIndex += 1;
      continue;
    }
    if (block is ReaderQuoteBlock) {
      items.add(
        ReaderRenderTextItem(
          text: block.text,
          kind: ReaderRenderTextKind.quote,
          paragraphIndex: paragraphIndex,
        ),
      );
      paragraphIndex += 1;
      continue;
    }
    if (block is ReaderCaptionBlock) {
      items.add(
        ReaderRenderTextItem(
          text: block.text,
          kind: ReaderRenderTextKind.caption,
          paragraphIndex: paragraphIndex,
        ),
      );
      paragraphIndex += 1;
      continue;
    }
    if (block is ReaderFootnoteBlock) {
      items.add(
        ReaderRenderTextItem(
          text: block.text,
          kind: ReaderRenderTextKind.footnote,
          paragraphIndex: paragraphIndex,
        ),
      );
      paragraphIndex += 1;
      continue;
    }
    if (block is ReaderImageBlock) {
      items.add(ReaderRenderImageItem(imageUrl: block.imageUrl));
    }
  }

  return List<ReaderRenderBlockItem>.unmodifiable(items);
}
