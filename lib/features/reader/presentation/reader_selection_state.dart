import 'package:flutter/rendering.dart';

class ReaderSelectionState {
  const ReaderSelectionState({
    this.range,
    this.status = SelectionStatus.none,
    this.isActive = false,
    this.startOffset = 0,
    this.endOffset = 0,
    this.snippet = '',
    this.highlight = false,
    this.bold = false,
    this.underline = false,
    this.wavy = false,
  });

  final SelectedContentRange? range;
  final SelectionStatus status;
  final bool isActive;
  final int startOffset;
  final int endOffset;
  final String snippet;
  final bool highlight;
  final bool bold;
  final bool underline;
  final bool wavy;

  bool get hasSnippet => snippet.trim().isNotEmpty;

  ReaderSelectionState copyWith({
    Object? range = _unset,
    SelectionStatus? status,
    bool? isActive,
    int? startOffset,
    int? endOffset,
    String? snippet,
    bool? highlight,
    bool? bold,
    bool? underline,
    bool? wavy,
  }) {
    return ReaderSelectionState(
      range:
          identical(range, _unset)
              ? this.range
              : range as SelectedContentRange?,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      snippet: snippet ?? this.snippet,
      highlight: highlight ?? this.highlight,
      bold: bold ?? this.bold,
      underline: underline ?? this.underline,
      wavy: wavy ?? this.wavy,
    );
  }

  ReaderSelectionState clear() {
    return const ReaderSelectionState();
  }

  ReaderSelectionState activate({
    required int startOffset,
    required int endOffset,
    required String snippet,
    required bool highlight,
    required bool bold,
    required bool underline,
    required bool wavy,
  }) {
    return copyWith(
      isActive: true,
      startOffset: startOffset,
      endOffset: endOffset,
      snippet: snippet,
      highlight: highlight,
      bold: bold,
      underline: underline,
      wavy: wavy,
    );
  }

  ReaderSelectionSnapshot? snapshot() {
    if (!isActive || !hasSnippet) {
      return null;
    }
    return ReaderSelectionSnapshot(
      startOffset: startOffset,
      endOffset: endOffset,
      snippet: snippet.trim(),
      hasHighlight: highlight,
      isBold: bold,
      isUnderline: underline,
      isWavy: wavy,
    );
  }

  ReaderSelectionState restore(ReaderSelectionSnapshot snapshot) {
    return activate(
      startOffset: snapshot.startOffset,
      endOffset: snapshot.endOffset,
      snippet: snapshot.snippet,
      highlight: snapshot.hasHighlight,
      bold: snapshot.isBold,
      underline: snapshot.isUnderline,
      wavy: snapshot.isWavy,
    );
  }
}

class ReaderSelectionSnapshot {
  const ReaderSelectionSnapshot({
    required this.startOffset,
    required this.endOffset,
    required this.snippet,
    required this.hasHighlight,
    required this.isBold,
    required this.isUnderline,
    required this.isWavy,
  });

  final int startOffset;
  final int endOffset;
  final String snippet;
  final bool hasHighlight;
  final bool isBold;
  final bool isUnderline;
  final bool isWavy;
}

class ReaderSelectionStyle {
  const ReaderSelectionStyle({
    required this.highlight,
    required this.bold,
    required this.underline,
    required this.wavy,
  });

  final bool highlight;
  final bool bold;
  final bool underline;
  final bool wavy;
}

const Object _unset = Object();
