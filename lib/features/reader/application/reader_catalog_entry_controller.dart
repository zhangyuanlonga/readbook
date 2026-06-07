import 'reader_mode_capabilities.dart';

class ReaderCatalogEntryDecision {
  const ReaderCatalogEntryDecision({required this.canOpen, this.message});

  final bool canOpen;
  final String? message;
}

class ReaderCatalogEntryController {
  const ReaderCatalogEntryController();

  ReaderCatalogEntryDecision resolveOpenDecision({
    required ReaderModeCapabilities capabilities,
    required bool hasCatalog,
    required bool catalogComplete,
  }) {
    if (!capabilities.supportsCatalogNavigation) {
      return const ReaderCatalogEntryDecision(
        canOpen: false,
        message: '当前内容暂不支持目录操作。',
      );
    }
    if (!hasCatalog && catalogComplete) {
      return const ReaderCatalogEntryDecision(
        canOpen: false,
        message: '当前书籍暂无目录。',
      );
    }
    return const ReaderCatalogEntryDecision(canOpen: true);
  }
}
