import 'reader_document.dart';

class ReaderLogicalPosition {
  const ReaderLogicalPosition({
    required this.chapterIndex,
    required this.blockIndex,
    required this.offsetInBlock,
    required this.chapterPositionRatio,
    this.pageIndex,
    this.totalPageCount,
    this.viewportMode,
    this.zoomScale,
    this.panDx,
    this.panDy,
  });

  factory ReaderLogicalPosition.fromDocument({
    required ReaderDocument document,
    required int chapterIndex,
    required double chapterPositionRatio,
    int? pageIndex,
  }) {
    final normalizedRatio = chapterPositionRatio.clamp(0.0, 1.0);
    final blocks = document.blocks;
    if (blocks.isEmpty) {
      return ReaderLogicalPosition(
        chapterIndex: chapterIndex,
        blockIndex: 0,
        offsetInBlock: 0,
        pageIndex: pageIndex,
        chapterPositionRatio: normalizedRatio,
      );
    }

    final scaledPosition = normalizedRatio * blocks.length;
    final blockIndex = scaledPosition.floor().clamp(0, blocks.length - 1);
    final localRatio = (scaledPosition - blockIndex).clamp(
      0.0,
      normalizedRatio >= 1.0 ? 1.0 : 0.999999,
    );
    final blockLength = _effectiveBlockLength(blocks[blockIndex]);
    final offsetInBlock = (blockLength * localRatio).round().clamp(
      0,
      blockLength,
    );

    return ReaderLogicalPosition(
      chapterIndex: chapterIndex,
      blockIndex: blockIndex,
      offsetInBlock: offsetInBlock,
      pageIndex: pageIndex,
      chapterPositionRatio: normalizedRatio,
    );
  }

  final int chapterIndex;
  final int blockIndex;
  final int offsetInBlock;
  final double chapterPositionRatio;
  final int? pageIndex;
  final int? totalPageCount;
  final String? viewportMode;
  final double? zoomScale;
  final double? panDx;
  final double? panDy;

  ReaderLogicalPosition copyWith({
    int? chapterIndex,
    int? blockIndex,
    int? offsetInBlock,
    double? chapterPositionRatio,
    int? pageIndex,
    int? totalPageCount,
    String? viewportMode,
    double? zoomScale,
    double? panDx,
    double? panDy,
    bool clearPageIndex = false,
    bool clearTotalPageCount = false,
    bool clearViewportMode = false,
    bool clearZoomScale = false,
    bool clearPanOffset = false,
  }) {
    return ReaderLogicalPosition(
      chapterIndex: chapterIndex ?? this.chapterIndex,
      blockIndex: blockIndex ?? this.blockIndex,
      offsetInBlock: offsetInBlock ?? this.offsetInBlock,
      chapterPositionRatio: (chapterPositionRatio ?? this.chapterPositionRatio)
          .clamp(0.0, 1.0),
      pageIndex: clearPageIndex ? null : (pageIndex ?? this.pageIndex),
      totalPageCount:
          clearTotalPageCount ? null : (totalPageCount ?? this.totalPageCount),
      viewportMode:
          clearViewportMode ? null : (viewportMode ?? this.viewportMode),
      zoomScale: clearZoomScale ? null : (zoomScale ?? this.zoomScale),
      panDx: clearPanOffset ? null : (panDx ?? this.panDx),
      panDy: clearPanOffset ? null : (panDy ?? this.panDy),
    );
  }

  double approximateRatio(ReaderDocument document) {
    final blocks = document.blocks;
    if (blocks.isEmpty) {
      return chapterPositionRatio.clamp(0.0, 1.0);
    }

    final safeBlockIndex = blockIndex.clamp(0, blocks.length - 1);
    final blockLength = _effectiveBlockLength(blocks[safeBlockIndex]);
    final offsetRatio = offsetInBlock.clamp(0, blockLength) / blockLength;
    return ((safeBlockIndex + offsetRatio) / blocks.length).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() {
    return {
      'chapterIndex': chapterIndex,
      'blockIndex': blockIndex,
      'offsetInBlock': offsetInBlock,
      'chapterPositionRatio': chapterPositionRatio,
      'pageIndex': pageIndex,
      'totalPageCount': totalPageCount,
      'viewportMode': viewportMode,
      'zoomScale': zoomScale,
      'panDx': panDx,
      'panDy': panDy,
    };
  }

  factory ReaderLogicalPosition.fromJson(Map<String, dynamic> json) {
    return ReaderLogicalPosition(
      chapterIndex: _requiredInt(json, 'chapterIndex'),
      blockIndex: _requiredInt(json, 'blockIndex'),
      offsetInBlock: _requiredInt(json, 'offsetInBlock'),
      chapterPositionRatio: _requiredDouble(json, 'chapterPositionRatio'),
      pageIndex: _optionalInt(json['pageIndex']),
      totalPageCount: _optionalInt(json['totalPageCount']),
      viewportMode: _optionalString(json['viewportMode']),
      zoomScale: _optionalDouble(json['zoomScale']),
      panDx: _optionalDouble(json['panDx']),
      panDy: _optionalDouble(json['panDy']),
    );
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = _optionalInt(json[key]);
    if (value == null) {
      throw FormatException('Missing required int field: $key');
    }
    return value;
  }

  static int? _optionalInt(Object? value) {
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

  static double _requiredDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is double) {
      return value.clamp(0.0, 1.0);
    }
    if (value is num) {
      return value.toDouble().clamp(0.0, 1.0);
    }
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null) {
        return parsed.clamp(0.0, 1.0);
      }
    }
    throw FormatException('Missing required double field: $key');
  }

  static double? _optionalDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static String? _optionalString(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static int _effectiveBlockLength(ReaderBlock block) {
    if (block is ReaderTextBlock) {
      return block.text.isEmpty ? 1 : block.text.length;
    }
    if (block is ReaderListItemBlock) {
      return block.text.isEmpty ? 1 : block.text.length;
    }
    if (block is ReaderQuoteBlock) {
      return block.text.isEmpty ? 1 : block.text.length;
    }
    if (block is ReaderCaptionBlock) {
      return block.text.isEmpty ? 1 : block.text.length;
    }
    if (block is ReaderFootnoteBlock) {
      return block.text.isEmpty ? 1 : block.text.length;
    }
    if (block is ReaderTitleBlock) {
      return block.text.isEmpty ? 1 : block.text.length;
    }
    return 1;
  }
}
