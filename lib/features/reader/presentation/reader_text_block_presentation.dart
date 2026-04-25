import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../../domain/entities/reader_settings.dart';
import '../application/reader_document_render_model.dart';
import '../application/reader_typography_resolver.dart';

class ReaderTextBlockPresentation {
  const ReaderTextBlockPresentation({
    required this.textStyle,
    required this.textAlign,
    required this.displayText,
    required this.indentLength,
    required this.spacingAfter,
  });

  final TextStyle textStyle;
  final TextAlign textAlign;
  final String displayText;
  final int indentLength;
  final double spacingAfter;
}

ReaderTextBlockPresentation resolveReaderTextBlockPresentation({
  required ReaderSettings settings,
  required Color primaryTextColor,
  required Color secondaryTextColor,
  required ReaderRenderTextItem? item,
  required bool isLast,
  TextAlign? paragraphTextAlign,
}) {
  final resolver = const ReaderTypographyResolver();
  final bodyColor =
      settings.bodyTextColorValue == null
          ? primaryTextColor
          : Color(settings.bodyTextColorValue!);
  final baseStyle = resolver.resolveBodyStyle(
    settings: settings,
    color: bodyColor,
  );
  final kind = item?.kind ?? ReaderRenderTextKind.paragraph;
  final textStyle = switch (kind) {
    ReaderRenderTextKind.paragraph => baseStyle,
    ReaderRenderTextKind.listItem => baseStyle.copyWith(
      height: (baseStyle.height ?? settings.lineHeight) + 0.05,
    ),
    ReaderRenderTextKind.quote => baseStyle.copyWith(
      fontStyle: FontStyle.italic,
      color: secondaryTextColor,
      height: (baseStyle.height ?? settings.lineHeight) + 0.08,
    ),
    ReaderRenderTextKind.caption => baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? settings.fontSize) * 0.9,
      color: secondaryTextColor,
      height: 1.45,
    ),
    ReaderRenderTextKind.footnote => baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? settings.fontSize) * 0.86,
      color: secondaryTextColor,
      height: 1.48,
    ),
    ReaderRenderTextKind.title => baseStyle.copyWith(
      fontSize:
          (baseStyle.fontSize ?? settings.fontSize) *
          _titleScaleForLevel(item?.level ?? 1),
      fontWeight: FontWeight.w800,
      height: 1.35,
    ),
  };
  final textAlign = switch (kind) {
    ReaderRenderTextKind.title => TextAlign.start,
    ReaderRenderTextKind.listItem => TextAlign.start,
    ReaderRenderTextKind.quote => TextAlign.start,
    ReaderRenderTextKind.caption => TextAlign.center,
    ReaderRenderTextKind.footnote => TextAlign.start,
    ReaderRenderTextKind.paragraph =>
      paragraphTextAlign ?? _paragraphTextAlign(settings),
  };
  final rawText = item?.text ?? '';
  final displayText = switch (kind) {
    ReaderRenderTextKind.paragraph => _applyParagraphIndent(rawText, settings),
    ReaderRenderTextKind.listItem => '• $rawText',
    ReaderRenderTextKind.quote => rawText,
    ReaderRenderTextKind.caption => rawText,
    ReaderRenderTextKind.footnote => '注: $rawText',
    ReaderRenderTextKind.title => rawText,
  };
  final spacingAfter =
      isLast
          ? 0
          : switch (kind) {
            ReaderRenderTextKind.paragraph => settings.paragraphSpacing,
            ReaderRenderTextKind.listItem => settings.paragraphSpacing * 0.7,
            ReaderRenderTextKind.quote => math.max(
              settings.paragraphSpacing * 0.85,
              14.0,
            ),
            ReaderRenderTextKind.caption => settings.paragraphSpacing * 0.6,
            ReaderRenderTextKind.footnote => settings.paragraphSpacing * 0.55,
            ReaderRenderTextKind.title => math.max(
              settings.paragraphSpacing,
              18.0,
            ),
          };
  return ReaderTextBlockPresentation(
    textStyle: textStyle,
    textAlign: textAlign,
    displayText: displayText,
    indentLength: displayText.length - rawText.length,
    spacingAfter: spacingAfter.toDouble(),
  );
}

String readerParagraphIndentPrefix(ReaderSettings settings) {
  final indentCount = settings.paragraphIndent.round();
  if (indentCount <= 0) {
    return '';
  }
  return '　' * indentCount;
}

String _applyParagraphIndent(String paragraph, ReaderSettings settings) {
  final prefix = readerParagraphIndentPrefix(settings);
  if (prefix.isEmpty) {
    return paragraph;
  }
  return '$prefix$paragraph';
}

TextAlign _paragraphTextAlign(ReaderSettings settings) {
  return settings.textFullJustifyEnabled ? TextAlign.justify : TextAlign.start;
}

double _titleScaleForLevel(int level) {
  return switch (level) {
    <= 1 => 1.34,
    2 => 1.22,
    3 => 1.12,
    _ => 1.04,
  };
}
