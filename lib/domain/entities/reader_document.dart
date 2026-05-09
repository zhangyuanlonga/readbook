abstract class ReaderBlock {
  const ReaderBlock();

  String get type;

  Map<String, dynamic> toJson();

  factory ReaderBlock.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString().trim() ?? '';
    switch (type) {
      case ReaderTextBlock.typeName:
        return ReaderTextBlock(
          text: ReaderDocument.requiredString(json, 'text'),
        );
      case ReaderListItemBlock.typeName:
        return ReaderListItemBlock(
          text: ReaderDocument.requiredString(json, 'text'),
        );
      case ReaderQuoteBlock.typeName:
        return ReaderQuoteBlock(
          text: ReaderDocument.requiredString(json, 'text'),
        );
      case ReaderCaptionBlock.typeName:
        return ReaderCaptionBlock(
          text: ReaderDocument.requiredString(json, 'text'),
        );
      case ReaderFootnoteBlock.typeName:
        return ReaderFootnoteBlock(
          text: ReaderDocument.requiredString(json, 'text'),
        );
      case ReaderImageBlock.typeName:
        return ReaderImageBlock(
          imageUrl: ReaderDocument.requiredString(json, 'imageUrl'),
        );
      case ReaderTitleBlock.typeName:
        return ReaderTitleBlock(
          text: ReaderDocument.requiredString(json, 'text'),
          level: ReaderDocument.optionalInt(json['level']) ?? 1,
        );
    }
    throw FormatException('Unknown ReaderBlock type: $type');
  }
}

class ReaderTextBlock extends ReaderBlock {
  const ReaderTextBlock({required this.text});

  static const String typeName = 'text';

  final String text;

  @override
  String get type => typeName;

  @override
  Map<String, dynamic> toJson() {
    return {'type': type, 'text': text};
  }
}

class ReaderListItemBlock extends ReaderBlock {
  const ReaderListItemBlock({required this.text});

  static const String typeName = 'list_item';

  final String text;

  @override
  String get type => typeName;

  @override
  Map<String, dynamic> toJson() {
    return {'type': type, 'text': text};
  }
}

class ReaderQuoteBlock extends ReaderBlock {
  const ReaderQuoteBlock({required this.text});

  static const String typeName = 'quote';

  final String text;

  @override
  String get type => typeName;

  @override
  Map<String, dynamic> toJson() {
    return {'type': type, 'text': text};
  }
}

class ReaderCaptionBlock extends ReaderBlock {
  const ReaderCaptionBlock({required this.text});

  static const String typeName = 'caption';

  final String text;

  @override
  String get type => typeName;

  @override
  Map<String, dynamic> toJson() {
    return {'type': type, 'text': text};
  }
}

class ReaderFootnoteBlock extends ReaderBlock {
  const ReaderFootnoteBlock({required this.text});

  static const String typeName = 'footnote';

  final String text;

  @override
  String get type => typeName;

  @override
  Map<String, dynamic> toJson() {
    return {'type': type, 'text': text};
  }
}

class ReaderImageBlock extends ReaderBlock {
  const ReaderImageBlock({required this.imageUrl});

  static const String typeName = 'image';

  final String imageUrl;

  @override
  String get type => typeName;

  @override
  Map<String, dynamic> toJson() {
    return {'type': type, 'imageUrl': imageUrl};
  }
}

class ReaderTitleBlock extends ReaderBlock {
  const ReaderTitleBlock({required this.text, this.level = 1});

  static const String typeName = 'title';

  final String text;
  final int level;

  @override
  String get type => typeName;

  @override
  Map<String, dynamic> toJson() {
    return {'type': type, 'text': text, 'level': level};
  }
}

class ReaderDocument {
  ReaderDocument({required Iterable<ReaderBlock> blocks})
    : blocks = List<ReaderBlock>.unmodifiable(
        blocks.where(_isMeaningfulBlock).toList(growable: false),
      );

  static const String inlineImageMarkerPrefix = '[[appread-image:';
  static const String inlineImageMarkerSuffix = ']]';

  final List<ReaderBlock> blocks;

