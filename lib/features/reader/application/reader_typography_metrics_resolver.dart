import '../../../domain/entities/reader_settings.dart';

class ReaderTypographyMetricsResolver {
  const ReaderTypographyMetricsResolver();

  ReaderSettings normalizeSettings(ReaderSettings settings) {
    final normalizedParagraphSpacing =
        settings.paragraphSpacing.clamp(0.0, 20.0).toDouble();
    final normalizedParagraphIndent =
        settings.paragraphIndent.clamp(0.0, 4.0).toDouble();

    return settings.copyWith(
      paragraphSpacing: normalizedParagraphSpacing,
      paragraphIndent: normalizedParagraphIndent,
    );
  }

  double resolveLineHeight(ReaderSettings settings) {
    return settings.lineHeight.clamp(1.2, 2.2).toDouble();
  }

  double resolveLineSpacingExtra(ReaderSettings settings) {
    final safeFontSize = settings.fontSize <= 0 ? 18.0 : settings.fontSize;
    return ((resolveLineHeight(settings) - 1) * safeFontSize)
        .clamp(0.0, 20.0)
        .toDouble();
  }

  double resolveParagraphSpacingUnits(ReaderSettings settings) {
    return settings.paragraphSpacing.clamp(0.0, 20.0).toDouble() / 10.0;
  }

  double resolveParagraphSpacingPixels({
    required ReaderSettings settings,
    double? fontSize,
    double? lineHeight,
  }) {
    final resolvedFontSize = fontSize ?? settings.fontSize;
    final resolvedLineHeight = lineHeight ?? resolveLineHeight(settings);
    final lineHeightPixels = resolvedFontSize * resolvedLineHeight;
    return lineHeightPixels * resolveParagraphSpacingUnits(settings);
  }

  int resolveParagraphIndentCount(ReaderSettings settings) {
    return settings.paragraphIndent.round().clamp(0, 4);
  }
}
