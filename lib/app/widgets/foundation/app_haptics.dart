import 'package:flutter/services.dart';

enum AppHapticType { selection, lightImpact, mediumImpact, heavyImpact }

class AppHaptics {
  const AppHaptics._();

  static Future<void> trigger(AppHapticType type, {bool enabled = true}) async {
    if (!enabled) {
      return;
    }
    return switch (type) {
      AppHapticType.selection => HapticFeedback.selectionClick(),
      AppHapticType.lightImpact => HapticFeedback.lightImpact(),
      AppHapticType.mediumImpact => HapticFeedback.mediumImpact(),
      AppHapticType.heavyImpact => HapticFeedback.heavyImpact(),
    };
  }

  static Future<void> selection({bool enabled = true}) {
    return trigger(AppHapticType.selection, enabled: enabled);
  }

  static Future<void> success({bool enabled = true}) {
    return trigger(AppHapticType.lightImpact, enabled: enabled);
  }

  static Future<void> warning({bool enabled = true}) {
    return trigger(AppHapticType.mediumImpact, enabled: enabled);
  }

  static Future<void> danger({bool enabled = true}) {
    return trigger(AppHapticType.heavyImpact, enabled: enabled);
  }
}
