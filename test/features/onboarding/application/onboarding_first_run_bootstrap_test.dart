import 'package:first_run_kit/first_run_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/app_data_version.dart';
import 'package:shuxiang_reading_next/features/onboarding/application/onboarding_first_run_bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fresh install keeps onboarding visible', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    await OnboardingFirstRunBootstrap.preserveExistingInstallState(prefs);
    OnboardingFirstRunBootstrap.prime(prefs);

    expect(OnboardingFirstRunBootstrap.shouldShowOnboardingSync(), isTrue);
  });

  test('existing install without first-run key is not interrupted', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      appDataVersionPreferenceKey: 1,
    });
    final prefs = await SharedPreferences.getInstance();

    await OnboardingFirstRunBootstrap.preserveExistingInstallState(prefs);
    OnboardingFirstRunBootstrap.prime(prefs);

    expect(prefs.getBool(FirstRunConstants.firstRunKey), isFalse);
    expect(OnboardingFirstRunBootstrap.shouldShowOnboardingSync(), isFalse);
  });

  test('explicit first-run reset is preserved for QA replay', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      appDataVersionPreferenceKey: 1,
      FirstRunConstants.firstRunKey: true,
    });
    final prefs = await SharedPreferences.getInstance();

    await OnboardingFirstRunBootstrap.preserveExistingInstallState(prefs);
    OnboardingFirstRunBootstrap.prime(prefs);

    expect(OnboardingFirstRunBootstrap.shouldShowOnboardingSync(), isTrue);
  });
}
