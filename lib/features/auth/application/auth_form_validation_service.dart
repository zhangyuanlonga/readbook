class AuthFormValidationService {
  const AuthFormValidationService();

  String? validateRequired(String? value, String fieldName) {
    if ((value ?? '').trim().isEmpty) {
      return '请输入$fieldName';
    }
    return null;
  }

  String? validateAccount(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return '请输入账号';
    }
    return null;
  }

  String? validateRequiredPassword(String? value) {
    if ((value ?? '').isEmpty) {
      return '请输入密码';
    }
    return null;
  }

  String? validateOptionalNewPassword(String? value) {
    final password = value ?? '';
    if (password.isNotEmpty && password.length < 6) {
      return '新密码至少需要 6 位';
    }
    return null;
  }

  String? validateConfirmPassword(
    String? value, {
    required String password,
    String emptyMessage = '请再次输入密码',
    String mismatchMessage = '两次密码输入不一致',
  }) {
    final confirm = value ?? '';
    if (confirm.isEmpty) {
      return emptyMessage;
    }
    if (confirm != password) {
      return mismatchMessage;
    }
    return null;
  }

  String? validateOptionalConfirmPassword(
    String? value, {
    required String password,
    String emptyMessage = '请再次输入新密码',
    String mismatchMessage = '两次输入的新密码不一致',
  }) {
    final confirm = value ?? '';
    if (password.isEmpty && confirm.isEmpty) {
      return null;
    }
    return validateConfirmPassword(
      value,
      password: password,
      emptyMessage: emptyMessage,
      mismatchMessage: mismatchMessage,
    );
  }

  String? validateOptionalEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) {
      return null;
    }
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) {
      return '邮箱格式不正确';
    }
    return null;
  }

  String? validateOptionalPhone(String? value) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) {
      return null;
    }
    final phonePattern = RegExp(r'^\+?[0-9][0-9\s-]{5,19}$');
    if (!phonePattern.hasMatch(phone)) {
      return '手机号格式不正确';
    }
    return null;
  }

  AuthPasswordStrength resolvePasswordStrength(String password) {
    final score =
        [
          password.length >= 8,
          RegExp(r'[A-Za-z]').hasMatch(password),
          RegExp(r'\d').hasMatch(password),
          RegExp(r'[^A-Za-z0-9]').hasMatch(password),
        ].where((matched) => matched).length;
    return AuthPasswordStrength(score);
  }
}

class AuthPasswordStrength {
  const AuthPasswordStrength(this.score);

  final int score;

  String get label => switch (score) {
    0 || 1 => '密码强度：偏弱',
    2 || 3 => '密码强度：适中',
    _ => '密码强度：较强',
  };

  bool get isStrongPresentation => score >= 3;
}
