import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/auth/auth_service.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/user/user_profile_service.dart';
import 'package:shuxiang_reading_next/features/auth/application/auth_form_validation_service.dart';
import 'package:shuxiang_reading_next/features/auth/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  test('auth providers expose auth-related services', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(authServiceProvider), isA<AuthService>());
    expect(
      container.read(authFormValidationServiceProvider),
      isA<AuthFormValidationService>(),
    );
    expect(container.read(authSessionStoreProvider), isA<AuthSessionStore>());
    expect(
      container.read(userProfileServiceProvider),
      isA<UserProfileService>(),
    );
  });
}
