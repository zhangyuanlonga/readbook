import '../../source/application/external_source_import_bridge.dart';
import '../application/advanced_theme_page_flow_coordinator.dart';

class AdvancedThemeImportController {
  const AdvancedThemeImportController();

  Future<void> consumePendingExternalImportPayloads({
    required bool isConsuming,
    required bool mounted,
    required void Function(bool value) setConsuming,
    required AdvancedThemePageFlowCoordinator flowCoordinator,
    required Future<void> Function(IncomingExternalImportPayload payload)
    importPayload,
  }) async {
    if (isConsuming || !mounted) {
      return;
    }

    setConsuming(true);
    try {
      await flowCoordinator.consumePendingPayloads(importPayload);
    } finally {
      setConsuming(false);
    }
  }
}
