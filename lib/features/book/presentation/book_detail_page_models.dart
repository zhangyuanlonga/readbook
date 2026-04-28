part of 'book_detail_page.dart';

class _LocalBookDiagnosticsSnapshot {
  const _LocalBookDiagnosticsSnapshot({
    required this.sourcePath,
    required this.storagePath,
    required this.resolvedStoragePath,
    required this.sourceFileExists,
    required this.storageFileExists,
    required this.sourceFileChanged,
    required this.globalSplitLongChapterEnabled,
    required this.splitSettingNeedsReindex,
  });

  final String sourcePath;
  final String storagePath;
  final String resolvedStoragePath;
  final bool sourceFileExists;
  final bool storageFileExists;
  final bool sourceFileChanged;
  final bool globalSplitLongChapterEnabled;
  final bool splitSettingNeedsReindex;
}

class _LocalCharsetOption {
  const _LocalCharsetOption({required this.label, required this.charset});

  final String label;
  final String? charset;
}
