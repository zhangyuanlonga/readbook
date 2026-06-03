import 'package:flutter/rendering.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'reader_selection_state.freezed.dart';

@freezed
abstract class ReaderSelectionState with _$ReaderSelectionState {
  const factory ReaderSelectionState({
    SelectedContentRange? range,
    @Default(SelectionStatus.none) SelectionStatus status,
    @Default(false) bool isActive,
    @Default(0) int startOffset,
    @Default(0) int endOffset,
    @Default('') String snippet,
    @Default(false) bool highlight,
    @Default(false) bool bold,
    @Default(false) bool underline,
    @Default(false) bool wavy,
  }) = _ReaderSelectionState;

  const ReaderSelectionState._();

  bool get hasSnippet => snippet.trim().isNotEmpty;

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

@freezed
abstract class ReaderSelectionSnapshot with _$ReaderSelectionSnapshot {
  const factory ReaderSelectionSnapshot({
    required int startOffset,
    required int endOffset,
    required String snippet,
    required bool hasHighlight,
    required bool isBold,
    required bool isUnderline,
    required bool isWavy,
  }) = _ReaderSelectionSnapshot;
}

@freezed
abstract class ReaderSelectionStyle with _$ReaderSelectionStyle {
  const factory ReaderSelectionStyle({
    required bool highlight,
    required bool bold,
    required bool underline,
    required bool wavy,
  }) = _ReaderSelectionStyle;
}