  factory ReaderDocument.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'];
    if (rawBlocks is! Iterable) {
      throw const FormatException('Missing ReaderDocument blocks');
    }
    return ReaderDocument(
      blocks: rawBlocks.map((item) {
        if (item is! Map) {
          throw const FormatException('Invalid ReaderBlock payload');
        }
        return ReaderBlock.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        );
      }),
    );
  }

  factory ReaderDocument.fromContent({
    required String content,
    List<String> imageUrls = const <String>[],
    String? title,
    bool includeTitleBlock = false,
  }) {
    final blocks = <ReaderBlock>[];
    final normalizedTitle = _normalizeText(title);
    if (includeTitleBlock && normalizedTitle != null) {
      blocks.add(ReaderTitleBlock(text: normalizedTitle));
    }

    final normalizedContent = _normalizeContent(content);
    if (normalizedContent.isNotEmpty) {
      for (final paragraph in _splitParagraphs(normalizedContent)) {
        final inlineImageUrl = tryParseInlineImageParagraph(paragraph);
        if (inlineImageUrl != null) {
          blocks.add(ReaderImageBlock(imageUrl: inlineImageUrl));
        } else if (paragraph.startsWith('• ')) {
          blocks.add(ReaderListItemBlock(text: paragraph.substring(2).trim()));
        } else if (paragraph.startsWith('> ')) {
          blocks.add(ReaderQuoteBlock(text: paragraph.substring(2).trim()));
        } else {
          blocks.add(ReaderTextBlock(text: paragraph));
        }
      }
    }

    if (blocks.isEmpty) {
      final normalizedImages = imageUrls
          .map(_normalizeText)
          .whereType<String>()
          .toList(growable: false);
      blocks.addAll(
        normalizedImages.map(
          (imageUrl) => ReaderImageBlock(imageUrl: imageUrl),
        ),
      );
    }

    return ReaderDocument(blocks: blocks);
  }

  bool get isEmpty => blocks.isEmpty;

  bool get hasImageBlocks => blocks.any((block) => block is ReaderImageBlock);

  bool get hasTextBlocks => blocks.any(
    (block) =>
        block is ReaderTextBlock ||
        block is ReaderTitleBlock ||
        block is ReaderListItemBlock ||
        block is ReaderQuoteBlock ||
        block is ReaderCaptionBlock ||
        block is ReaderFootnoteBlock,
  );

  bool get isPureImageDocument {
    final contentBlocks = blocks
        .where((block) => block is! ReaderTitleBlock)
        .toList(growable: false);
    return contentBlocks.isNotEmpty &&
        contentBlocks.every((block) => block is ReaderImageBlock);
  }

  List<String> get imageUrls {
    return blocks
        .whereType<ReaderImageBlock>()
        .map((block) => block.imageUrl)
        .toList(growable: false);
  }

  List<String> get paragraphs {
    return blocks
        .map((block) {
          if (block is ReaderTextBlock) {
            return block.text;
          }
          if (block is ReaderListItemBlock) {
            return '• ${block.text}';
          }
          if (block is ReaderQuoteBlock) {
            return block.text;
          }
          if (block is ReaderCaptionBlock) {
            return block.text;
          }
          if (block is ReaderFootnoteBlock) {
            return '注: ${block.text}';
          }
          if (block is ReaderTitleBlock) {
            return block.text;
          }
          if (block is ReaderImageBlock) {
            return inlineImageParagraph(block.imageUrl);
          }
          return '';
        })
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
  }

  String get compatibilityContent => paragraphs.join('\n\n').trim();

  String get debugSummary {
    final textCount = blocks.whereType<ReaderTextBlock>().length;
    final listCount = blocks.whereType<ReaderListItemBlock>().length;
    final quoteCount = blocks.whereType<ReaderQuoteBlock>().length;
    final captionCount = blocks.whereType<ReaderCaptionBlock>().length;
    final footnoteCount = blocks.whereType<ReaderFootnoteBlock>().length;
    final imageCount = blocks.whereType<ReaderImageBlock>().length;
    final titleCount = blocks.whereType<ReaderTitleBlock>().length;
    return 'ReaderDocument(blocks=${blocks.length}, titles=$titleCount, texts=$textCount, lists=$listCount, quotes=$quoteCount, captions=$captionCount, footnotes=$footnoteCount, images=$imageCount, pureImage=$isPureImageDocument)';
  }

  Map<String, dynamic> toJson() {
    return {
      'blocks': blocks.map((block) => block.toJson()).toList(growable: false),
    };
  }

  static String inlineImageParagraph(String imageUrl) {
    return '$inlineImageMarkerPrefix$imageUrl$inlineImageMarkerSuffix';
  }

  static String? tryParseInlineImageParagraph(String paragraph) {
    final normalized = paragraph.trim();
    if (!normalized.startsWith(inlineImageMarkerPrefix) ||
        !normalized.endsWith(inlineImageMarkerSuffix)) {
      return null;
    }
    final raw = normalized.substring(
      inlineImageMarkerPrefix.length,
      normalized.length - inlineImageMarkerSuffix.length,
    );
    final imageUrl = raw.trim();
    return imageUrl.isEmpty ? null : imageUrl;
  }

  static bool _isMeaningfulBlock(ReaderBlock block) {
    if (block is ReaderTextBlock) {
      return block.text.trim().isNotEmpty;
    }
    if (block is ReaderListItemBlock) {
      return block.text.trim().isNotEmpty;
    }
    if (block is ReaderQuoteBlock) {
      return block.text.trim().isNotEmpty;
    }
    if (block is ReaderCaptionBlock) {
      return block.text.trim().isNotEmpty;
    }
    if (block is ReaderFootnoteBlock) {
      return block.text.trim().isNotEmpty;
    }
    if (block is ReaderTitleBlock) {
      return block.text.trim().isNotEmpty;
    }
    if (block is ReaderImageBlock) {
      return block.imageUrl.trim().isNotEmpty;
    }
    return false;
  }

  static List<String> _splitParagraphs(String content) {
    return content
        .split(RegExp(r'\n{2,}'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String _normalizeContent(String content) {
    return content
        .replaceAll(r'\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n+'), '\n\n')
        .trim();
  }

  static String? _normalizeText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static String requiredString(Map<String, dynamic> json, String key) {
    final value = _normalizeText(json[key]?.toString());
    if (value == null) {
      throw FormatException('Missing required field: $key');
    }
    return value;
  }

  static int? optionalInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}
