import '../../../domain/entities/reader_settings.dart';
import 'reader_surface_metrics.dart';

class ReaderPaginationSpec {
  const ReaderPaginationSpec({
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
  });

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
}

class ReaderPaginationSpecResolver {
  const ReaderPaginationSpecResolver();

  ReaderPaginationSpec resolve({
    required ReaderSettings settings,
    required ReaderSurfaceMetrics surfaceMetrics,
  }) {
    return ReaderPaginationSpec(
      contentWidth: surfaceMetrics.contentWidth,
      contentHeight: surfaceMetrics.contentHeight,
      contentRectLeft: surfaceMetrics.contentRect.left,
      contentRectTop: surfaceMetrics.contentRect.top,
      pagePaddingTop: surfaceMetrics.effectivePagePadding.top,
      pagePaddingRight: surfaceMetrics.effectivePagePadding.right,
      pagePaddingBottom: surfaceMetrics.effectivePagePadding.bottom,
      pagePaddingLeft: surfaceMetrics.effectivePagePadding.left,
      pinnedHeaderHeight: surfaceMetrics.pinnedHeaderHeight,
      fontSize: settings.fontSize,
      lineHeight: settings.lineHeight,
      paragraphSpacing: settings.paragraphSpacing,
      paragraphIndent: settings.paragraphIndent,
      letterSpacing: settings.letterSpacing,
      textFullJustifyEnabled: settings.textFullJustifyEnabled,
      bodyTextItalicEnabled: settings.bodyTextItalicEnabled,
      fontWeightLevel: settings.fontWeightLevel,
      fontWeightValue: settings.fontWeightValue,
      fontSource: settings.fontSource,
      systemFontPreset: settings.systemFontPreset,
      fontFamilyKey: settings.fontFamilyKey?.trim(),
    );
  }

  String buildSignature({
    required String chapterId,
    required ReaderPaginationSpec spec,
  }) {
    return [
      chapterId,
      spec.contentWidth.toStringAsFixed(1),
      spec.contentHeight.toStringAsFixed(1),
      spec.contentRectLeft.toStringAsFixed(1),
      spec.contentRectTop.toStringAsFixed(1),
      spec.pinnedHeaderHeight.toStringAsFixed(1),
      spec.pagePaddingTop.toStringAsFixed(1),
      spec.pagePaddingRight.toStringAsFixed(1),
      spec.pagePaddingBottom.toStringAsFixed(1),
      spec.pagePaddingLeft.toStringAsFixed(1),
      spec.fontSize.toStringAsFixed(1),
      spec.lineHeight.toStringAsFixed(2),
      spec.paragraphSpacing.toStringAsFixed(1),
      spec.paragraphIndent.toStringAsFixed(1),
      spec.letterSpacing.toStringAsFixed(3),
      spec.textFullJustifyEnabled ? 'justify' : 'start',
      spec.bodyTextItalicEnabled ? 'italic' : 'normal',
      spec.fontWeightLevel.name,
      spec.fontWeightValue?.toString() ?? '',
      spec.fontSource.name,
      spec.systemFontPreset.name,
      spec.fontFamilyKey ?? '',
    ].join('|');
  }
}
