import '../../../domain/entities/app_advanced_theme.dart';

class AdvancedThemeExportNaming {
  const AdvancedThemeExportNaming._();

  static String themeBundleExportFileName(AppAdvancedTheme theme) {
    return '${normalizedExportFileName(theme.name)}.zip';
  }

  static String themeBatchBundleExportFileName({DateTime? now}) {
    return 'advanced_themes_batch_${formattedTimestampForFileName(now ?? DateTime.now())}.zip';
  }

  static String normalizedExportFileName(String name) {
    final normalized = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
    return normalized.isEmpty ? 'advanced_theme' : normalized;
  }

  static String formattedTimestampForFileName(DateTime value) {
    String twoDigits(int input) => input.toString().padLeft(2, '0');
    return '${value.year}${twoDigits(value.month)}${twoDigits(value.day)}_${twoDigits(value.hour)}${twoDigits(value.minute)}${twoDigits(value.second)}';
  }
}
