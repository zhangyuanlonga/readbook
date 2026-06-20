import 'reader_layout_request.dart';
import 'reader_mixed_content_payload.dart';

enum ReaderMixedContentParityStatus { supported, partial, missing }

class ReaderMixedContentParityItem {
  const ReaderMixedContentParityItem({
    required this.key,
    required this.status,
    required this.reason,
  });

  final String key;
  final ReaderMixedContentParityStatus status;
  final String reason;
}

class ReaderMixedContentParityReport {
  const ReaderMixedContentParityReport({required this.items});

  final List<ReaderMixedContentParityItem> items;

  bool get hasMissing => items.any(
    (item) => item.status == ReaderMixedContentParityStatus.missing,
  );

  bool get hasPartial => items.any(
    (item) => item.status == ReaderMixedContentParityStatus.partial,
  );

  ReaderMixedContentParityStatus? statusFor(String key) {
    for (final item in items) {
      if (item.key == key) {
        return item.status;
      }
    }
    return null;
  }
}

class ReaderMixedContentParityPolicy {
  const ReaderMixedContentParityPolicy();

  ReaderMixedContentParityReport evaluate(List<ReaderLayoutBlock> blocks) {
    final items = <ReaderMixedContentParityItem>[
      _evaluateTextBlocks(blocks),
      _evaluateTitleBlocks(blocks),
      _evaluateImageBlocks(blocks),
      _evaluateSemanticPayload(
        blocks: blocks,
        key: 'caption',
        kind: ReaderLayoutBlockKind.caption,
        payloadKind: ReaderMixedContentPayloadKind.caption,
      ),
      _evaluateSemanticPayload(
        blocks: blocks,
        key: 'footnote',
        kind: ReaderLayoutBlockKind.footnote,
        payloadKind: ReaderMixedContentPayloadKind.footnote,
      ),
      _evaluateSemanticPayload(
        blocks: blocks,
        key: 'link',
        kind: ReaderLayoutBlockKind.link,
        payloadKind: ReaderMixedContentPayloadKind.link,
      ),
    ];
    return ReaderMixedContentParityReport(
      items: List<ReaderMixedContentParityItem>.unmodifiable(items),
    );
  }

  ReaderMixedContentParityItem _evaluateTextBlocks(
    List<ReaderLayoutBlock> blocks,
  ) {
    final hasText = blocks.any(
      (block) => block.isText && block.text.isNotEmpty,
    );
    return ReaderMixedContentParityItem(
      key: 'text',
      status:
          hasText
              ? ReaderMixedContentParityStatus.supported
              : ReaderMixedContentParityStatus.missing,
      reason: hasText ? 'text_blocks_present' : 'no_readable_text_block',
    );
  }

  ReaderMixedContentParityItem _evaluateTitleBlocks(
    List<ReaderLayoutBlock> blocks,
  ) {
    final hasTitle = blocks.any((block) => block.isTitle);
    return ReaderMixedContentParityItem(
      key: 'title',
      status:
          hasTitle
              ? ReaderMixedContentParityStatus.supported
              : ReaderMixedContentParityStatus.partial,
      reason: hasTitle ? 'title_block_present' : 'title_may_fallback_to_chrome',
    );
  }

  ReaderMixedContentParityItem _evaluateImageBlocks(
    List<ReaderLayoutBlock> blocks,
  ) {
    final imageBlocks = blocks.where((block) => block.isImage).toList();
    if (imageBlocks.isEmpty) {
      return const ReaderMixedContentParityItem(
        key: 'image',
        status: ReaderMixedContentParityStatus.partial,
        reason: 'no_image_block_in_sample',
      );
    }
    final allHavePayload = imageBlocks.every(
      (block) =>
          ReaderMixedContentPayloads.read(block.columnPayload)?.kind ==
          ReaderMixedContentPayloadKind.image,
    );
    final allHaveSize = imageBlocks.every((block) => block.estimatedHeight > 0);
    return ReaderMixedContentParityItem(
      key: 'image',
      status:
          allHavePayload && allHaveSize
              ? ReaderMixedContentParityStatus.supported
              : ReaderMixedContentParityStatus.missing,
      reason:
          allHavePayload && allHaveSize
              ? 'image_payload_and_placeholder_size_present'
              : 'image_payload_or_placeholder_size_missing',
    );
  }

  ReaderMixedContentParityItem _evaluateSemanticPayload({
    required List<ReaderLayoutBlock> blocks,
    required String key,
    required ReaderLayoutBlockKind kind,
    required ReaderMixedContentPayloadKind payloadKind,
  }) {
    final matching = blocks.where((block) => block.kind == kind).toList();
    if (matching.isEmpty) {
      return ReaderMixedContentParityItem(
        key: key,
        status: ReaderMixedContentParityStatus.partial,
        reason: 'no_${key}_block_in_sample',
      );
    }
    final allHavePayload = matching.every(
      (block) =>
          ReaderMixedContentPayloads.read(block.columnPayload)?.kind ==
          payloadKind,
    );
    return ReaderMixedContentParityItem(
      key: key,
      status:
          allHavePayload
              ? ReaderMixedContentParityStatus.supported
              : ReaderMixedContentParityStatus.missing,
      reason:
          allHavePayload ? '${key}_payload_present' : '${key}_payload_missing',
    );
  }
}
