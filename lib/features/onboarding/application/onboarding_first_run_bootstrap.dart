import 'package:first_run_kit/first_run_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_data_version.dart';

class OnboardingFirstRunBootstrap {
  OnboardingFirstRunBootstrap._();

  static bool _shouldShowOnboarding = true;

  static Future<void> preserveExistingInstallState(
    SharedPreferences prefs,
  ) async {
    if (prefs.containsKey(FirstRunConstants.firstRunKey)) {
      return;
    }
    final existingDataVersion = prefs.getInt(appDataVersionPreferenceKey) ?? 0;
    if (existingDataVersion <= 0) {
      return;
    }
    await FirstRunManager().markFirstRunComplete();
  }

  static void prime(SharedPreferences prefs) {
    _shouldShowOnboarding =
        prefs.getBool(FirstRunConstants.firstRunKey) ??
        FirstRunConstants.defaultFirstRunValue;
  }

  static bool shouldShowOnboardingSync() => _shouldShowOnboarding;

  static void markCompletedSync() {
    _shouldShowOnboarding = false;
  }
}
