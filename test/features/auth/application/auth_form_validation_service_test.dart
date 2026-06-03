import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/auth/application/auth_form_validation_service.dart';

void main() {
  const service = AuthFormValidationService();

  group('AuthFormValidationService', () {
    test('validates account and required password', () {
      expect(service.validateAccount(' '), '请输入账号');
      expect(service.validateAccount('reader'), isNull);
      expect(service.validateRequiredPassword(''), '请输入密码');
      expect(service.validateRequiredPassword('secret'), isNull);
    });

    test('validates required and optional confirm password', () {
      expect(
        service.validateConfirmPassword('', password: 'secret'),
        '请再次输入密码',
      );
      expect(
        service.validateConfirmPassword('secret2', password: 'secret'),
        '两次密码输入不一致',
      );
      expect(
        service.validateConfirmPassword('secret', password: 'secret'),
        isNull,
      );

      expect(service.validateOptionalConfirmPassword('', password: ''), isNull);
      expect(
        service.validateOptionalConfirmPassword('', password: 'secret'),
        '请再次输入新密码',
      );
      expect(
        service.validateOptionalConfirmPassword('secret2', password: 'secret'),
        '两次输入的新密码不一致',
      );
    });

    test('validates optional email and phone', () {
      expect(service.validateOptionalEmail(''), isNull);
      expect(service.validateOptionalEmail('reader@example.com'), isNull);
      expect(service.validateOptionalEmail('reader@example'), '邮箱格式不正确');

      expect(service.validateOptionalPhone(''), isNull);
      expect(service.validateOptionalPhone('+86 13800138000'), isNull);
      expect(service.validateOptionalPhone('abc'), '手机号格式不正确');
    });

    test('resolves password strength presentation', () {
      expect(service.resolvePasswordStrength('').label, '密码强度：偏弱');
      expect(service.resolvePasswordStrength('abcdef12').label, '密码强度：适中');
      expect(
        service.resolvePasswordStrength('abcdef12!').isStrongPresentation,
        isTrue,
      );
    });
  });
}
